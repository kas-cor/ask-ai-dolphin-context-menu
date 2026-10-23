#!/bin/bash
# CI test: ask-ai-acp-client.py (phase 0 ACP client)
# Tests:
#   1. Streams only agent text to stdout; thoughts/tools stay on stderr
#   2. Attachments are sent as resource_link blocks with absolute file:// URIs
#   3. Model / effort / mode are applied through session/set_config_option
#   4. An agent without config options is not fatal (warning + answer)
#   5. Permission policy: write-like tools denied, read-only tools allowed
#   6. Agent error → exit 1; auth-required error → exit 3 with a hint
#   7. SIGINT sends session/cancel and exits 130
#   8. --idle-timeout cancels a silent agent instead of hanging forever
#   9. --probe reports capabilities without starting a conversation
#  10. --reuse-session stores and resumes sessions, with a new-session fallback
#      and no replayed history in the new answer
#  11. --permission ask: terminal prompt, safe deny when there is no terminal
#  12. --trace records both directions of the conversation
#  13. --context text blocks and a sane ASK_AI_ACP_IDLE_TIMEOUT
#  14. Agent requests made outside the prompt turn are served, not queued
#      (a permission request before session/set_config_option answers)
#  15. An invalid permission policy names the accepted values

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CLIENT="$PROJECT_DIR/src/ask-ai-acp-client.py"
FAKE_AGENT="$SCRIPT_DIR/fake-acp-agent.py"
AGENT_CMD="python3 $FAKE_AGENT"
FAILED=0

print_header() {
    echo ""
    echo "=================================================="
    echo "  $1"
    echo "=================================================="
}

pass() { echo "  ✅ $1"; }
fail() { echo "  ❌ FAILED: $1"; FAILED=1; }

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

LOG_FILE="$TEST_DIR/agent.log"
ATTACH_FILE="$TEST_DIR/attached file.txt"
printf 'file body\n' >"$ATTACH_FILE"

# run_client <label> [env assignments...] -- <client args...>
run_client() {
    local label="$1"
    shift
    local -a envs=()
    while [ "$1" != "--" ]; do
        envs+=("$1")
        shift
    done
    shift
    : >"$LOG_FILE"
    local rc=0
    env "${envs[@]}" FAKE_ACP_LOG="$LOG_FILE" \
        python3 "$CLIENT" --agent "$AGENT_CMD" --cwd "$TEST_DIR" "$@" \
        >"$TEST_DIR/out-$label.txt" 2>"$TEST_DIR/err-$label.txt" || rc=$?
    echo "$rc"
}

agent_log_has() { grep -qF -- "$1" "$LOG_FILE"; }

# ------------------------------------------------------
print_header "1. Streaming: answer on stdout, reasoning on stderr"
# ------------------------------------------------------
rc=$(run_client basic -- "What is up?")
if [ "$rc" -eq 0 ]; then
    pass "Basic turn exits 0"
else
    fail "Basic turn exited $rc: $(cat "$TEST_DIR/err-basic.txt")"
fi
if [ "$(cat "$TEST_DIR/out-basic.txt")" = "Hello from ACP" ]; then
    pass "stdout contains only the agent's Markdown text"
else
    fail "Unexpected stdout: $(head -c 200 "$TEST_DIR/out-basic.txt")"
fi
# The indicator is localized, and these tests inherit the developer's $LANG.
case "$(cat "$TEST_DIR/err-basic.txt")" in
    "Thinking..."|"Думает...")
        pass "Quiet mode announces that the agent is thinking"
        ;;
    *)
        fail "Unexpected quiet-mode stderr: $(head -2 "$TEST_DIR/err-basic.txt")"
        ;;
esac
rc=$(run_client thinking-en ASK_AI_LOCALE=en_EN -- "What is up?")
if [ "$(cat "$TEST_DIR/err-thinking-en.txt")" = "Thinking..." ]; then
    pass "The thinking indicator follows ASK_AI_LOCALE (en)"
else
    fail "English indicator missing: $(head -2 "$TEST_DIR/err-thinking-en.txt")"
fi
if grep -qi 'thinking about it\|agent_thought_chunk' "$TEST_DIR/err-basic.txt"; then
    fail "Quiet mode still leaked the thoughts themselves"
else
    pass "Thoughts and tool calls stay hidden without --verbose"
fi
rc=$(run_client thinking-ru ASK_AI_LOCALE=ru_RU -- "What is up?")
if [ "$(cat "$TEST_DIR/err-thinking-ru.txt")" = "Думает..." ]; then
    pass "The thinking indicator follows ASK_AI_LOCALE (ru)"
