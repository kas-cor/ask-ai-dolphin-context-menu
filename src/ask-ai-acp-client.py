#!/usr/bin/env python3
"""Minimal ACP (Agent Client Protocol) client for Ask AI.

Phase 0: drives any ACP agent over stdio and streams its answer as Markdown on
stdout, so the existing pipeline (`| tee result.md | glow -`) keeps working.

Protocol (v1, newline-delimited JSON-RPC 2.0 on stdin/stdout):
  initialize            -> agent capabilities and auth methods
  session/new           -> session id + config options (model, effort, mode)
  session/set_config_option  -> select model / reasoning effort / mode
  session/prompt        -> prompt turn; answer arrives as session/update chunks
  session/cancel        -> notification sent on SIGINT

Only `agent_message_chunk` text reaches stdout. Thoughts, tool calls and
protocol noise go to stderr (with --verbose) or to the trace file, so the saved
.md and the glow output stay clean.

Exit codes:
  0   answer completed
  1   agent/protocol failure
  3   the agent requires authentication first
  130 interrupted by the user
"""

import argparse
import json
import os
import queue
import signal
import subprocess
import sys
import threading
import time
from urllib.parse import quote

PROTOCOL_VERSION = 1
DEFAULT_AGENT = "opencode acp"
HANDSHAKE_TIMEOUT = 60.0
# Tool calls that only read: safe to auto-approve when the policy allows it.
READ_ONLY_KINDS = {"read", "search", "fetch", "think"}


class AcpError(Exception):
    """Protocol or transport failure."""


class Trace:
    """Append-only JSON-RPC log (--trace), useful when an agent misbehaves."""

    def __init__(self, path):
        self._fh = None
        if not path:
            return
        try:
            os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
            self._fh = open(path, "a", encoding="utf-8")
        except OSError as exc:
            print(f"acp: cannot write trace {path}: {exc}", file=sys.stderr)

    def write(self, direction, payload):
        if not self._fh:
            return
        try:
            self._fh.write(f"{direction} {json.dumps(payload, ensure_ascii=False)}\n")
            self._fh.flush()
        except OSError:
            self._fh = None

    def close(self):
        if self._fh:
            try:
                self._fh.close()
            finally:
                self._fh = None


def log(message):
    print(f"acp: {message}", file=sys.stderr, flush=True)


class AgentProcess:
    """Spawns the ACP agent and pumps its stdio on background threads."""

    def __init__(self, command, trace):
        self.command = command
        self.trace = trace
        self.proc = None
        self._incoming = queue.Queue()
        self._next_id = 0
        self._write_lock = threading.Lock()

    def start(self):
        try:
            self.proc = subprocess.Popen(
                self.command,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                bufsize=0,
            )
        except FileNotFoundError:
            raise AcpError(f"agent not found: {self.command[0]}")
        except OSError as exc:
            raise AcpError(f"cannot start agent: {exc}")
        threading.Thread(target=self._read_stdout, daemon=True).start()
        threading.Thread(target=self._read_stderr, daemon=True).start()

    def _read_stdout(self):
        stream = self.proc.stdout
        while True:
            line = stream.readline()
            if not line:
                self._incoming.put(("eof", None))
                return
            text = line.decode("utf-8", "replace").strip()
            if not text:
                continue
            try:
                self._incoming.put(("msg", json.loads(text)))
            except json.JSONDecodeError:
                # ACP forbids non-JSON on stdout; surface it instead of hiding it.
                log(f"invalid JSON from agent: {text[:200]}")

    def _read_stderr(self):
        stream = self.proc.stderr
        while True:
            line = stream.readline()
            if not line:
                return
            self.trace.write("agent-stderr", line.decode("utf-8", "replace").rstrip())

    def send(self, payload):
        self.trace.write("->", payload)
        data = (json.dumps(payload, ensure_ascii=False) + "\n").encode("utf-8")
        with self._write_lock:
            try:
                self.proc.stdin.write(data)
                self.proc.stdin.flush()
            except (BrokenPipeError, ValueError):
                raise AcpError("agent closed the connection")

    def request(self, method, params, timeout=HANDSHAKE_TIMEOUT):
        self._next_id += 1
        req_id = self._next_id
        self.send({"jsonrpc": "2.0", "id": req_id, "method": method, "params": params})
        deadline = time.monotonic() + timeout
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise AcpError(f"{method}: no response from the agent")
            entry = self._next(timeout=remaining)
            if entry is None:
                raise AcpError(f"{method}: agent exited")
            if entry.get("id") != req_id or "method" in entry:
                # Not the response we wait for: keep it for the main loop.
                self._incoming.put(("msg", entry))
                time.sleep(0.01)
                continue
            if "error" in entry:
                raise AcpError(f"{method}: {_error_text(entry['error'])}")
            return entry.get("result") or {}

    def _next(self, timeout):
        try:
            kind, payload = self._incoming.get(timeout=timeout)
        except queue.Empty:
            return None
        if kind == "eof":
            return None
        self.trace.write("<-", payload)
        return payload

    def terminate(self):
        if not self.proc:
            return
        try:
            self.proc.stdin.close()
        except OSError:
            pass
        try:
            self.proc.terminate()
            self.proc.wait(timeout=2)
        except (subprocess.TimeoutExpired, OSError):
            try:
                self.proc.kill()
            except OSError:
                pass


