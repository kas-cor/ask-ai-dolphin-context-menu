#!/bin/bash
# CI test: unit tests for ask-ai-common.sh helpers
# Tests:
#   1. ask_ai_detect_locale() — locale detection / case insensitivity
#   2. ask_ai_load_locale() — locale file loading
#   3. ask_ai_is_text_file() — text/binary detection, MIME types, edge cases
#   4. ask_ai_file_size() — file size with GNU and BSD stat
#   5. ask_ai_dir_listing() — directory listing, max limit, hidden files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
FAILED=0

print_header() {
    echo ""
    echo "========================================================"
    echo "  $1"
    echo "========================================================"
}

pass() {
    echo "  ✅ $1"
}

fail() {
    echo "  ❌ FAILED: $1"
    FAILED=1
}

# Source the module under test
COMMON="$PROJECT_DIR/src/ask-ai-common.sh"
if [ ! -f "$COMMON" ]; then
    echo "❌ $COMMON not found"
    exit 1
fi
# shellcheck disable=SC1090
source "$COMMON"

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# ======================================================
print_header "1. ask_ai_detect_locale"
# ======================================================

# 1a. Default (no env set, LANG not matched)
_old_lang="${LANG:-}"
_old_ask_locale="${ASK_AI_LOCALE:-}"
unset ASK_AI_LOCALE
export LANG="en_US.UTF-8"
loc=$(ask_ai_detect_locale)
if [ "$loc" = "en_EN" ]; then
    pass "Default locale (LANG=en_US.UTF-8) → en_EN"
else
    fail "Expected en_EN, got '$loc'"
fi

# 1b. Russian from LANG
export LANG="ru_RU.UTF-8"
loc=$(ask_ai_detect_locale)
if [ "$loc" = "ru_RU" ]; then
    pass "LANG=ru_RU.UTF-8 → ru_RU"
else
    fail "Expected ru_RU, got '$loc'"
fi

# 1c. Russian from ru_UA
export LANG="ru_UA.UTF-8"
loc=$(ask_ai_detect_locale)
if [ "$loc" = "ru_RU" ]; then
    pass "LANG=ru_UA.UTF-8 → ru_RU"
else
    fail "Expected ru_RU, got '$loc'"
fi

# 1d. Russian from be_BY
export LANG="be_BY.UTF-8"
loc=$(ask_ai_detect_locale)
if [ "$loc" = "ru_RU" ]; then
    pass "LANG=be_BY.UTF-8 → ru_RU"
else
    fail "Expected ru_RU, got '$loc'"
fi

# 1e. Russian from uk_UA
export LANG="uk_UA.UTF-8"
loc=$(ask_ai_detect_locale)
if [ "$loc" = "ru_RU" ]; then
    pass "LANG=uk_UA.UTF-8 → ru_RU"
else
    fail "Expected ru_RU, got '$loc'"
fi

# 1f. ASK_AI_LOCALE override (case insensitive)
export ASK_AI_LOCALE="RU"
export LANG="en_US.UTF-8"
loc=$(ask_ai_detect_locale)
if [ "$loc" = "ru_RU" ]; then
    pass "ASK_AI_LOCALE=RU (uppercase) → ru_RU"
else
    fail "Expected ru_RU, got '$loc'"
fi

# 1g. ASK_AI_LOCALE=ru (short form)
export ASK_AI_LOCALE="ru"
loc=$(ask_ai_detect_locale)
if [ "$loc" = "ru_RU" ]; then
    pass "ASK_AI_LOCALE=ru → ru_RU"
else
    fail "Expected ru_RU, got '$loc'"
fi

# 1h. ASK_AI_LOCALE=en (short form)
export ASK_AI_LOCALE="en"
loc=$(ask_ai_detect_locale)
if [ "$loc" = "en_EN" ]; then
    pass "ASK_AI_LOCALE=en → en_EN"
else
    fail "Expected en_EN, got '$loc'"
fi

# 1i. ASK_AI_LOCALE=EN_EN (mixed case)
export ASK_AI_LOCALE="En_En"
loc=$(ask_ai_detect_locale)
if [ "$loc" = "en_EN" ]; then
    pass "ASK_AI_LOCALE=En_En (mixed case) → en_EN"
else
    fail "Expected en_EN, got '$loc'"
fi

# 1j. ASK_AI_LOCALE empty → falls through to LANG
unset ASK_AI_LOCALE
export LANG="fr_FR.UTF-8"
loc=$(ask_ai_detect_locale)
if [ "$loc" = "en_EN" ]; then
    pass "Unsupported LANG=fr_FR.UTF-8 → en_EN fallback"
else
    fail "Expected en_EN, got '$loc'"
fi

# Restore env
if [ -n "$_old_lang" ]; then
    export LANG="$_old_lang"
else
    unset LANG
fi
if [ -n "$_old_ask_locale" ]; then
    export ASK_AI_LOCALE="$_old_ask_locale"
else
    unset ASK_AI_LOCALE
fi

# ======================================================
print_header "2. ask_ai_load_locale"
# ======================================================