else
    fail "Russian indicator missing: $(head -2 "$TEST_DIR/err-thinking-ru.txt")"
fi

rc=$(run_client verbose -- --verbose "What is up?")
if grep -q "agent_thought_chunk" "$TEST_DIR/err-verbose.txt" \
    && grep -q "tool_call" "$TEST_DIR/err-verbose.txt"; then
    pass "--verbose reports thoughts and tool calls on stderr"
else
    fail "--verbose did not report protocol activity"
fi
if grep -qxF 'Thinking...' "$TEST_DIR/err-verbose.txt"; then
    fail "--verbose still printed the thinking indicator"
else
    pass "--verbose replaces the indicator with the real thoughts"
fi
if grep -q '"jsonrpc"' "$TEST_DIR/out-verbose.txt"; then
    fail "Protocol traffic leaked into stdout"
else
    pass "Protocol traffic never reaches stdout"
fi

# ------------------------------------------------------
print_header "2. Attachments become resource_link blocks"
# ------------------------------------------------------
rc=$(run_client attach -- "Describe the file" "$ATTACH_FILE")
if grep -q '"type": "resource_link"' "$LOG_FILE"; then
    pass "Attachment sent as resource_link"
else
    fail "No resource_link in the prompt: $(head -c 300 "$LOG_FILE")"
fi
expected_uri="file://$(printf '%s' "$ATTACH_FILE" | sed 's/ /%20/g')"
if grep -qF "$expected_uri" "$LOG_FILE"; then
    pass "Absolute file:// URI with escaped spaces"
else
    fail "Expected $expected_uri in the prompt"
fi
if grep -qF 'attached file.txt' "$LOG_FILE"; then
    pass "Attachment keeps its display name"
else
    fail "Attachment name missing from the prompt"
fi

# ------------------------------------------------------
print_header "3. Model / effort / mode via session/set_config_option"
# ------------------------------------------------------
rc=$(run_client config -- --model fake/small --effort high --mode build "Question")
if [ "$rc" -eq 0 ]; then
    pass "Configured turn exits 0"
else
    fail "Configured turn exited $rc: $(cat "$TEST_DIR/err-config.txt")"
fi
for expected in '"model": "fake/small"' '"effort": "high"' '"mode": "build"'; do
    if agent_log_has "$expected"; then
        pass "Agent applied $expected"
    else
        fail "Agent did not receive $expected"
    fi
done

# Agents name modes differently: plan/build must be mapped, not rejected.
rc=$(run_client modealias FAKE_ACP_MODES=read-only,auto -- --mode plan "Question")
if agent_log_has '"mode": "read-only"'; then
    pass "Mode 'plan' mapped to the agent's 'read-only'"
else
    fail "Mode alias not applied: $(grep config_set "$LOG_FILE" | tr '\n' ' ')"
fi
rc=$(run_client modealias2 FAKE_ACP_MODES=read-only,auto -- --mode build "Question")
if agent_log_has '"mode": "auto"'; then
    pass "Mode 'build' mapped to the agent's 'auto'"
else
    fail "Mode alias for build not applied"
fi

rc=$(run_client badmodel -- --model fake/nope "Question")
if [ "$rc" -eq 0 ] && grep -q "ignored" "$TEST_DIR/err-badmodel.txt" \
    && grep -q "Hello from ACP" "$TEST_DIR/out-badmodel.txt"; then
    pass "Unknown model value warns and still answers"
else
    fail "Invalid model should warn, not fail (rc=$rc)"
fi

# ------------------------------------------------------
print_header "4. Agent without config options"
# ------------------------------------------------------
: >"$LOG_FILE"
rc=0
FAKE_ACP_NO_OPTIONS=1 FAKE_ACP_LOG="$LOG_FILE" \
    python3 "$CLIENT" --agent "$AGENT_CMD" --cwd "$TEST_DIR" --model fake/small "Question" \
    >"$TEST_DIR/out-noopts.txt" 2>"$TEST_DIR/err-noopts.txt" || rc=$?
if [ "$rc" -eq 0 ] && grep -q "no model option" "$TEST_DIR/err-noopts.txt"; then
    pass "Missing model option is a warning, not an error"
else
    fail "Missing model option handling wrong (rc=$rc): $(cat "$TEST_DIR/err-noopts.txt")"
fi
if grep -q "Hello from ACP" "$TEST_DIR/out-noopts.txt"; then
    pass "Answer still arrives without config options"
else
    fail "No answer when the agent exposes no config options"