def _error_text(error):
    if isinstance(error, dict):
        message = error.get("message") or "unknown error"
        code = error.get("code")
        return f"{message} (code {code})" if code is not None else message
    return str(error)


def split_command(command):
    """Split an agent command line without invoking a shell."""
    import shlex

    return shlex.split(command)


def find_option(config_options, wanted_id, wanted_category):
    """Return the config option the agent exposes for model/effort/mode."""
    for option in config_options or []:
        if option.get("id") == wanted_id:
            return option
    for option in config_options or []:
        if option.get("category") == wanted_category:
            return option
    return None


def file_uri(path):
    return "file://" + quote(os.path.abspath(path))


class Client:
    def __init__(self, args):
        self.args = args
        self.trace = Trace(args.trace)
        self.agent = AgentProcess(split_command(args.agent), self.trace)
        self.session_id = None
        self.config_options = []
        self.stop_reason = None
        self._streamed = 0
        self.auth_methods = []
        self.interrupted = False
        self.exit_code = 0

    # --- setup ---------------------------------------------------------

    def connect(self):
        self.agent.start()
        result = self.agent.request(
            "initialize",
            {
                "protocolVersion": PROTOCOL_VERSION,
                "clientCapabilities": {"fs": {"readTextFile": True, "writeTextFile": False}},
            },
        )
        version = result.get("protocolVersion")
        if version != PROTOCOL_VERSION:
            raise AcpError(
                f"unsupported ACP version {version!r} (this client speaks {PROTOCOL_VERSION})"
            )
        self.auth_methods = result.get("authMethods") or []
        info = result.get("agentInfo") or {}
        if info.get("name") and self.args.verbose:
            log(f"agent: {info.get('name')} {info.get('version', '')}".strip())

        session = self.agent.request(
            "session/new", {"cwd": self.args.cwd, "mcpServers": []}
        )
        self.session_id = session.get("sessionId")
        if not self.session_id:
            raise AcpError("session/new returned no sessionId")
        self.config_options = session.get("configOptions") or []
        self._apply_config()

    def _apply_config(self):
        for value, wanted_id, category, label in (
            (self.args.model, "model", "model", "model"),
            (self.args.effort, "effort", "thought_level", "effort"),
            (self.args.mode, "mode", "mode", "mode"),
        ):
            if not value:
                continue
            option = find_option(self.config_options, wanted_id, category)
            if option is None:
                log(f"{label} '{value}' ignored: the agent exposes no {label} option")
                continue
            try:
                result = self.agent.request(
                    "session/set_config_option",
                    {"sessionId": self.session_id, "configId": option["id"], "value": value},
                )
            except AcpError as exc:
                log(f"{label} '{value}' ignored: {exc}")
                continue
            self.config_options = result.get("configOptions") or self.config_options

    def prompt_blocks(self):
        blocks = [{"type": "text", "text": self.args.query}]
        for path in self.args.files:
            if not os.path.isfile(path):
                log(f"attachment skipped (not a file): {path}")
                continue
            blocks.append(
                {
                    "type": "resource_link",
                    "uri": file_uri(path),
                    "name": os.path.basename(path),
                }
            )
        return blocks

    # --- prompt turn ---------------------------------------------------

    def run_prompt(self):
        self.agent.send(
            {
                "jsonrpc": "2.0",
                "id": "prompt",
                "method": "session/prompt",
                "params": {"sessionId": self.session_id, "prompt": self.prompt_blocks()},
            }
        )
        # Some agents retry a failing provider for a long time without sending a
        # single chunk; without this the window looks frozen with no output.
        idle_deadline = time.monotonic() + self.args.idle_timeout
        while self.stop_reason is None:
            entry = self.agent._next(timeout=1.0)
            if entry is None:
                if self.interrupted:
                    break
                if self.agent.proc.poll() is not None:
                    raise AcpError("agent exited before finishing the answer")
                if time.monotonic() > idle_deadline:
                    log(f"no response for {int(self.args.idle_timeout)}s, cancelling")
                    self.interrupt(signal.SIGINT, None)
                    self.exit_code = 1
                    break
                continue
            before = self._streamed
            self._dispatch(entry)
            if self._streamed != before:
                idle_deadline = time.monotonic() + self.args.idle_timeout
        if self.stop_reason in ("refusal", "max_tokens", "max_turn_requests"):
            log(f"agent stopped early: {self.stop_reason}")

    def _dispatch(self, message):
        method = message.get("method")
        if method == "session/update":
            self._on_update(message.get("params") or {})
            return
        if method and "id" in message:
            self._on_agent_request(message)
            return
        if message.get("id") == "prompt":
            if "error" in message:
                error = message["error"]
                if _looks_like_auth(error):
                    self.exit_code = 3
                    log(f"agent requires authentication: {_error_text(error)}")
                    self._print_auth_hint()
                else:
                    raise AcpError(f"prompt failed: {_error_text(error)}")
                self.stop_reason = "error"
                return
            result = message.get("result") or {}
            self.stop_reason = result.get("stopReason") or "end_turn"

    def _on_update(self, params):
        update = params.get("update") or {}
        kind = update.get("sessionUpdate")
        if kind == "agent_message_chunk":
            text = (update.get("content") or {}).get("text", "")
            if text:
                sys.stdout.write(text)
                sys.stdout.flush()
                self._streamed += len(text)
        elif kind in ("agent_thought_chunk", "tool_call", "tool_call_update", "plan"):
            if self.args.verbose:
                log(f"{kind}: {json.dumps(update, ensure_ascii=False)[:300]}")
        elif kind == "notice" and self.args.verbose:
            log(f"notice: {update.get('title', '')} {update.get('description', '')}".strip())
        # available_commands_update / usage_update / current_mode_update: ignored

    def _on_agent_request(self, message):
        method = message.get("method")
        req_id = message.get("id")
        if method == "session/request_permission":
            reply = self._permission_reply(message.get("params") or {})
        elif method == "fs/read_text_file":
            reply = self._read_file(message.get("params") or {})
        elif method == "fs/write_text_file":
            reply = {"error": {"code": -32601, "message": "file writes are not supported"}}
        else:
            reply = {"error": {"code": -32601, "message": f"method not supported: {method}"}}
        payload = {"jsonrpc": "2.0", "id": req_id}
        payload.update(reply)
        try:
            self.agent.send(payload)
        except AcpError:
            pass

    def _permission_reply(self, params):
        tool_call = params.get("toolCall") or {}
        kind = tool_call.get("kind")
        title = tool_call.get("title") or kind or "tool"
        options = params.get("options") or []
        if self.args.permission == "allow-read" and kind in READ_ONLY_KINDS:
            chosen = _first_option(options, ("allow_once", "allow_session", "allow_always"))
            if chosen:
                return {"result": {"outcome": {"outcome": "selected", "optionId": chosen}}}
        log(f"permission denied for tool: {title} (kind={kind})")
        denied = _first_option(options, ("reject_once", "reject_always"))
        if denied:
            return {"result": {"outcome": {"outcome": "selected", "optionId": denied}}}
        return {"result": {"outcome": {"outcome": "cancelled"}}}

    def _read_file(self, params):
        path = params.get("path") or ""
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as fh:
                lines = fh.read().splitlines()
        except OSError as exc:
            return {"error": {"code": -32000, "message": f"cannot read {path}: {exc}"}}
        line = params.get("line")
        limit = params.get("limit")
        if line:
            start = max(int(line) - 1, 0)
            end = start + int(limit) if limit else None
            lines = lines[start:end]
        return {"result": {"content": "\n".join(lines)}}

    def _print_auth_hint(self):
        methods = ", ".join(m.get("name") or m.get("id", "?") for m in self.auth_methods)
        log(f"available auth methods: {methods or 'none advertised'}")
        log("run the agent's login command in a terminal, then retry")

    # --- lifecycle -----------------------------------------------------

    def interrupt(self, _signum, _frame):
        self.interrupted = True
        try:
            self.agent.send(
                {"jsonrpc": "2.0", "method": "session/cancel", "params": {"sessionId": self.session_id}}
            )
        except AcpError:
            pass

    def close(self):
        # One-shot client: ending the subprocess ends the session. `session/close`
        # stays unused until sessions are reused across queries (later phase).
        self.agent.terminate()
        self.trace.close()


