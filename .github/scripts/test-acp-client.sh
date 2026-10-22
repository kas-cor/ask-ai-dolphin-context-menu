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
#   9. --trace records both directions of the conversation

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
if [ -s "$TEST_DIR/err-basic.txt" ]; then
    fail "Quiet mode leaked to stderr: $(head -2 "$TEST_DIR/err-basic.txt")"
else
    pass "Thoughts and tool calls stay silent without --verbose"
fi

rc=$(run_client verbose -- --verbose "What is up?")
if grep -q "agent_thought_chunk" "$TEST_DIR/err-verbose.txt" \
    && grep -q "tool_call" "$TEST_DIR/err-verbose.txt"; then
    pass "--verbose reports thoughts and tool calls on stderr"
else
    fail "--verbose did not report protocol activity"
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
print_header "9. Trace file"
# ------------------------------------------------------
rc=$(run_client traced -- --trace "$TEST_DIR/trace.log" "Question")
if grep -q '^-> {"jsonrpc"' "$TEST_DIR/trace.log" \
    && grep -q '^<- {"jsonrpc"' "$TEST_DIR/trace.log"; then
    pass "Trace records both directions"
else
    fail "Trace file missing traffic"
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
