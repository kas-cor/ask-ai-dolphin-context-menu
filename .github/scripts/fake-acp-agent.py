#!/usr/bin/env python3
"""Fake ACP agent for CI.

Speaks just enough of the protocol to exercise ask-ai-acp-client.py without a
network, an API key or a real harness. Behaviour is selected with env vars:

  FAKE_ACP_SCENARIO   basic (default) | hang | error | auth | permission
  FAKE_ACP_TOOL_KIND  tool kind reported in the permission request (default: edit)
  FAKE_ACP_LOG        JSON-lines file recording what the agent observed
  FAKE_ACP_NO_OPTIONS "1" → session/new without model/effort/mode options
  FAKE_ACP_LOAD       "1" → advertise loadSession and accept session/load
  FAKE_ACP_LOAD_FAIL  "1" → make session/load fail (expired session)
  FAKE_ACP_REPLAY     "1" → replay old chunks on session/load, as real agents do
"""

import json
import os
import sys
import time

SCENARIO = os.environ.get("FAKE_ACP_SCENARIO", "basic")
TOOL_KIND = os.environ.get("FAKE_ACP_TOOL_KIND", "edit")
LOG_PATH = os.environ.get("FAKE_ACP_LOG", "")
NO_OPTIONS = os.environ.get("FAKE_ACP_NO_OPTIONS") == "1"
MODE_VALUES = [v for v in (os.environ.get("FAKE_ACP_MODES") or "plan,build").split(",") if v]
LOAD_SESSION = os.environ.get("FAKE_ACP_LOAD") == "1"
LOAD_FAIL = os.environ.get("FAKE_ACP_LOAD_FAIL") == "1"
REPLAY = os.environ.get("FAKE_ACP_REPLAY") == "1"
SESSION_ID = "sess_fake_1"


def record(**fields):
    if not LOG_PATH:
        return
    try:
        with open(LOG_PATH, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(fields, ensure_ascii=False) + "\n")
    except OSError:
        pass


def send(payload):
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def notify(update):
    send(
        {
            "jsonrpc": "2.0",
            "method": "session/update",
            "params": {"sessionId": SESSION_ID, "update": update},
        }
    )


def chunk(text):
    notify(
        {
            "sessionUpdate": "agent_message_chunk",
            "messageId": "msg_1",
            "content": {"type": "text", "text": text},
        }
    )


def config_options():
    if NO_OPTIONS:
        return []
    return [
        {
            "id": "model",
            "name": "Model",
            "category": "model",
            "type": "select",
            "currentValue": "fake/default",
            "options": [
                {"value": "fake/default", "name": "Default"},
                {"value": "fake/small", "name": "Small"},
            ],
        },
        {
            "id": "effort",
            "name": "Effort",
            "category": "thought_level",
            "type": "select",
            "currentValue": "default",
            "options": [
                {"value": "default", "name": "Default"},
                {"value": "high", "name": "High"},
            ],
        },
        {
            "id": "mode",
            "name": "Mode",
            "category": "mode",
            "type": "select",
            "currentValue": MODE_VALUES[0],
            "options": [{"value": v, "name": v} for v in MODE_VALUES],
        },
    ]


def prompt_turn(params):
    record(
        cwd=params.get("cwd"),
        prompt=params.get("prompt"),
        session=params.get("sessionId"),
    )
    if SCENARIO == "error":
        send(
            {
                "jsonrpc": "2.0",
                "id": "prompt",
                "error": {"code": -32603, "message": "provider exploded"},
            }
        )
        return
    if SCENARIO == "auth":
        send(
            {
                "jsonrpc": "2.0",
                "id": "prompt",
                "error": {"code": -32000, "message": "authentication required: run login"},
            }
        )
        return

    notify(
        {
            "sessionUpdate": "agent_thought_chunk",
            "content": {"type": "text", "text": "thinking about it"},
        }
    )
    notify(
        {
            "sessionUpdate": "tool_call",
            "toolCallId": "call_1",
            "title": "Reading files",
            "kind": "read",
            "status": "pending",
        }
    )

    if SCENARIO == "permission":
        send(
            {
                "jsonrpc": "2.0",
                "id": "perm-1",
                "method": "session/request_permission",
                "params": {
                    "sessionId": SESSION_ID,
                    "toolCall": {"toolCallId": "call_2", "title": "Edit file", "kind": TOOL_KIND},
                    "options": [
                        {"optionId": "allow", "name": "Allow", "kind": "allow_once"},
                        {"optionId": "deny", "name": "Deny", "kind": "reject_once"},
                    ],
                },
            }
        )
        return  # the reply is handled by the main loop

    if SCENARIO == "hang":
        return

    chunk("Hello ")
    chunk("from ACP")
    send({"jsonrpc": "2.0", "id": "prompt", "result": {"stopReason": "end_turn"}})


