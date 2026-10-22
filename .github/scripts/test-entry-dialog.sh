#!/bin/bash
# CI test: entry point (ask-ai-dolphin.sh) dialog/terminal handling
# Tests:
#   1. Cancel (dialog exits 1) → exit code 0, no terminal launched
#   2. Crash (dialog exits 2) → exit code 1, log path reported
#   3. ~/.ask_ai is sourced for the GUI path (model/locale visible to dialog)
#   4. Submitted query → exactly one terminal launch, ASK_AI_PAUSE=1 on the
#      command line (Konsole does not inherit the launcher's environment)
#   5. $TERMINAL with arguments is split and used (no konsole fallback)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
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

INSTALL_DIR="$TEST_DIR/install"
HOME_DIR="$TEST_DIR/home"
BIN_DIR="$TEST_DIR/bin"
mkdir -p "$INSTALL_DIR/locales" "$HOME_DIR" "$BIN_DIR"

cp "$PROJECT_DIR/src/ask-ai-dolphin.sh" "$INSTALL_DIR/"
cp "$PROJECT_DIR/src/ask-ai-common.sh" "$INSTALL_DIR/"
cp "$PROJECT_DIR"/locales/* "$INSTALL_DIR/locales/"

# The fake terminal executes this runner with a *cleared* environment (a real
# Konsole hands the command to an existing instance), so it records what the
# runner actually receives, not what the entry script exported.
cat >"$INSTALL_DIR/ask-ai-dolphin-run.sh" <<'RUNNER'
#!/bin/bash
{
    echo "runner: $*"
    echo "runner_pause=${ASK_AI_PAUSE:-unset}"
    echo "runner_model=${ASK_AI_MODEL:-unset}"
} >>"$FAKE_RUNNER_LOG"
RUNNER
chmod +x "$INSTALL_DIR/ask-ai-dolphin-run.sh"

DIALOG_LOG_FILE="$TEST_DIR/dialog-calls.log"
TERM_LOG_FILE="$TEST_DIR/terminal-calls.log"
RUNNER_LOG_FILE="$TEST_DIR/runner-calls.log"
: >"$DIALOG_LOG_FILE"
: >"$TERM_LOG_FILE"
: >"$RUNNER_LOG_FILE"

cat >"$INSTALL_DIR/ask-ai-dolphin-dialog.py" <<'DIALOG'
#!/bin/bash
{
    echo "argv: $*"
    echo "locale=${ASK_AI_LOCALE:-unset}"
    echo "model=${ASK_AI_MODEL:-unset}"
} >>"$FAKE_DIALOG_LOG"
case "${FAKE_DIALOG_MODE:-ok}" in
    cancel) exit 1 ;;
    crash)  echo "Traceback (most recent call last): boom" >&2; exit 2 ;;
    *)      printf 'fake query\n' ;;
esac
DIALOG
chmod +x "$INSTALL_DIR/ask-ai-dolphin-dialog.py"

# Both terminals emulate the real hand-off: Konsole (and KDE terminals in
# general) passes `-e cmd` to an already running instance, and the new session
# inherits THAT process's environment. `env -i` reproduces exactly that, which
# is what broke the "press Enter to close" pause: anything the entry script
# only exported never reached the runner.
cat >"$BIN_DIR/konsole" <<'TERM'
#!/bin/bash
{
    echo "konsole: $*"
    echo "pause=${ASK_AI_PAUSE:-unset}"
} >>"$FAKE_TERM_LOG"
[ "${1:-}" = "-e" ] && shift
exec env -i HOME="$HOME" PATH="$FAKE_CLEAN_PATH" \
    FAKE_RUNNER_LOG="$FAKE_RUNNER_LOG" "$@"
TERM
chmod +x "$BIN_DIR/konsole"

cat >"$BIN_DIR/fake-term" <<'TERM'
#!/bin/bash
{
    echo "fake-term: $*"
    echo "pause=${ASK_AI_PAUSE:-unset}"
} >>"$FAKE_TERM_LOG"
while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do shift; done
[ "${1:-}" = "--" ] && shift
exec env -i HOME="$HOME" PATH="$FAKE_CLEAN_PATH" \
    FAKE_RUNNER_LOG="$FAKE_RUNNER_LOG" "$@"
TERM
chmod +x "$BIN_DIR/fake-term"

SELECTED="$TEST_DIR/selected file.txt"
echo "content" >"$SELECTED"

run_entry() {
    : >"$DIALOG_LOG_FILE"
    : >"$TERM_LOG_FILE"
    : >"$RUNNER_LOG_FILE"
    env -i \
        HOME="$HOME_DIR" \
        PATH="$BIN_DIR:/usr/bin:/bin" \
        LANG=en_US.UTF-8 \
        SHELL=/bin/bash \
        FAKE_DIALOG_LOG="$DIALOG_LOG_FILE" \
        FAKE_TERM_LOG="$TERM_LOG_FILE" \
        FAKE_RUNNER_LOG="$RUNNER_LOG_FILE" \
        FAKE_CLEAN_PATH="$BIN_DIR:/usr/bin:/bin" \
        "$@" \
        bash "$INSTALL_DIR/ask-ai-dolphin.sh" "$SELECTED"
}

# ------------------------------------------------------
print_header "1. Cancel → exit 0"
# ------------------------------------------------------
rc=0
run_entry FAKE_DIALOG_MODE=cancel >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 0 ]; then
    pass "Dialog cancel returns 0 (no spurious error to Dolphin)"
else
    fail "Dialog cancel should return 0, got $rc"
fi
if [ -s "$TERM_LOG_FILE" ]; then
    fail "Cancel must not launch a terminal"
else
    pass "Cancel does not launch a terminal"
fi

# ------------------------------------------------------
print_header "2. Crash → exit 1 + log path, not treated as cancel"
# ------------------------------------------------------
rc=0
stderr_out=$(run_entry FAKE_DIALOG_MODE=crash 2>&1 >/dev/null) || rc=$?
if [ "$rc" -eq 1 ]; then
    pass "Dialog crash returns 1"
else
    fail "Dialog crash should return 1, got $rc"
fi
case "$stderr_out" in
    *dialog.log*) pass "Crash message points at the dialog log" ;;
    *)            fail "Crash message should mention dialog.log, got: '$stderr_out'" ;;
esac
if grep -q "Traceback" "$HOME_DIR/.cache/ask-ai/dialog.log" 2>/dev/null; then
    pass "Dialog stderr captured in ~/.cache/ask-ai/dialog.log"
else
    fail "Dialog stderr was not captured"
fi
if [ -s "$TERM_LOG_FILE" ]; then
    fail "Crash must not launch a terminal"
else
    pass "Crash does not launch a terminal"
fi

# ------------------------------------------------------
print_header "3. ~/.ask_ai is read on the GUI path"
# ------------------------------------------------------
cat >"$HOME_DIR/.ask_ai" <<'CFG'
export ASK_AI_MODEL="opencode/test-model-x"
export ASK_AI_LOCALE="ru_RU"
CFG

rc=0
run_entry FAKE_DIALOG_MODE=ok >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 0 ] && grep -q "model=opencode/test-model-x" "$DIALOG_LOG_FILE"; then
    pass "ASK_AI_MODEL from ~/.ask_ai reaches the dialog"
else
    fail "ASK_AI_MODEL from ~/.ask_ai was not applied"
fi
if grep -q "locale=ru_RU" "$DIALOG_LOG_FILE"; then
    pass "ASK_AI_LOCALE=ru_RU (full form) from ~/.ask_ai is honoured"
else
    fail "ASK_AI_LOCALE=ru_RU from ~/.ask_ai was ignored"
fi
rm -f "$HOME_DIR/.ask_ai"

# ------------------------------------------------------
print_header "4. Submitted query → single konsole launch"
# ------------------------------------------------------
rc=0
run_entry FAKE_DIALOG_MODE=ok ASK_AI_MODEL=parent-env-model >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 0 ]; then
    pass "Entry exits 0 after launching the terminal"
else
    fail "Entry should exit 0, got $rc"
fi
launches=$(grep -c '^konsole:' "$TERM_LOG_FILE" || true)
if [ "$launches" -eq 1 ]; then
    pass "Exactly one terminal launch"
else
    fail "Expected 1 terminal launch, got $launches"
fi
if grep -q -- "-e env ASK_AI_PAUSE=1 $INSTALL_DIR/ask-ai-dolphin-run.sh fake query" "$TERM_LOG_FILE"; then
    pass "Runner path and query passed after -e, pause flag on the command line"
else
    fail "konsole args wrong: $(cat "$TERM_LOG_FILE")"
fi
# The assertion above deliberately checks the command line, not the
# environment: a real Konsole hands the request to an already running instance
# and the new session never sees the variables exported by this script.
if grep -q "runner_pause=1" "$RUNNER_LOG_FILE"; then
    pass "Runner gets ASK_AI_PAUSE=1 across the env-dropping hand-off"
else
    fail "Runner did not get ASK_AI_PAUSE (log: $(cat "$RUNNER_LOG_FILE"))"
fi
# Sanity check of the simulation itself: if the fake terminal passed the
# caller's environment through, the pause test above would pass for the wrong
# reason (and the env drop would go unnoticed again).
if grep -q "runner_model=unset" "$RUNNER_LOG_FILE"; then
    pass "Simulated hand-off really drops the launcher's environment"
else
    fail "Fake terminal inherited the caller's env — simulation is not realistic"
fi

# ------------------------------------------------------
print_header "5. \$TERMINAL with arguments"
# ------------------------------------------------------
rc=0
run_entry TERMINAL="fake-term --flag" FAKE_DIALOG_MODE=ok >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 0 ] && [ "$(grep -c '^fake-term:' "$TERM_LOG_FILE" || true)" -eq 1 ]; then
    pass "Custom \$TERMINAL used exactly once"
else
    fail "\$TERMINAL handling wrong: rc=$rc log=$(cat "$TERM_LOG_FILE")"
fi
if grep -q -- "--flag -- env ASK_AI_PAUSE=1 $INSTALL_DIR/ask-ai-dolphin-run.sh fake query" "$TERM_LOG_FILE"; then
    pass "Extra terminal arguments preserved, command passed after --"
else
    fail "\$TERMINAL arguments wrong: $(cat "$TERM_LOG_FILE")"
fi
if grep -q "runner_pause=1" "$RUNNER_LOG_FILE"; then
    pass "Pause flag also survives the \$TERMINAL hand-off"
else
    fail "Runner did not get ASK_AI_PAUSE through \$TERMINAL (log: $(cat "$RUNNER_LOG_FILE"))"
fi
if [ "$(grep -c '^konsole:' "$TERM_LOG_FILE" || true)" -eq 0 ]; then
    pass "No fallback konsole window (no double launch)"
else
    fail "konsole was launched in addition to \$TERMINAL"
fi

# ------------------------------------------------------
print_header "6. CRLF preset config is parsed cleanly"
# ------------------------------------------------------
mkdir -p "$HOME_DIR/.config"
printf 'Preset one\nPreset CRLF\r\n' >"$HOME_DIR/.config/ask-ai-dolphin.cfg"
rc=0
run_entry FAKE_DIALOG_MODE=cancel >/dev/null 2>&1 || rc=$?
if grep -q "argv: Preset one Preset CRLF" "$DIALOG_LOG_FILE"; then
    pass "Both presets passed to the dialog"
else
    fail "Presets wrong: $(head -1 "$DIALOG_LOG_FILE")"
fi
if grep -q $'\r' "$DIALOG_LOG_FILE"; then
    fail "Carriage return leaked from the config into the query"
else
    pass "No carriage return in preset text"
fi
rm -f "$HOME_DIR/.config/ask-ai-dolphin.cfg"

# ------------------------------------------------------
echo ""
if [ "$FAILED" -eq 1 ]; then
    echo "❌ SOME TESTS FAILED"
    exit 1
else
    echo "✅ ALL TESTS PASSED"
    exit 0
fi