fi

# ------------------------------------------------------
print_header "5. Permission policy"
# ------------------------------------------------------
rc=$(run_client perm-write FAKE_ACP_SCENARIO=permission -- "Edit something")
if agent_log_has '"permission_option": "deny"'; then
    pass "Write-like tool call denied (plan-safe default)"
else
    fail "Write-like tool call was not denied: $(grep permission "$LOG_FILE" || echo none)"
fi
if grep -q "permission=deny" "$TEST_DIR/out-perm-write.txt"; then
    pass "Agent was told the permission outcome"
else
    fail "Denial never reached the agent"
fi

rc=$(run_client perm-read FAKE_ACP_SCENARIO=permission FAKE_ACP_TOOL_KIND=read -- "Read something")
if agent_log_has '"permission_option": "allow"'; then
    pass "Read-only tool call allowed with allow-read policy"
else
    fail "Read-only tool call was not allowed: $(grep permission "$LOG_FILE" || echo none)"
fi

# ------------------------------------------------------
print_header "6. Errors and authentication"
# ------------------------------------------------------
rc=$(run_client err FAKE_ACP_SCENARIO=error -- "Question")
if [ "$rc" -eq 1 ] && grep -q "provider exploded" "$TEST_DIR/err-err.txt"; then
    pass "Agent error surfaces with the agent's message (exit 1)"
else
    fail "Agent error handling wrong (rc=$rc): $(cat "$TEST_DIR/err-err.txt")"
fi

rc=$(run_client auth FAKE_ACP_SCENARIO=auth -- "Question")
if [ "$rc" -eq 3 ] && grep -q "authentication" "$TEST_DIR/err-auth.txt"; then
    pass "Auth-required error exits 3 with a hint"
else
    fail "Auth error handling wrong (rc=$rc): $(cat "$TEST_DIR/err-auth.txt")"
fi

# ------------------------------------------------------
print_header "7. SIGINT cancels the session"
# ------------------------------------------------------
: >"$LOG_FILE"
rc=0
FAKE_ACP_SCENARIO=hang FAKE_ACP_LOG="$LOG_FILE" \
    python3 "$CLIENT" --agent "$AGENT_CMD" --cwd "$TEST_DIR" "Hang" \
    >"$TEST_DIR/out-cancel.txt" 2>"$TEST_DIR/err-cancel.txt" &
client_pid=$!
sleep 2
kill -INT "$client_pid" 2>/dev/null || true
wait "$client_pid" || rc=$?
if [ "$rc" -eq 130 ]; then
    pass "Interrupted client exits 130"
else
    fail "Interrupted client exited $rc"
fi
if agent_log_has '"cancelled": true'; then
    pass "session/cancel delivered to the agent"
else
    fail "Agent never received session/cancel"
fi

# ------------------------------------------------------
print_header "8. Idle timeout"
# ------------------------------------------------------
rc=$(run_client idle FAKE_ACP_SCENARIO=hang -- --idle-timeout 1 "Hang")
if [ "$rc" -eq 1 ] && grep -q "cancelling" "$TEST_DIR/err-idle.txt"; then
    pass "Silent agent is cancelled after --idle-timeout"
else
    fail "Idle timeout not honoured (rc=$rc): $(cat "$TEST_DIR/err-idle.txt")"
fi

# ------------------------------------------------------
print_header "9. Probe mode"
# ------------------------------------------------------
rc=0
python3 "$CLIENT" --agent "$AGENT_CMD" --cwd "$TEST_DIR" --probe \
    >"$TEST_DIR/probe.json" 2>"$TEST_DIR/err-probe.txt" || rc=$?
if [ "$rc" -eq 0 ] && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["capabilities"]; assert d["configOptions"]' "$TEST_DIR/probe.json"; then
    pass "--probe reports capabilities and config options as JSON"
else
    fail "Probe failed (rc=$rc): $(cat "$TEST_DIR/err-probe.txt")"
fi

# ------------------------------------------------------
print_header "10. Session reuse"
# ------------------------------------------------------
STORE="$TEST_DIR/sessions.json"
rm -f "$STORE"
rc=$(run_client reuse1 FAKE_ACP_LOAD=1 -- --reuse-session --session-store "$STORE" "First question")
if [ -f "$STORE" ] && agent_log_has '"new_session": true'; then
    pass "First run creates a session and remembers it"
else
    fail "Session was not stored (rc=$rc)"