def _first_option(options, kinds):
    for option in options:
        if option.get("kind") in kinds:
            return option.get("optionId")
    return None


def _looks_like_auth(error):
    text = json.dumps(error, ensure_ascii=False).lower()
    return "auth" in text or "login" in text


def parse_args(argv):
    parser = argparse.ArgumentParser(
        description="Run an ACP agent and stream its answer as Markdown.",
        add_help=True,
    )
    parser.add_argument("--agent", default=os.environ.get("ASK_AI_AGENT_CMD") or DEFAULT_AGENT,
                        help=f'agent command line (default: "{DEFAULT_AGENT}")')
    parser.add_argument("--cwd", default=None, help="session working directory")
    parser.add_argument("--model", default=None, help="model config option value")
    parser.add_argument("--effort", default=None, help="reasoning effort option value")
    parser.add_argument("--mode", default=None, help="session mode (plan/build)")
    parser.add_argument("--permission", choices=("allow-read", "deny"), default="allow-read",
                        help="policy for session/request_permission (default: allow-read)")
    parser.add_argument("--idle-timeout", type=float,
                        default=float(os.environ.get("ASK_AI_ACP_IDLE_TIMEOUT") or 180),
                        help="cancel when no answer text arrives for this many seconds (default: 180)")
    parser.add_argument("--trace", default=os.environ.get("ASK_AI_ACP_TRACE") or None,
                        help="append JSON-RPC traffic to this file")
    parser.add_argument("--verbose", action="store_true", help="agent thoughts, tools, info on stderr")
    parser.add_argument("query", help="question to ask")
    parser.add_argument("files", nargs="*", help="files attached as resource links")
    return parser.parse_args(argv)


def main(argv):
    args = parse_args(argv)
    if args.cwd is None:
        first = args.files[0] if args.files else ""
        args.cwd = os.path.dirname(os.path.abspath(first)) if first else os.getcwd()
    if not os.path.isdir(args.cwd):
        log(f"cwd does not exist: {args.cwd}")
        return 1

    client = Client(args)
    signal.signal(signal.SIGINT, client.interrupt)
    signal.signal(signal.SIGTERM, client.interrupt)
    try:
        client.connect()
        client.run_prompt()
    except AcpError as exc:
        log(str(exc))
        client.exit_code = client.exit_code or 1
    except KeyboardInterrupt:
        client.exit_code = 130
    finally:
        client.close()
    if client.interrupted and client.exit_code == 0:
        client.exit_code = 130
    if client.exit_code == 0:
        sys.stdout.write("\n")
        sys.stdout.flush()
    return client.exit_code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
