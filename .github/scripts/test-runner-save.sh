#!/bin/bash
# CI test: verify runner save, attachments, auto-exec, and shared helpers
# Tests:
#   1. Shebang detection logic
#   2. Query slug generation
#   3. Script save + chmod (execution only with AUTO_EXEC)
#   4. Plain output is NOT treated as script
#   5. ASK_AI_SAVE_DIR output file creation
#   6. Locale keys for save/script/auto-exec messages
#   7. Runner fallback strings present
#   8. ASK_AI_AUTO_EXEC decision matrix
#   9. ask-ai-common.sh helpers (text file, size)
#  10. Attachment flag building limits
#  11. Entry point uses terminal fallback + RU presets
#  12. opencode v2: effort as model variant
#  13. Script save: opencode v2 response shapes (e2e)
#  14. opencode v2 resolver (v1 in PATH must be skipped)
#  15. Failure handling: no .md on error, bad limits, "-" paths, pause mode
#  16. ~/.ask_ai reaches the runner when Konsole drops the launcher's env
#  17. ACP harness: default path drives an agent without the opencode CLI
#  18. Agent registry: id → command, install hints, ASK_AI_AGENT_CMD override

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
FAILED=0

print_header() {
    echo ""
    echo "================================================"
    echo "  $1"
    echo "================================================"
}

pass() {
    echo "  ✅ $1"
}

fail() {
    echo "  ❌ FAILED: $1"
    FAILED=1
}

# --------------------------------
print_header "1. Shebang detection"
# --------------------------------

line1="#!/bin/bash"
if [[ "$line1" == "#!"* ]]; then
    pass "Shebang detected: '$line1'"
else
    fail "Should detect shebang: '$line1'"
fi

line2="  #!/bin/bash  "
if [[ "$line2" == "#!"* ]]; then
    fail "Should NOT detect shebang with leading spaces"
else
    pass "No false positive for leading spaces"
fi

line3="# Not a shebang"
if [[ "$line3" == "#!"* ]]; then
    fail "Should NOT detect plain comment as shebang"
else
    pass "No false positive for plain comment"
fi

line4="#!/usr/bin/python3"
if [[ "$line4" == "#!"* ]]; then
    pass "Shebang detected: '$line4'"
else
    fail "Should detect python shebang"
fi

# --------------------------------
print_header "2. Query slug generation"
# --------------------------------

slug_test() {
    local input="$1"
    local expected="$2"
    local label="$3"
    local result
    result=$(echo "$input" | python3 -c "
import sys, re
s = sys.stdin.read().strip().lower()
s = re.sub(r'[^a-zа-я0-9 ]', '', s).strip().replace(' ', '_')[:40]
print(s or 'result')
" 2>/dev/null) || result=$(echo "$input" | tr ' ' '_' | head -c 40)
    if [ -z "$result" ]; then
        result="result"
    fi
    if [ "$result" = "$expected" ]; then
        pass "$label → '$result'"
    else
        fail "$label: expected '$expected', got '$result'"
    fi
}

slug_test "Resize images to 1920x1080" "resize_images_to_1920x1080" "English query"
slug_test "Перескажи этот текст" "перескажи_этот_текст" "Russian query"
slug_test "Abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz" "abcdefghijklmnopqrstuvwxyzabcdefghijklmn" "Long query truncated to 40 chars"
slug_test "!!! @@@" "result" "Only special chars → fallback 'result'"

# --------------------------------
print_header "3. Script save, chmod +x (no auto-exec by default)"
# --------------------------------

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

TEMP_OUTPUT=$(mktemp)
cat > "$TEMP_OUTPUT" << 'SCRIPT'
#!/bin/bash
echo "Hello from generated script"
SCRIPT

SAVE_DIR="$TEST_DIR/save-test"
mkdir -p "$SAVE_DIR"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
QUERY_SLUG="test_script"
SAVE_FILE="$SAVE_DIR/${QUERY_SLUG}-${TIMESTAMP}.md"
cp "$TEMP_OUTPUT" "$SAVE_FILE"

SCRIPT_FILE="${SAVE_FILE%.md}.sh"
cp "$TEMP_OUTPUT" "$SCRIPT_FILE"
chmod +x "$SCRIPT_FILE"

if [ -f "$SCRIPT_FILE" ] && [ -x "$SCRIPT_FILE" ]; then
    pass "Script file created and executable"
else
    fail "Script file should exist and be executable"
fi

# Default AUTO_EXEC is prompt/never-auto — execution must be opt-in
case "${ASK_AI_AUTO_EXEC:-prompt}" in
    1|yes|true|always) fail "Default should not be auto-exec" ;;
    *) pass "Default ASK_AI_AUTO_EXEC is not auto-run" ;;
esac

OUTPUT=$("$SCRIPT_FILE" 2>&1)
if [ "$OUTPUT" = "Hello from generated script" ]; then
    pass "Script can be executed when chosen: '$OUTPUT'"
else
    fail "Script output mismatch: got '$OUTPUT'"
fi

rm -f "$TEMP_OUTPUT" "$SAVE_FILE" "$SCRIPT_FILE"

# --------------------------------
print_header "4. Plain output (no shebang)"
# --------------------------------

TEMP_OUTPUT=$(mktemp)
cat > "$TEMP_OUTPUT" << 'TEXT'
This is a summary of the text.
It does not start with a shebang.
TEXT