fi
rc=$(run_client reuse2 FAKE_ACP_LOAD=1 -- --reuse-session --session-store "$STORE" "Second question")
if agent_log_has '"loaded_session": "sess_fake_1"'; then
    pass "Second run resumes the stored session with session/load"
else
    fail "Session was not resumed (rc=$rc): $(head -c 200 "$LOG_FILE")"
fi
if grep -qF 'Hello from ACP' "$TEST_DIR/out-reuse2.txt"; then
    pass "Resumed session still answers"
else
    fail "Resumed session produced no answer"
fi

# session/load replays the stored conversation: none of it belongs in this
# answer (it would otherwise land in stdout, the clipboard and the saved .md).
rc=$(run_client replay FAKE_ACP_LOAD=1 FAKE_ACP_REPLAY=1 -- --reuse-session --session-store "$STORE" "Second question again")
if agent_log_has '"loaded_session"' && [ "$(cat "$TEST_DIR/out-replay.txt")" = "Hello from ACP" ]; then
    pass "Replayed history stays out of the new answer"
else
    fail "Replayed history leaked into stdout: $(cat "$TEST_DIR/out-replay.txt")"
fi

rc=$(run_client reuse3 FAKE_ACP_LOAD=1 FAKE_ACP_LOAD_FAIL=1 -- --reuse-session --session-store "$STORE" "Third question")
if agent_log_has '"new_session": true' && grep -qF 'Hello from ACP' "$TEST_DIR/out-reuse3.txt"; then
    pass "Expired session falls back to a new one"
else
    fail "Expired session handling wrong (rc=$rc)"
fi

rc=$(run_client noreuse FAKE_ACP_LOAD=1 -- --session-store "$STORE" "Fourth question")
if agent_log_has '"new_session": true' && ! agent_log_has '"loaded_session"'; then
    pass "Without --reuse-session a fresh session is always created"
else
    fail "Session was reused without asking"
fi

# ------------------------------------------------------
print_header "11. Interactive permission policy (ask)"
# ------------------------------------------------------
# No controlling terminal (setsid): the question cannot be asked, so the tool
# must be denied instead of blocking or gaining rights by accident.
: >"$LOG_FILE"
rc=0
setsid env FAKE_ACP_SCENARIO=permission FAKE_ACP_LOG="$LOG_FILE" \
    python3 "$CLIENT" --agent "$AGENT_CMD" --cwd "$TEST_DIR" --permission ask "Edit something" \
    </dev/null >"$TEST_DIR/out-ask-notty.txt" 2>"$TEST_DIR/err-ask-notty.txt" || rc=$?
if agent_log_has '"permission_option": "deny"' \
    && grep -q "no terminal" "$TEST_DIR/err-ask-notty.txt"; then
    pass "Without a terminal, ask-mode denies and says why"
else
    fail "ask-mode without a tty misbehaved (rc=$rc): $(cat "$TEST_DIR/err-ask-notty.txt")"
fi

# With a pseudo-terminal and an explicit "y", the same tool is allowed.
: >"$LOG_FILE"
cat >"$TEST_DIR/ask-yes.sh" <<ASKYES
#!/bin/bash
FAKE_ACP_SCENARIO=permission FAKE_ACP_LOG="$LOG_FILE" \\
    python3 "$CLIENT" --agent "$AGENT_CMD" --cwd "$TEST_DIR" --permission ask "Edit something"
ASKYES
chmod +x "$TEST_DIR/ask-yes.sh"
printf 'y\n' | script -qec "bash $TEST_DIR/ask-yes.sh" /dev/null \
    >"$TEST_DIR/out-ask-yes.txt" 2>"$TEST_DIR/err-ask-yes.txt" || true
if agent_log_has '"permission_option": "allow"'; then
    pass "ask-mode allows the tool after a 'y' on the terminal"
else
    fail "ask-mode did not accept the answer: $(cat "$TEST_DIR/err-ask-yes.txt")"
fi

# ------------------------------------------------------
print_header "12. Trace file"
# ------------------------------------------------------
rc=$(run_client traced -- --trace "$TEST_DIR/trace.log" "Question")
if grep -q '^-> {"jsonrpc"' "$TEST_DIR/trace.log" \
    && grep -q '^<- {"jsonrpc"' "$TEST_DIR/trace.log"; then
    pass "Trace records both directions"
else
    fail "Trace file missing traffic"
fi

