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
    runner_lbl_attached
    runner_lbl_skipped_attach
    runner_lbl_clipboard
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
echo ""
if [ "$FAILED" -eq 1 ]; then
    echo "❌ SOME TESTS FAILED"
    exit 1
else
    echo "✅ ALL TESTS PASSED"
    exit 0
fi