# 2a. Load from locales/ subdirectory (relative to script_dir)
_script_dir="$PROJECT_DIR/src"
if ask_ai_load_locale "$_script_dir" "en_EN"; then
    pass "ask_ai_load_locale returned 0 for existing locale en_EN"
else
    fail "ask_ai_load_locale should return 0 for existing locale"
fi

# 2b. Non-existent locale → return 1
if ask_ai_load_locale "$_script_dir" "xx_XX" 2>/dev/null; then
    fail "ask_ai_load_locale should return 1 for missing locale"
else
    pass "Missing locale xx_XX → return 1"
fi

# ======================================================
print_header "3. ask_ai_is_text_file"
# ======================================================

# 3a. Plain text file
echo "hello world" > "$TEST_DIR/text.txt"
if ask_ai_is_text_file "$TEST_DIR/text.txt"; then
    pass "Plain text file → text"
else
    fail "Plain text should be detected as text"
fi

# 3b. Binary file with NUL byte
printf 'hello\0world' > "$TEST_DIR/binary.bin"
if ask_ai_is_text_file "$TEST_DIR/binary.bin"; then
    fail "Binary with NUL should NOT be text"
else
    pass "Binary with NUL byte → not text"
fi

# 3c. Empty file (inode/x-empty)
: > "$TEST_DIR/empty.txt"
if ask_ai_is_text_file "$TEST_DIR/empty.txt"; then
    pass "Empty file (x-empty) → text"
else
    fail "Empty file should be detected as text"
fi

# 3d. JSON file
echo '{"key": "value"}' > "$TEST_DIR/data.json"
if ask_ai_is_text_file "$TEST_DIR/data.json"; then
    pass "JSON file → text"
else
    fail "JSON should be detected as text"
fi

# 3e. XML file
echo '<root><item/></root>' > "$TEST_DIR/data.xml"
if ask_ai_is_text_file "$TEST_DIR/data.xml"; then
    pass "XML file → text"
else
    fail "XML should be detected as text"
fi

# 3f. Shell script
echo '#!/bin/bash' > "$TEST_DIR/script.sh"
echo 'echo hi' >> "$TEST_DIR/script.sh"
if ask_ai_is_text_file "$TEST_DIR/script.sh"; then
    pass "Shell script → text"
else
    fail "Shell script should be detected as text"
fi

# 3g. Python script
echo '#!/usr/bin/env python3' > "$TEST_DIR/script.py"
echo 'print("hi")' >> "$TEST_DIR/script.py"
if ask_ai_is_text_file "$TEST_DIR/script.py"; then
    pass "Python script → text"
else
    fail "Python script should be detected as text"
fi

# 3h. YAML file
echo 'key: value' > "$TEST_DIR/data.yaml"
if ask_ai_is_text_file "$TEST_DIR/data.yaml"; then
    pass "YAML file → text"
else
    fail "YAML should be detected as text"
fi

# 3i. JavaScript file
echo 'const x = 1;' > "$TEST_DIR/data.js"
if ask_ai_is_text_file "$TEST_DIR/data.js"; then
    pass "JavaScript file → text"
else
    fail "JavaScript should be detected as text"
fi

# 3j. CSV file
echo 'a,b,c' > "$TEST_DIR/data.csv"
if ask_ai_is_text_file "$TEST_DIR/data.csv"; then
    pass "CSV file → text"
else
    fail "CSV should be detected as text"
fi

# 3k. Non-existent file
if ask_ai_is_text_file "$TEST_DIR/nonexistent.txt" 2>/dev/null; then
    fail "Non-existent file should NOT be text"
else
    pass "Non-existent file → not text"
fi

# 3l. Directory (not a regular file)
mkdir -p "$TEST_DIR/mydir"
if ask_ai_is_text_file "$TEST_DIR/mydir" 2>/dev/null; then
    fail "Directory should NOT be text"
else
    pass "Directory → not text"
fi

# 3m. Large text file (over 200 KiB — still text)
dd if=/dev/zero bs=1024 count=250 2>/dev/null | tr '\0' 'A' > "$TEST_DIR/large.txt" || \
    head -c 256000 /dev/zero | tr '\0' 'A' > "$TEST_DIR/large.txt"
if ask_ai_is_text_file "$TEST_DIR/large.txt"; then
    pass "Large text file (250 KiB) → text"
else
    fail "Large text file should still be detected as text"
fi

# 3n. Unreadable file
echo "secret" > "$TEST_DIR/secret.txt"
chmod 000 "$TEST_DIR/secret.txt"
if ask_ai_is_text_file "$TEST_DIR/secret.txt" 2>/dev/null; then
    fail "Unreadable file should NOT be text"
else
    pass "Unreadable file → not text"
fi
chmod 644 "$TEST_DIR/secret.txt"

# ======================================================
print_header "4. ask_ai_file_size"
# ======================================================

# 4a. Small file
echo -n "hello" > "$TEST_DIR/small.txt"
sz=$(ask_ai_file_size "$TEST_DIR/small.txt")
if [ "$sz" -eq 5 ]; then
    pass "Small file (5 bytes) → $sz"