# ------------------------------------------------------
print_header "13. Context blocks and idle-timeout parsing"
# ------------------------------------------------------
DIRECTORY_CONTEXT=$'Directory listing of /tmp/demo:\n- notes.md'
rc=$(run_client context -- --context "$DIRECTORY_CONTEXT" "What is in this folder?")
if python3 - "$LOG_FILE" <<'PY'
import json, sys
entries = [json.loads(line) for line in open(sys.argv[1], encoding="utf-8") if line.strip()]
blocks = next(entry["prompt"] for entry in entries if "prompt" in entry)
assert blocks[0]["type"] == "text" and "Directory listing of /tmp/demo:" in blocks[0]["text"], blocks
assert blocks[-1]["text"] == "What is in this folder?", blocks
PY
then
    pass "--context is sent as the leading text block"
else
    fail "--context was not delivered: $(head -c 300 "$LOG_FILE")"
fi

# A typo in the timeout variable must not take the whole query down.
rc=0
: >"$LOG_FILE"
env ASK_AI_ACP_IDLE_TIMEOUT=abc FAKE_ACP_LOG="$LOG_FILE" \
    python3 "$CLIENT" --agent "$AGENT_CMD" --cwd "$TEST_DIR" "Timeout typo" \
    >"$TEST_DIR/out-idle-env.txt" 2>"$TEST_DIR/err-idle-env.txt" || rc=$?
if [ "$rc" -eq 0 ] && grep -q 'Hello from ACP' "$TEST_DIR/out-idle-env.txt" \
    && grep -q 'ignoring ASK_AI_ACP_IDLE_TIMEOUT' "$TEST_DIR/err-idle-env.txt"; then
    pass "A non-numeric ASK_AI_ACP_IDLE_TIMEOUT warns and falls back"
else
    fail "Bad idle timeout broke the run (rc=$rc): $(head -2 "$TEST_DIR/err-idle-env.txt")"
fi

# ------------------------------------------------------
print_header "14. Agent request during a config call"
# ------------------------------------------------------
# The agent blocks on session/request_permission before answering
# session/set_config_option. The client must answer it right there; holding it
# in the queue until the prompt turn would stall the handshake.
rc=$(run_client early-perm FAKE_ACP_EARLY_PERMISSION=1 -- --verbose --model fake/small "Question")
if [ "$rc" -eq 0 ] && [ "$(cat "$TEST_DIR/out-early-perm.txt")" = "Hello from ACP" ]; then
    pass "Config call served the agent's permission request and the turn finished"
else
    fail "Agent request during a config call stalled (rc=$rc): $(head -3 "$TEST_DIR/err-early-perm.txt")"
fi
if agent_log_has '"pre_permission_option": "allow"'; then
    pass "Read-only permission granted while the config call was in flight"
else
    fail "Permission request was not answered: $(grep pre_permission "$LOG_FILE" || echo none)"
fi
if agent_log_has '"model": "fake/small"'; then
    pass "Config call completed after the permission reply"
else
    fail "Config call never completed"
fi
if grep -q "agent_thought_chunk" "$TEST_DIR/err-early-perm.txt"; then
    pass "Notifications received meanwhile are kept for the main loop"
else
    fail "Notification sent during the config call was lost: $(cat "$TEST_DIR/err-early-perm.txt")"
fi

# ------------------------------------------------------
print_header "15. Invalid permission policy"
# ------------------------------------------------------
rc=0
: >"$LOG_FILE"
env ASK_AI_PERMISSION=bogus FAKE_ACP_LOG="$LOG_FILE" \
    python3 "$CLIENT" --agent "$AGENT_CMD" --cwd "$TEST_DIR" "Question" \
    >"$TEST_DIR/out-perm-bogus.txt" 2>"$TEST_DIR/err-perm-bogus.txt" || rc=$?
if [ "$rc" -eq 2 ] && grep -q 'unknown permission policy' "$TEST_DIR/err-perm-bogus.txt" \
    && grep -q 'ASK_AI_PERMISSION' "$TEST_DIR/err-perm-bogus.txt" \
    && grep -q 'allow-read, ask, deny' "$TEST_DIR/err-perm-bogus.txt"; then
    pass "A bad policy names the variable and the accepted values (exit 2)"
else
    fail "Bad permission policy handling wrong (rc=$rc): $(head -3 "$TEST_DIR/err-perm-bogus.txt")"
fi
if grep -q 'usage:' "$TEST_DIR/err-perm-bogus.txt"; then
    fail "The raw argparse usage dump is still printed"
else
    pass "No argparse usage dump in the message"
fi

# ------------------------------------------------------
echo ""
if [ "$FAILED" -eq 1 ]; then
    echo "❌ SOME TESTS FAILED"
    exit 1
else
    echo "✅ ALL TESTS PASSED"
    exit 0
fi