FIRST_LINE=$(head -1 "$TEMP_OUTPUT")
if [[ "$FIRST_LINE" == "#!"* ]]; then
    fail "Should NOT detect shebang in plain text"
else
    pass "No shebang detected for plain text"
fi

rm -f "$TEMP_OUTPUT"

# --------------------------------
print_header "5. ASK_AI_SAVE_DIR output file"
# --------------------------------

TEMP_OUTPUT=$(mktemp)
echo "Test output content" > "$TEMP_OUTPUT"
SAVE_FILE="$SAVE_DIR/save_test-${TIMESTAMP}.md"
cp "$TEMP_OUTPUT" "$SAVE_FILE"
if [ "$(cat "$SAVE_FILE")" = "Test output content" ]; then
    pass "SAVE_FILE created with correct content"
else
    fail "SAVE_FILE content mismatch"
fi
rm -f "$TEMP_OUTPUT" "$SAVE_FILE"

# --------------------------------
print_header "6. Locale keys"
# --------------------------------

LOCALE_DIR="$PROJECT_DIR/locales"
REQUIRED_KEYS=(
    runner_lbl_saved
    runner_lbl_executing
    runner_lbl_script_saved
    runner_lbl_script_failed
    runner_lbl_run_confirm
    runner_lbl_script_skipped
    runner_lbl_opencode_failed
    runner_lbl_err_opencode_v2
    runner_lbl_attached
    runner_lbl_skipped_attach
    runner_lbl_clipboard
    runner_lbl_effort_skipped
    runner_lbl_effort_unknown
    runner_lbl_effort_pinned
    install_opencode_url
    dialog_history_label
    dialog_model_label
    sh_err_no_terminal
    install_ask_ai_exists
    install_fish_note
)

for locale_file in "$LOCALE_DIR"/en_EN "$LOCALE_DIR"/ru_RU; do
    locale_name=$(basename "$locale_file")
    for key in "${REQUIRED_KEYS[@]}"; do
        if grep -q "^${key}=" "$locale_file"; then
            pass "[$locale_name] Key '$key' found"
        else
            fail "[$locale_name] Missing key '$key'"
        fi
    done
done

# The opencode install hint must point at the v2 installer (not the v1 /install,
# which redirects, nor v1 package names opencode-ai / tap/opencode).
for locale_file in "$LOCALE_DIR"/en_EN "$LOCALE_DIR"/ru_RU; do
    locale_name=$(basename "$locale_file")
    hint=$(grep '^install_opencode_url=' "$locale_file")
    case "$hint" in
        *opencode.ai/v2/install*) pass "[$locale_name] install hint uses /v2/install" ;;
        *) fail "[$locale_name] install hint must use https://opencode.ai/v2/install" ;;
    esac
    case "$hint" in
        *opencode-ai*|*tap/opencode[^-]*) fail "[$locale_name] install hint mentions a v1 package" ;;
        *) pass "[$locale_name] install hint has no v1 package refs" ;;
    esac
done

# --------------------------------
print_header "7. Runner contains new symbols"
# --------------------------------

RUNNER_FILE="$PROJECT_DIR/src/ask-ai-dolphin-run.sh"
for needle in ASK_AI_AUTO_EXEC pipefail ATTACH_FLAGS runner_lbl_run_confirm; do
    if grep -qF "$needle" "$RUNNER_FILE"; then
        pass "Runner references $needle"
    else
        fail "Runner missing $needle"
    fi
done

if grep -qF 'INSTALL_DIR' "$RUNNER_FILE" && ! grep -qE 'SCRIPT_DIR=\$\{FILES' "$RUNNER_FILE"; then
    pass "Runner uses INSTALL_DIR (no SCRIPT_DIR overwrite for save path)"
else
    # Still OK if SCRIPT_OUT_DIR is used
    if grep -qF 'SCRIPT_OUT_DIR' "$RUNNER_FILE"; then
        pass "Runner uses SCRIPT_OUT_DIR for script save path"
    else
        fail "Runner should not reuse SCRIPT_DIR for script output"
    fi
fi

# --------------------------------
print_header "8. ASK_AI_AUTO_EXEC decision matrix"
# --------------------------------

decide_exec() {
    local mode="$1"
    local mode_lower
    mode_lower="${mode,,}"
    case "${mode_lower:-prompt}" in
        1|yes|true|always) echo yes ;;
        0|no|false|never) echo no ;;
        *) echo prompt ;;
    esac
}

[ "$(decide_exec 1)" = "yes" ] && pass "AUTO_EXEC=1 → run" || fail "AUTO_EXEC=1"
[ "$(decide_exec always)" = "yes" ] && pass "AUTO_EXEC=always → run" || fail "AUTO_EXEC=always"
[ "$(decide_exec 0)" = "no" ] && pass "AUTO_EXEC=0 → skip" || fail "AUTO_EXEC=0"
[ "$(decide_exec never)" = "no" ] && pass "AUTO_EXEC=never → skip" || fail "AUTO_EXEC=never"
[ "$(decide_exec prompt)" = "prompt" ] && pass "AUTO_EXEC=prompt → ask" || fail "AUTO_EXEC=prompt"
[ "$(decide_exec "")" = "prompt" ] && pass "AUTO_EXEC unset → ask" || fail "AUTO_EXEC unset"

# --------------------------------
print_header "9. common.sh helpers"
# --------------------------------