else
    fail "Expected 5, got '$sz'"
fi

# 4b. Empty file
: > "$TEST_DIR/empty.txt"
sz=$(ask_ai_file_size "$TEST_DIR/empty.txt")
if [ "$sz" -eq 0 ]; then
    pass "Empty file → $sz"
else
    fail "Expected 0, got '$sz'"
fi

# 4c. File with one byte
echo -n "x" > "$TEST_DIR/onebyte.txt"
sz=$(ask_ai_file_size "$TEST_DIR/onebyte.txt")
if [ "$sz" -eq 1 ]; then
    pass "One-byte file → $sz"
else
    fail "Expected 1, got '$sz'"
fi

# 4d. File with newline
echo "hello" > "$TEST_DIR/newline.txt"
sz=$(ask_ai_file_size "$TEST_DIR/newline.txt")
if [ "$sz" -eq 6 ]; then
    pass "File with newline (6 bytes) → $sz"
else
    fail "Expected 6, got '$sz'"
fi

# 4e. Larger file (10 KiB)
dd if=/dev/zero bs=1024 count=10 2>/dev/null > "$TEST_DIR/10k.bin" || \
    head -c 10240 /dev/zero > "$TEST_DIR/10k.bin"
sz=$(ask_ai_file_size "$TEST_DIR/10k.bin")
if [ "$sz" -eq 10240 ]; then
    pass "10 KiB file → $sz"
else
    fail "Expected 10240, got '$sz'"
fi

# 4f. Non-existent file
sz=$(ask_ai_file_size "$TEST_DIR/nonexistent" 2>/dev/null || echo 0)
if [ "$sz" -eq 0 ] || [ -z "$sz" ]; then
    pass "Non-existent file → 0 (or empty)"
else
    fail "Expected 0 or empty for missing file, got '$sz'"
fi

# ======================================================
print_header "5. ask_ai_dir_listing"
# ======================================================

# 5a. Directory with files
mkdir -p "$TEST_DIR/list_a"
for i in a b c d e; do
    echo "$i" > "$TEST_DIR/list_a/$i.txt"
done
listing=$(ask_ai_dir_listing "$TEST_DIR/list_a")
count=$(echo "$listing" | wc -l)
if [ "$count" -eq 5 ]; then
    pass "Directory with 5 files → $count entries"
else
    fail "Expected 5 entries, got $count (listing: $listing)"
fi

# 5b. Empty directory
mkdir -p "$TEST_DIR/list_empty"
listing=$(ask_ai_dir_listing "$TEST_DIR/list_empty")
if [ -z "$listing" ]; then
    pass "Empty directory → no entries"
else
    fail "Expected empty output, got '$listing'"
fi

# 5c. Directory with hidden files
mkdir -p "$TEST_DIR/list_hidden"
echo "visible" > "$TEST_DIR/list_hidden/visible.txt"
echo "hidden" > "$TEST_DIR/list_hidden/.hidden.txt"
listing=$(ask_ai_dir_listing "$TEST_DIR/list_hidden")
count=$(echo "$listing" | wc -l)
if [ "$count" -eq 2 ]; then
    pass "Directory with visible + hidden files → $count entries (includes hidden)"
else
    fail "Expected 2 entries (visible + hidden), got $count"
fi

# 5d. Max limit (max=3)
mkdir -p "$TEST_DIR/list_many"
for i in $(seq 1 10); do
    echo "$i" > "$TEST_DIR/list_many/file$i.txt"
done
listing=$(ask_ai_dir_listing "$TEST_DIR/list_many" 3)
count=$(echo "$listing" | wc -l)
if [ "$count" -eq 4 ]; then
    # 3 entries + 1 ellipsis line
    pass "Max=3 limit → 3 entries + … (total $count lines)"
else
    fail "Expected 4 lines (3 entries + …), got $count"
fi

# 5e. Default max is 50
mkdir -p "$TEST_DIR/list_50"
for i in $(seq 1 60); do
    echo "$i" > "$TEST_DIR/list_50/file$i.txt"
done
listing=$(ask_ai_dir_listing "$TEST_DIR/list_50")
count=$(echo "$listing" | wc -l)
if [ "$count" -eq 51 ]; then
    # 50 entries + 1 ellipsis line
    pass "Default max=50 → 50 entries + … (total $count lines)"
else
    fail "Expected 51 lines (50 entries + …), got $count"
fi

# 5f. Directory name ends with a space (edge case)
mkdir -p "$TEST_DIR/space dir"
echo "test" > "$TEST_DIR/space dir/file.txt"
listing=$(ask_ai_dir_listing "$TEST_DIR/space dir")
count=$(echo "$listing" | wc -l)
if [ "$count" -eq 1 ]; then
    pass "Dir with space in name → works correctly"
else
    fail "Expected 1 entry, got $count"
fi

# ======================================================
echo ""
if [ "$FAILED" -eq 1 ]; then
    echo "❌ SOME TESTS FAILED"
    exit 1
else
    echo "✅ ALL TESTS PASSED"
    exit 0
fi