def main():
    for raw in sys.stdin:
        line = raw.strip()
        if not line:
            continue
        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            record(bad_json=line[:120])
            continue

        method = message.get("method")
        req_id = message.get("id")
        params = message.get("params") or {}

        if method is None:
            # A response to our own request (permission).
            if req_id == "perm-1":
                outcome = ((message.get("result") or {}).get("outcome") or {}).get("outcome")
                option_id = ((message.get("result") or {}).get("outcome") or {}).get("optionId")
                record(permission_outcome=outcome, permission_option=option_id)
                if outcome == "selected" and option_id:
                    chunk(f"permission={option_id}")
                else:
                    chunk("permission=denied")
                notify(
                    {
                        "sessionUpdate": "tool_call_update",
                        "toolCallId": "call_2",
                        "status": "completed",
                    }
                )
                send({"jsonrpc": "2.0", "id": "prompt", "result": {"stopReason": "end_turn"}})
            continue

        if method == "initialize":
            send(
                {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {
                        "protocolVersion": 1,
                        "agentCapabilities": {
                            "loadSession": LOAD_SESSION,
                            "promptCapabilities": {"embeddedContext": True, "image": False},
                        },
                        "authMethods": [
                            {"id": "fake-login", "name": "Login with fake"}
                        ],
                        "agentInfo": {"name": "Fake ACP", "version": "0.0.1"},
                    },
                }
            )
        elif method == "session/load":
            record(loaded_session=params.get("sessionId"), load_cwd=params.get("cwd"))
            if LOAD_FAIL:
                send(
                    {
                        "jsonrpc": "2.0",
                        "id": req_id,
                        "error": {"code": -32002, "message": "session not found"},
                    }
                )
                continue
            if REPLAY:
                # Real agents replay the stored conversation as updates before
                # answering session/load; the client must not print that back.
                notify(
                    {
                        "sessionUpdate": "user_message_chunk",
                        "content": {"type": "text", "text": "previous question"},
                    }
                )
                chunk("OLD-HISTORY ")
                chunk("FROM PREVIOUS TURN")
            send(
                {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {
                        "sessionId": params.get("sessionId") or SESSION_ID,
                        "configOptions": config_options(),
                    },
                }
            )
        elif method == "session/new":
            record(new_session=True, session_new_cwd=params.get("cwd"))
            send(
                {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {"sessionId": SESSION_ID, "configOptions": config_options()},
                }
            )
        elif method == "session/set_config_option":
            config_id = params.get("configId")
            value = params.get("value")
            known = {opt["id"]: [o["value"] for o in opt["options"]] for opt in config_options()}
            if config_id not in known:
                send(
                    {
                        "jsonrpc": "2.0",
                        "id": req_id,
                        "error": {"code": -32602, "message": f"unknown config option: {config_id}"},
                    }
                )
                continue
            if value not in known[config_id]:
                send(
                    {
                        "jsonrpc": "2.0",
                        "id": req_id,
                        "error": {"code": -32602, "message": f"{config_id} not found: {value}"},
                    }
                )
                continue
            record(config_set={config_id: value})
            options = config_options()
            for opt in options:
                if opt["id"] == config_id:
                    opt["currentValue"] = value
            send({"jsonrpc": "2.0", "id": req_id, "result": {"configOptions": options}})
        elif method == "session/prompt":
            prompt_turn(params)
        elif method == "session/cancel":
            record(cancelled=True)
            send({"jsonrpc": "2.0", "id": "prompt", "result": {"stopReason": "cancelled"}})
        else:
            send(
                {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "error": {"code": -32601, "message": f"unsupported: {method}"},
                }
            )


if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:
        pass
    except KeyboardInterrupt:
        pass
    time.sleep(0)