COMMON="$PROJECT_DIR/src/ask-ai-common.sh"
if [ -f "$COMMON" ]; then
    # shellcheck disable=SC1090
    source "$COMMON"
    pass "Sourced ask-ai-common.sh"

    loc=$(ask_ai_detect_locale)
    [ -n "$loc" ] && pass "ask_ai_detect_locale → $loc" || fail "detect_locale empty"

    TEXT_F="$TEST_DIR/sample.txt"
    BIN_F="$TEST_DIR/sample.bin"
    echo "hello world" > "$TEXT_F"
    printf 'hello\0world' > "$BIN_F"

    if ask_ai_is_text_file "$TEXT_F"; then
        pass "text file detected as text"
    else
        fail "text file should be text"
    fi

    # Binary with NUL — file(1) may say application/octet-stream
    if ask_ai_is_text_file "$BIN_F"; then
        fail "binary with NUL should not be text"
    else
        pass "binary with NUL rejected"
    fi

    sz=$(ask_ai_file_size "$TEXT_F")
    if [ "$sz" -gt 0 ]; then
        pass "ask_ai_file_size → $sz"
    else
        fail "ask_ai_file_size failed"
    fi
else
    fail "ask-ai-common.sh missing"
fi

# --------------------------------
print_header "10. Attachment limits logic"
# --------------------------------

MAX_ATTACH_BYTES=100
MAX_ATTACH_FILES=2
ATTACH_COUNT=0
ATTACHED=0
SKIPPED=0

for f in "$TEST_DIR/a.txt" "$TEST_DIR/b.txt" "$TEST_DIR/c.txt"; do
    echo "x" > "$f"
done
# large file
dd if=/dev/zero of="$TEST_DIR/big.txt" bs=200 count=1 2>/dev/null || head -c 200 /dev/zero > "$TEST_DIR/big.txt"

for f in "$TEST_DIR/a.txt" "$TEST_DIR/b.txt" "$TEST_DIR/c.txt" "$TEST_DIR/big.txt"; do
    size_b=$(ask_ai_file_size "$f")
    if ask_ai_is_text_file "$f" && [ "$size_b" -le "$MAX_ATTACH_BYTES" ] && [ "$ATTACH_COUNT" -lt "$MAX_ATTACH_FILES" ]; then
        ATTACH_COUNT=$((ATTACH_COUNT + 1))
        ATTACHED=$((ATTACHED + 1))
    else
        SKIPPED=$((SKIPPED + 1))
    fi
done

if [ "$ATTACHED" -eq 2 ] && [ "$SKIPPED" -eq 2 ]; then
    pass "Attachment limits: 2 attached, 2 skipped"
else
    fail "Attachment limits: attached=$ATTACHED skipped=$SKIPPED (expected 2/2)"
fi

# --------------------------------
print_header "11. Entry point uses terminal fallback + RU presets"
# --------------------------------

ENTRY="$PROJECT_DIR/src/ask-ai-dolphin.sh"
for needle in launch_in_terminal "Опиши эти файлы" INSTALL_DIR; do
    if grep -qF "$needle" "$ENTRY"; then
        pass "Entry has $needle"
    else
        fail "Entry missing $needle"
    fi
done

# --------------------------------
print_header "12. opencode v2: effort as model variant"
# --------------------------------

# v2 removed --variant; effort must reach opencode as provider/model#variant.
# Explanatory comments may mention the flag — only executable lines count.
if grep -vE '^[[:space:]]*#' "$RUNNER_FILE" | grep -qE -- '--variant'; then
    fail "Runner must not pass the removed --variant flag"
else
    pass "Runner no longer passes --variant"
fi

for needle in ask_ai_apply_effort 'LBL_EFFORT_SKIPPED' 'LBL_EFFORT_UNKNOWN' 'LBL_EFFORT_PINNED'; do
    if grep -qF "$needle" "$RUNNER_FILE" "$COMMON"; then
        pass "References $needle"
    else
        fail "Missing $needle"
    fi
done

# Theme vars are optional — runner must not crash under `set -u` when unset.
# (Regression: `${ASK_AI_THEME,,}` aborted the runner before any output.)
# Flag an expansion whose name is followed by anything other than a default/:-.
if grep -vE '^[[:space:]]*#' "$RUNNER_FILE" \
        | grep -qE '\$\{(ASK_AI_THEME|COLORFGBG)[^-:]'; then
    fail "ASK_AI_THEME/COLORFGBG must be expanded with a default"
else
    pass "Theme vars expanded with defaults"
fi

# ask_ai_apply_effort return-code contract
# shellcheck disable=SC1090
source "$COMMON"
effort_rc() { local rc=0; ask_ai_apply_effort "$1" "$2" >/dev/null 2>&1 || rc=$?; echo "$rc"; }

# pinned model is rejected before any opencode call → deterministic rc=3
[ "$(effort_rc "opencode/deepseek-v4-flash#max" "high")" = "3" ] \
    && pass "pinned model → rc 3" || fail "pinned model should return 3"
# empty effort → rc 2
[ "$(effort_rc "opencode/deepseek-v4-flash" "")" = "2" ] \
    && pass "empty effort → rc 2" || fail "empty effort should return 2"

if command -v opencode &>/dev/null; then
    # Without opencode installed this is rc=2 (cannot verify) — accepted.
    rc_out=$(effort_rc "opencode/deepseek-v4-flash" "high")
    case "$rc_out" in
        0) pass "supported variant → rc 0" ;;
        1) pass "variant check → rc 1 (model unknown to this opencode)" ;;
        2) pass "variant check → rc 2 (catalog unavailable)" ;;
        *) fail "unexpected rc $rc_out" ;;
    esac
    if [ "$rc_out" = "0" ]; then
        out=$(ask_ai_apply_effort "opencode/deepseek-v4-flash" "high")
        [ "$out" = "opencode/deepseek-v4-flash#high" ] \
            && pass "output is model#variant" || fail "got '$out'"
    fi
else
    [ "$(effort_rc "opencode/deepseek-v4-flash" "high")" = "2" ] \
        && pass "no opencode → rc 2" || fail "should return 2 without opencode"
fi

# opencode v2: --agent must always be passed explicitly. When the agent is
# inherited from the opencode config (default_agent), v2 appends a spurious
# second assistant turn to `opencode run` output — it pollutes the terminal and
# every saved .md. Default agent is plan (read-only); ASK_AI_MODE overrides it.
if grep -vE '^[[:space:]]*#' "$RUNNER_FILE" | grep -qF -- '--agent "$MODE"'; then
    pass "Runner always passes an explicit --agent"
else
    fail "Runner must pass --agent explicitly (opencode v2 duplicate turn)"
fi

if grep -qF 'MODE="${ASK_AI_MODE:-plan}"' "$RUNNER_FILE"; then
    pass "Default agent is plan (ASK_AI_MODE overridable)"
else
    fail "MODE must default to plan"
fi

# --------------------------------
print_header "13. Script save: opencode v2 response shapes (e2e)"
# --------------------------------
# Runs the real runner with a shimmed `opencode` (no network, deterministic)
# against canned response shapes. Covers the v2 plan-style answer: prose
# before the fenced script and commentary after it — detection must find the
# shebang block anywhere, not only when it opens the response.

SHIM_DIR="$TEST_DIR/opencode-shim"
FAKE_SAVE_DIR="$TEST_DIR/fake-save"
# Isolated HOME: the runner reads ~/.ask_ai, and a developer's real file must
# not change the outcome of these tests.
FAKE_HOME="$TEST_DIR/fake-home"
mkdir -p "$SHIM_DIR" "$FAKE_SAVE_DIR" "$FAKE_HOME"

cat > "$SHIM_DIR/opencode" <<'SHIM'
#!/bin/bash
# Shim: report a v2 version (so the resolver picks it) and print the canned
# response for `run`; ignore everything else.
if [ "${1:-}" = "--version" ]; then
    echo "v2.0.27"
    exit 0
fi
if [ -n "${FAKE_ARGS:-}" ]; then
    printf '%s\n' "$@" >>"$FAKE_ARGS"
fi
if [ -n "${FAKE_RESPONSE:-}" ]; then
    cat "$FAKE_RESPONSE"
fi
exit "${FAKE_EXIT:-0}"
SHIM
chmod +x "$SHIM_DIR/opencode"

printf 'print("hi")\n' > "$TEST_DIR/attach-sample.py"

run_fake_runner() {  # $1 = canned response file, $2 = label, [$3 = file to attach]
    local file="${3:-$TEST_DIR/attach-sample.py}"
    rm -f "$FAKE_SAVE_DIR"/*
    # ASK_AI_HARNESS=cli keeps these cases on the legacy `opencode run` path;
    # the ACP path has its own section at the end.
    FAKE_RESPONSE="$1" PATH="$SHIM_DIR:$PATH" ASK_AI_LOCALE=en_EN HOME="$FAKE_HOME" \
        ASK_AI_HARNESS=cli \
        GLOW_DISABLED=1 ASK_AI_AUTO_EXEC=0 ASK_AI_SAVE_DIR="$FAKE_SAVE_DIR" \
        bash "$RUNNER_FILE" "test query" "$file" \
        </dev/null >"$TEST_DIR/fake-run-$2.log" 2>&1
}

count_sh() {
    find "$FAKE_SAVE_DIR" -maxdepth 1 -type f -name '*.sh' | wc -l
}

# --- 13a. Prose first, fenced shebang block in the middle, trailing prose
cat > "$TEST_DIR/resp-prose-first.txt" <<'EOF'
**Объяснение одной строкой:** скрипт печатает дату.

```bash
#!/bin/bash
echo hello-from-v2
```

Готово — сохраните как show-date.sh и сделайте chmod +x.
EOF

run_fake_runner "$TEST_DIR/resp-prose-first.txt" prose
if [ "$(count_sh)" = "1" ]; then
    pass "Prose-first v2 response → script detected"
    sh_file=$(find "$FAKE_SAVE_DIR" -maxdepth 1 -type f -name '*.sh')
    [ "$(head -n1 "$sh_file")" = "#!/bin/bash" ] \
        && pass "Extracted block starts with shebang" \
        || fail "Extracted block must start with shebang"
    grep -qF 'echo hello-from-v2' "$sh_file" \
        && pass "Script body extracted" || fail "Script body missing"
    if grep -qF 'Объяснение' "$sh_file" || grep -qF 'Готово' "$sh_file"; then
        fail "Prose must not leak into the .sh"
    else
        pass "No prose leaked into the .sh"
    fi
    [ -x "$sh_file" ] && pass "Script is chmod +x" || fail "Script not executable"
    out=$("$sh_file" 2>&1) || out="EXIT:$?"
    [ "$out" = "hello-from-v2" ] \
        && pass "Extracted script runs: '$out'" || fail "Script output: '$out'"
    glob_md=("$FAKE_SAVE_DIR"/*.md)
    [ -f "${glob_md[0]}" ] && grep -qF 'Объяснение' "${glob_md[0]}" \
        && pass ".md keeps the full response" || fail ".md missing or truncated"
else
    fail "Prose-first v2 response should produce exactly 1 .sh, got $(count_sh)"
fi

# --- 13b. Raw shebang on the first line → whole response is the script
cat > "$TEST_DIR/resp-raw.txt" <<'EOF'
#!/bin/bash
echo raw-v2
EOF

run_fake_runner "$TEST_DIR/resp-raw.txt" raw
if [ "$(count_sh)" = "1" ]; then
    sh_file=$(find "$FAKE_SAVE_DIR" -maxdepth 1 -type f -name '*.sh')
    if diff -q "$sh_file" "$TEST_DIR/resp-raw.txt" >/dev/null; then
        pass "Raw first-line shebang → whole response saved as .sh"
    else
        fail "Raw shebang response should be saved verbatim"
    fi
else
    fail "Raw shebang should produce 1 .sh, got $(count_sh)"
fi

# --- 13c. Fence without a shebang → not a script
cat > "$TEST_DIR/resp-no-shebang.txt" <<'EOF'
**Идея:**

```bash
echo no-shebang
```
EOF

run_fake_runner "$TEST_DIR/resp-no-shebang.txt" noshebang
if [ "$(count_sh)" = "0" ]; then
    pass "Fenced block without shebang → no .sh"
else
    fail "Fence without shebang must not create a .sh"
fi

# --- 13d. Plain prose → not a script
cat > "$TEST_DIR/resp-plain.txt" <<'EOF'
Просто ответ без кода: файл печатает hi.
EOF

run_fake_runner "$TEST_DIR/resp-plain.txt" plain
if [ "$(count_sh)" = "0" ]; then
    pass "Plain prose → no .sh"
else
    fail "Plain prose must not create a .sh"
fi

# --------------------------------
print_header "14. opencode v2 resolver (v1 in PATH must be skipped)"
# --------------------------------
# The Dolphin→konsole session PATH does not source ~/.zshrc, so `opencode` can
# resolve to a system v1 build (e.g. /usr/sbin/opencode 1.x): v1's `run -f`
# is an array that swallows the prompt and dies with "File not found: <prompt>".
# ask_ai_opencode_bin must pick the first binary with a major version >= 2.

R14="$TEST_DIR/resolver"
mkdir -p "$R14/v1bin" "$R14/v2bin" "$R14/home/.opencode/bin" "$R14/emptyhome"

cat > "$R14/v1bin/opencode" <<'EOF'
#!/bin/bash
if [ "${1:-}" = "--version" ]; then echo "1.19.0"; exit 0; fi
exit 0
EOF
cat > "$R14/v2bin/opencode" <<'EOF'
#!/bin/bash
if [ "${1:-}" = "--version" ]; then echo "v2.0.27"; exit 0; fi
exit 0
EOF
chmod +x "$R14/v1bin/opencode" "$R14/v2bin/opencode"
cp "$R14/v2bin/opencode" "$R14/home/.opencode/bin/opencode"

# shellcheck disable=SC1090
source "$COMMON"

# A: v1 sits earlier in PATH than v2 → v2 must still win
got=$(export HOME="$R14/emptyhome" PATH="$R14/v1bin:$R14/v2bin:/usr/bin:/bin"; ask_ai_opencode_bin 2>/dev/null)
if [ "$got" = "$R14/v2bin/opencode" ]; then
    pass "v2 wins over an earlier v1 in PATH"
else
    fail "expected $R14/v2bin/opencode, got '${got:-nothing}'"
fi

# B: only v1 in PATH, v2 in ~/.opencode/bin → HOME candidate wins
got=$(export HOME="$R14/home" PATH="$R14/v1bin:/usr/bin:/bin"; ask_ai_opencode_bin 2>/dev/null)
if [ "$got" = "$R14/home/.opencode/bin/opencode" ]; then
    pass "~/.opencode/bin v2 used when PATH has only v1"
else
    fail "expected $R14/home/.opencode/bin/opencode, got '${got:-nothing}'"
fi

# C: only v1 anywhere → resolver must fail (runner then prints a clear error)
if got=$(export HOME="$R14/emptyhome" PATH="$R14/v1bin:/usr/bin:/bin"; ask_ai_opencode_bin 2>/dev/null); then
    fail "v1-only environment should not resolve, got '$got'"
else
    pass "v1-only environment → not resolved"
fi

# D: no opencode at all → not resolved
if got=$(export HOME="$R14/emptyhome" PATH="/usr/bin:/bin"; ask_ai_opencode_bin 2>/dev/null); then
    fail "missing opencode should not resolve, got '$got'"
else
    pass "no opencode → not resolved"
fi

# Runner must report the dedicated v2 error (not the generic one) when only
# v1 is available — checked statically; the live path is covered by 14a–d.
if grep -qF 'LBL_ERR_OPENCODE_V2' "$RUNNER_FILE"; then
    pass "Runner has a dedicated 'v2 required' error message"
else
    fail "Runner missing LBL_ERR_OPENCODE_V2 handling"
fi

# --------------------------------
print_header "15. Failure handling and terminal-mode differences"
# --------------------------------

# --- 15a. opencode fails → a partial answer must not be saved as a normal .md
printf 'partial answer\n' > "$TEST_DIR/resp-partial.txt"
FAKE_EXIT=1 run_fake_runner "$TEST_DIR/resp-partial.txt" fail
if [ -z "$(find "$FAKE_SAVE_DIR" -maxdepth 1 -type f -name '*.md')" ]; then
    pass "Failed run leaves no .md behind"
else
    fail "Failed run saved a .md"
fi
if grep -qF 'opencode exited with an error' "$TEST_DIR/fake-run-fail.log"; then
    pass "Failed run reports the opencode error"
else
    fail "Missing opencode failure message"
fi

# --- 15b. Non-numeric attachment limits must not disable attachments
printf 'ok\n' > "$TEST_DIR/resp-ok.txt"
ASK_AI_MAX_ATTACH_BYTES=abc ASK_AI_MAX_ATTACH_FILES=xyz \
    run_fake_runner "$TEST_DIR/resp-ok.txt" badlimits
if grep -qF 'Attached files:' "$TEST_DIR/fake-run-badlimits.log"; then
    pass "Bad ASK_AI_MAX_ATTACH_* falls back to defaults (file still attached)"
else
    fail "Bad limits silently dropped the attachment"
fi
if grep -q 'integer expression expected' "$TEST_DIR/fake-run-badlimits.log"; then
    fail "Bad limits leak shell errors to the user"
else
    pass "Bad limits produce no shell errors"
fi

# --- 15c. A path starting with "-" must not reach opencode as a flag
DASH_DIR="$TEST_DIR/dash-dir"
mkdir -p "$DASH_DIR"
printf 'hello\n' > "$DASH_DIR/-dash.txt"
ARG_LOG="$TEST_DIR/args-dash.log"
: >"$ARG_LOG"
( cd "$DASH_DIR" && FAKE_ARGS="$ARG_LOG" run_fake_runner "$TEST_DIR/resp-ok.txt" dash "-dash.txt" )
attach_arg=$(awk '$0 == "-f" { getline; print; exit }' "$ARG_LOG")
if [ "$attach_arg" = "-dash.txt" ]; then
    fail "Leading-dash path passed to opencode verbatim (flag injection)"
else
    pass "Leading-dash path is not passed verbatim"
fi
if [ "$attach_arg" = "$DASH_DIR/-dash.txt" ]; then
    pass "Leading-dash path rewritten to an absolute path"
else
    fail "Expected $DASH_DIR/-dash.txt after -f, got '${attach_arg:-nothing}'"
fi

# --- 15d. "Press Enter to close" only in a terminal window (ASK_AI_PAUSE)
run_fake_runner "$TEST_DIR/resp-ok.txt" inline
if grep -qF '✅ Done.' "$TEST_DIR/fake-run-inline.log" \
    && ! grep -qF 'Press Ctrl+C' "$TEST_DIR/fake-run-inline.log"; then
    pass "Inline run (ask/askr) returns without asking for Enter"
else
    fail "Inline run still prints the window-close hint"
fi
ASK_AI_PAUSE=1 run_fake_runner "$TEST_DIR/resp-ok.txt" pause
if grep -qF 'Press Ctrl+C or Enter to close' "$TEST_DIR/fake-run-pause.log"; then
    pass "Terminal window (ASK_AI_PAUSE=1) keeps the close hint"
else
    fail "Terminal window lost the close hint"
fi

# --------------------------------
print_header "16. ~/.ask_ai reaches the runner alone (Konsole env drop)"
# --------------------------------
# Konsole hands `-e cmd` to an already running instance, so the session that
# runs the query inherits that instance's environment, not the one the entry
# script set up. Every case below therefore runs with `env -i`: only the file
# itself can provide the settings the docs promise for the right-click menu.
FILE_SAVE_DIR="$TEST_DIR/file-save-dir"
DOT_ASK_AI="$FAKE_HOME/.ask_ai"
cat > "$DOT_ASK_AI" <<EOF
# Konsole drops the launcher environment: the runner reads this file itself.
export ASK_AI_MODEL="opencode/model-from-file"
export ASK_AI_SAVE_DIR="$FILE_SAVE_DIR"
EOF

# ASK_AI_HARNESS is not inherited by `env -i`, so the CLI default applies;
# keep these cases on the CLI path explicitly.
CLEAN_ENV=(env -i HOME="$FAKE_HOME" PATH="$SHIM_DIR:/usr/bin:/bin"
    ASK_AI_HARNESS=cli FAKE_RESPONSE="$TEST_DIR/resp-ok.txt" GLOW_DISABLED=1
    ASK_AI_LOCALE=en_EN ASK_AI_AUTO_EXEC=0)

# --- 16a. Model from ~/.ask_ai is used with no ASK_AI_MODEL in the env
CLEAN_ARGS="$TEST_DIR/args-clean-env.log"
: > "$CLEAN_ARGS"
"${CLEAN_ENV[@]}" FAKE_ARGS="$CLEAN_ARGS" \
    bash "$RUNNER_FILE" "clean env query" "$TEST_DIR/attach-sample.py" \
    </dev/null >"$TEST_DIR/fake-run-cleanenv.log" 2>&1
if grep -qxF 'opencode/model-from-file' "$CLEAN_ARGS"; then
    pass "ASK_AI_MODEL from ~/.ask_ai applies when the session env is dropped"
else
    fail "Model from ~/.ask_ai was not used (args: $(tr '\n' ' ' < "$CLEAN_ARGS"))"
fi

# --- 16b. Save dir from ~/.ask_ai is honoured too
if find "$FILE_SAVE_DIR" -maxdepth 1 -type f -name '*.md' | grep -q .; then
    pass "ASK_AI_SAVE_DIR from ~/.ask_ai saves the response"
else
    fail "ASK_AI_SAVE_DIR from ~/.ask_ai was ignored"
fi

# --- 16c. An explicit environment value still wins over the file
: > "$CLEAN_ARGS"
"${CLEAN_ENV[@]}" FAKE_ARGS="$CLEAN_ARGS" ASK_AI_MODEL="opencode/model-from-env" \
    bash "$RUNNER_FILE" "explicit model" "$TEST_DIR/attach-sample.py" \
    </dev/null >"$TEST_DIR/fake-run-explicit-model.log" 2>&1
if grep -qxF 'opencode/model-from-env' "$CLEAN_ARGS" \
    && ! grep -qxF 'opencode/model-from-file' "$CLEAN_ARGS"; then
    pass "Explicit ASK_AI_MODEL overrides ~/.ask_ai"
else
    fail "Explicit ASK_AI_MODEL was overridden by ~/.ask_ai"
fi

# --- 16d. A broken ~/.ask_ai must not abort the query
cat > "$DOT_ASK_AI" <<'EOF'
if then
EOF
"${CLEAN_ENV[@]}" \
    bash "$RUNNER_FILE" "broken config" "$TEST_DIR/attach-sample.py" \
    </dev/null >"$TEST_DIR/fake-run-badcfg.log" 2>&1
if grep -qF '✅ Done.' "$TEST_DIR/fake-run-badcfg.log" \
    && grep -qF 'ok' "$TEST_DIR/fake-run-badcfg.log" \
    && ! grep -qiF 'syntax error' "$TEST_DIR/fake-run-badcfg.log"; then
    pass "Broken ~/.ask_ai is ignored without breaking the query"
else
    fail "Broken ~/.ask_ai broke the runner: $(tail -3 "$TEST_DIR/fake-run-badcfg.log" | tr '\n' ' ')"
fi

# --------------------------------
print_header "17. ACP harness is the default"
# --------------------------------
# The runner must be able to drive any ACP agent: no opencode in PATH (the ACP
# path never checks for it), a fake agent that speaks the protocol, and the
# usual save/script pipeline on top of its Markdown output.
ACP_LOG="$TEST_DIR/acp-agent.log"
: >"$ACP_LOG"
rm -f "$FAKE_SAVE_DIR"/*
# -u ASK_AI_MODEL: a developer's own export must not hide the default handling.
# ASK_AI_ACP / ASK_AI_HARNESS are deliberately unset: the ACP path must be the
# one taken when nothing asks for a specific harness.
env -u ASK_AI_MODEL -u ASK_AI_ACP -u ASK_AI_HARNESS \
    ASK_AI_AGENT_CMD="python3 $SCRIPT_DIR/fake-acp-agent.py" \
    FAKE_ACP_LOG="$ACP_LOG" \
    PATH="/usr/bin:/bin" HOME="$FAKE_HOME" GLOW_DISABLED=1 ASK_AI_LOCALE=en_EN \
    ASK_AI_AUTO_EXEC=0 ASK_AI_SAVE_DIR="$FAKE_SAVE_DIR" \
    bash "$RUNNER_FILE" "acp query" "$TEST_DIR/attach-sample.py" \
    </dev/null >"$TEST_DIR/fake-run-acp.log" 2>&1

if grep -qF 'Harness:' "$TEST_DIR/fake-run-acp.log"; then
    pass "Runner announces the ACP harness"
else
    fail "Runner did not switch to ACP: $(tail -3 "$TEST_DIR/fake-run-acp.log" | tr '\n' ' ')"
fi
if grep -qF 'agent default' "$TEST_DIR/fake-run-acp.log"; then
    pass "ACP mode does not inject the opencode CLI model default"
else
    fail "ACP mode printed a CLI model as the selected one"
fi
if grep -qF 'Hello from ACP' "$TEST_DIR/fake-run-acp.log"; then
    pass "Answer streamed through the runner pipeline"
else
    fail "No ACP answer in the runner output"
fi
if grep -qF 'resource_link' "$ACP_LOG"; then
    pass "Selected file attached as an ACP resource_link"
else
    fail "Attachment missing from the ACP prompt"
fi
acp_md=$(find "$FAKE_SAVE_DIR" -maxdepth 1 -type f -name '*.md' | head -1)
if [ -n "$acp_md" ] && grep -qF 'Hello from ACP' "$acp_md"; then
    pass ".md saved from the ACP answer"
else
    fail "ACP answer was not saved as .md"
fi
if grep -qF 'opencode v2 not found' "$TEST_DIR/fake-run-acp.log"; then
    fail "ACP mode still required the opencode CLI"
else
    pass "ACP mode works without the opencode CLI"
fi

# --- Escape hatch: ASK_AI_HARNESS=cli and the old ASK_AI_ACP=0 keep the CLI
run_cli_harness() {
    local label="$1"
    shift
    rm -f "$FAKE_SAVE_DIR"/*
    env -u ASK_AI_MODEL "$@" FAKE_RESPONSE="$TEST_DIR/resp-ok.txt" \
        PATH="$SHIM_DIR:/usr/bin:/bin" HOME="$FAKE_HOME" GLOW_DISABLED=1 \
        ASK_AI_LOCALE=en_EN ASK_AI_AUTO_EXEC=0 ASK_AI_SAVE_DIR="$FAKE_SAVE_DIR" \
        bash "$RUNNER_FILE" "cli query" "$TEST_DIR/attach-sample.py" \
        </dev/null >"$TEST_DIR/fake-run-$label.log" 2>&1
}
run_cli_harness harness-cli -u ASK_AI_ACP ASK_AI_HARNESS=cli
if grep -qF 'Harness:' "$TEST_DIR/fake-run-harness-cli.log"; then
    fail "ASK_AI_HARNESS=cli still used ACP"
else
    pass "ASK_AI_HARNESS=cli keeps the opencode CLI path"
fi
if grep -qF 'opencode/mimo-v2.6-flash-free' "$TEST_DIR/fake-run-harness-cli.log"; then
    pass "CLI path keeps the documented default model"
else
    fail "CLI path lost its default model"
fi

run_cli_harness acp-alias -u ASK_AI_HARNESS ASK_AI_ACP=0
if grep -qF 'Harness:' "$TEST_DIR/fake-run-acp-alias.log"; then
    fail "ASK_AI_ACP=0 still used ACP"
else
    pass "ASK_AI_ACP=0 (pre-1.4 alias) still selects the CLI path"
fi

# --------------------------------
print_header "18. Agent registry and missing-agent handling"
# --------------------------------
rm -f "$FAKE_SAVE_DIR"/*
rc=0
env -u ASK_AI_AGENT_CMD ASK_AI_AGENT=gemini PATH="/usr/bin:/bin" HOME="$FAKE_HOME" \
    ASK_AI_LOCALE=en_EN GLOW_DISABLED=1 ASK_AI_AUTO_EXEC=0 ASK_AI_SAVE_DIR="$FAKE_SAVE_DIR" \
    bash "$RUNNER_FILE" "gemini query" "$TEST_DIR/attach-sample.py" \
    </dev/null >"$TEST_DIR/fake-run-gemini-missing.log" 2>&1 || rc=$?
if [ "$rc" -eq 1 ] && grep -qF "Agent 'gemini' not found" "$TEST_DIR/fake-run-gemini-missing.log"; then
    pass "ASK_AI_AGENT with a missing binary fails with a clear message"
else
    fail "Missing agent handling wrong (rc=$rc): $(tail -2 "$TEST_DIR/fake-run-gemini-missing.log" | tr '\n' ' ')"
fi
if grep -qF 'npm install -g @google/gemini-cli' "$TEST_DIR/fake-run-gemini-missing.log"; then
    pass "Missing agent message carries the install hint"
else
    fail "Install hint missing from the error"
fi

rc=0
env -u ASK_AI_AGENT_CMD ASK_AI_AGENT=definitely-not-an-agent PATH="/usr/bin:/bin" \
    HOME="$FAKE_HOME" ASK_AI_LOCALE=en_EN GLOW_DISABLED=1 \
    bash "$RUNNER_FILE" "bogus query" "$TEST_DIR/attach-sample.py" \
    </dev/null >"$TEST_DIR/fake-run-bogus-agent.log" 2>&1 || rc=$?
if grep -qF "Unknown ASK_AI_AGENT 'definitely-not-an-agent'" "$TEST_DIR/fake-run-bogus-agent.log"; then
    pass "Unknown agent id warns and falls back"
else
    fail "Unknown agent produced no warning (rc=$rc)"
fi

rm -f "$FAKE_SAVE_DIR"/*
ASK_AI_AGENT=gemini \
    ASK_AI_AGENT_CMD="python3 $SCRIPT_DIR/fake-acp-agent.py" \
    FAKE_ACP_LOG="$TEST_DIR/acp-agent.log" \
    PATH="/usr/bin:/bin" HOME="$FAKE_HOME" GLOW_DISABLED=1 ASK_AI_LOCALE=en_EN \
    ASK_AI_AUTO_EXEC=0 ASK_AI_SAVE_DIR="$FAKE_SAVE_DIR" \
    bash "$RUNNER_FILE" "override query" "$TEST_DIR/attach-sample.py" \
    </dev/null >"$TEST_DIR/fake-run-agent-override.log" 2>&1
if grep -qF 'Hello from ACP' "$TEST_DIR/fake-run-agent-override.log" \
    && grep -qF '(gemini)' "$TEST_DIR/fake-run-agent-override.log"; then
    pass "ASK_AI_AGENT_CMD overrides the registry entry"
else
    fail "Registry override not honoured: $(tail -3 "$TEST_DIR/fake-run-agent-override.log" | tr '\n' ' ')"
fi

# --------------------------------
echo ""
if [ "$FAILED" -eq 1 ]; then
    echo "❌ SOME TESTS FAILED"
    exit 1
else
    echo "✅ ALL TESTS PASSED"
    exit 0
fi
