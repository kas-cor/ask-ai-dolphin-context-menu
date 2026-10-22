#!/bin/bash
# CI test: install.sh (sandboxed HOME, fake dependencies)
# Tests:
#   1. ./install.sh ru_RU → Russian UI/config even with LANG=en_US
#   2. ./install.sh en_EN → English config even with LANG=ru_RU
#   3. No argument → LANG decides (ru_RU.UTF-8 → Russian)
#   4. Installed .desktop: @HOME@ substituted, Exec quoted
#   5. Installed layout: scripts, locales, ~/.ask_ai, shell rc line
#   6. opencode v1 only → dedicated warning, installation still completes
#   7. Dependency check follows ASK_AI_AGENT (no opencode needed for gemini)
#   8. uninstall.sh removes only project files

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

if ! python3 -c "import PyQt5" 2>/dev/null && ! python3 -c "import PyQt6" 2>/dev/null; then
    echo "❌ PyQt5/PyQt6 is required to run this test (install python3-pyqt5)"
    exit 1
fi

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

make_bin() {
    local dir="$1" version="$2"
    mkdir -p "$dir"
    cat >"$dir/opencode" <<EOF
#!/bin/bash
if [ "\${1:-}" = "--version" ]; then echo "$version"; exit 0; fi
if [ "\${1:-}" = "api" ]; then echo '{"data":[]}'; exit 0; fi
exit 0
EOF
    cat >"$dir/konsole" <<'EOF'
#!/bin/bash
exit 0
EOF
    cat >"$dir/glow" <<'EOF'
#!/bin/bash
cat
EOF
    chmod +x "$dir"/opencode "$dir"/konsole "$dir"/glow
}

# Run the installer in an isolated HOME.
# Usage: run_install <home> <bin-dir> <locale-arg> [KEY=VALUE ...]
run_install() {
    local home="$1" bin="$2" arg="$3"
    shift 3
    mkdir -p "$home"
    : >"$home/.bashrc"
    env -i \
        HOME="$home" \
        PATH="$bin:/usr/local/bin:/usr/bin:/bin" \
        SHELL=/bin/bash \
        TERM=xterm \
        "$@" \
        bash "$PROJECT_DIR/install.sh" "$arg" 2>&1
}

# ------------------------------------------------------
print_header "1. ./install.sh ru_RU (LANG=en_US)"
# ------------------------------------------------------
BIN_V2="$TEST_DIR/bin-v2"
make_bin "$BIN_V2" "v2.0.27"
H1="$TEST_DIR/home-ru-arg"
out=$(run_install "$H1" "$BIN_V2" ru_RU LANG=en_US.UTF-8) || true

case "$out" in
    *"Установка завершена"*) pass "Installer messages are Russian" ;;
    *) fail "Expected Russian installer output, got: $(printf '%s' "$out" | tail -3)" ;;
esac
if grep -q "Опиши эти файлы" "$H1/.config/ask-ai-dolphin.cfg" 2>/dev/null; then
    pass "ru_RU presets installed"
else
    fail "Expected Russian presets in ~/.config/ask-ai-dolphin.cfg"
fi
if [ -f "$H1/.local/bin/locales/ru_RU" ] && [ -f "$H1/.local/bin/locales/en_EN" ]; then
    pass "All locale files copied to ~/.local/bin/locales"
else
    fail "Locale files missing after install"
fi
for f in ask-ai-common.sh ask-ai-dolphin.sh ask-ai-dolphin-run.sh ask-ai-dolphin-dialog.py \
    ask-ai-acp-client.py; do
    [ -x "$H1/.local/bin/$f" ] || fail "$f missing or not executable"
done
pass "Scripts installed and executable"

if [ -f "$H1/.ask_ai" ]; then
    pass "~/.ask_ai created"
else
    fail "~/.ask_ai was not created"
fi
if grep -Fq '. ~/.ask_ai' "$H1/.bashrc" 2>/dev/null; then
    pass "Shell rc source line added"
else
    fail "Shell rc source line missing"
fi

DESKTOP="$H1/.local/share/kio/servicemenus/ask-ai-dolphin.desktop"
if [ -f "$DESKTOP" ]; then
    if grep -q '@HOME@' "$DESKTOP"; then
        fail ".desktop still contains the @HOME@ placeholder"
    else
        pass ".desktop has \$HOME substituted"
    fi
    if grep -Fq "Exec=\"$H1/.local/bin/ask-ai-dolphin.sh\" %F" "$DESKTOP"; then
        pass ".desktop Exec is quoted and points at the installed script"
    else
        fail ".desktop Exec wrong: $(grep -F 'Exec=' "$DESKTOP")"
    fi
else
    fail ".desktop was not installed"
fi

# ------------------------------------------------------
print_header "2. ./install.sh en_EN (LANG=ru_RU)"
# ------------------------------------------------------
H2="$TEST_DIR/home-en-arg"
out=$(run_install "$H2" "$BIN_V2" en_EN LANG=ru_RU.UTF-8) || true
if grep -q "Describe these files" "$H2/.config/ask-ai-dolphin.cfg" 2>/dev/null; then
    pass "en_EN argument overrides LANG=ru_RU.UTF-8"
else
    fail "en_EN argument was ignored (LANG won)"
fi

# ------------------------------------------------------
print_header "3. No argument → LANG decides"
# ------------------------------------------------------
H3="$TEST_DIR/home-lang-ru"
out=$(run_install "$H3" "$BIN_V2" "" LANG=ru_RU.UTF-8) || true
if grep -q "Опиши эти файлы" "$H3/.config/ask-ai-dolphin.cfg" 2>/dev/null; then
    pass "LANG=ru_RU.UTF-8 → Russian config"
else
    fail "LANG-based detection failed"
fi

H4="$TEST_DIR/home-lang-en"
out=$(run_install "$H4" "$BIN_V2" "" LANG=en_US.UTF-8) || true
if grep -q "Describe these files" "$H4/.config/ask-ai-dolphin.cfg" 2>/dev/null; then
    pass "LANG=en_US.UTF-8 → English config"
else
    fail "English fallback failed"
fi

# ------------------------------------------------------
print_header "4. Unknown locale argument falls back to LANG"
# ------------------------------------------------------
H5="$TEST_DIR/home-unknown"
out=$(run_install "$H5" "$BIN_V2" de_DE LANG=ru_RU.UTF-8) || true
if grep -q "Опиши эти файлы" "$H5/.config/ask-ai-dolphin.cfg" 2>/dev/null; then
    pass "Unknown argument (de_DE) keeps the LANG-based locale"
else
    fail "Unknown argument forced English instead of falling back to LANG"
fi

# ------------------------------------------------------
print_header "5. opencode v1 only → warning, install completes"
# ------------------------------------------------------
BIN_V1="$TEST_DIR/bin-v1"
make_bin "$BIN_V1" "1.19.0"
H6="$TEST_DIR/home-v1"
rc=0
out=$(run_install "$H6" "$BIN_V1" en_EN LANG=en_US.UTF-8) || rc=$?
if [ "$rc" -eq 0 ]; then
    pass "Install completes with v1 in PATH (runtime v1 is a warning, not a hard error)"
else
    fail "Install should complete, got rc=$rc"
fi
case "$out" in
    *"opencode v2 not found"*) pass "v2 warning shown" ;;
    *) fail "Missing opencode v2 warning" ;;
esac
if [ -x "$H6/.local/bin/ask-ai-dolphin.sh" ]; then
    pass "Files installed despite the warning"
else
    fail "Install did not complete"
fi

# ------------------------------------------------------
print_header "6. Dependency check follows ASK_AI_AGENT"
# ------------------------------------------------------
# ACP is the default harness and the agent is configurable, so an installation
# with gemini (or claude, codex, …) must not demand the opencode CLI.
BIN_GEMINI="$TEST_DIR/bin-gemini"
mkdir -p "$BIN_GEMINI"
printf '#!/bin/bash\nexit 0\n' >"$BIN_GEMINI/konsole"
printf '#!/bin/bash\ncat\n' >"$BIN_GEMINI/glow"
printf '#!/bin/bash\nexit 0\n' >"$BIN_GEMINI/gemini"
chmod +x "$BIN_GEMINI"/*
H_GEMINI="$TEST_DIR/home-gemini"
rc=0
out=$(run_install "$H_GEMINI" "$BIN_GEMINI" en_EN LANG=en_US.UTF-8 ASK_AI_AGENT=gemini) || rc=$?
if [ "$rc" -eq 0 ] && [ -x "$H_GEMINI/.local/bin/ask-ai-dolphin.sh" ]; then
    pass "Install completes with gemini and no opencode in PATH"
else
    fail "Installer still required opencode (rc=$rc): $(printf '%s' "$out" | tail -4 | tr '\n' ' ')"
fi
case "$out" in
    *"opencode v2 not found"*) fail "opencode v2 warning shown for a gemini setup" ;;
    *) pass "No opencode warning when another agent is selected" ;;
esac

# …and when that agent is missing, its own install hint is what the user sees.
BIN_NOAGENT="$TEST_DIR/bin-noagent"
mkdir -p "$BIN_NOAGENT"
printf '#!/bin/bash\nexit 0\n' >"$BIN_NOAGENT/konsole"
printf '#!/bin/bash\ncat\n' >"$BIN_NOAGENT/glow"
chmod +x "$BIN_NOAGENT"/*
H_GEMINI_MISSING="$TEST_DIR/home-gemini-missing"
rc=0
out=$(run_install "$H_GEMINI_MISSING" "$BIN_NOAGENT" en_EN LANG=en_US.UTF-8 ASK_AI_AGENT=gemini) || rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -qF 'npm install -g @google/gemini-cli'; then
    pass "Missing agent fails the install with its own install hint"
else
    fail "Missing gemini was not reported properly (rc=$rc): $(printf '%s' "$out" | tail -4 | tr '\n' ' ')"
fi

# ------------------------------------------------------
print_header "7. uninstall.sh removes only project files"
# ------------------------------------------------------
H7="$TEST_DIR/home-uninstall"
run_install "$H7" "$BIN_V2" en_EN LANG=en_US.UTF-8 >/dev/null 2>&1 || true

# A foreign locale file must survive the uninstall.
printf 'some_other_tool_key="x"\n' >"$H7/.local/bin/locales/xx_XX"
# Runtime cache created by the dialog/effort code.
mkdir -p "$H7/.cache/ask-ai"
: >"$H7/.cache/ask-ai/models.json"
# User data that must be kept.
printf 'custom preset\n' >"$H7/.config/ask-ai-dolphin.cfg"
printf 'old query\n' >"$H7/.config/ask-ai-dolphin.history"

rc=0
env -i HOME="$H7" PATH="$BIN_V2:/usr/local/bin:/usr/bin:/bin" \
    bash "$PROJECT_DIR/uninstall.sh" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 0 ]; then
    pass "Uninstaller exits 0"
else
    fail "Uninstaller failed with rc=$rc"
fi

if [ ! -e "$H7/.local/bin/ask-ai-dolphin.sh" ] && [ ! -e "$H7/.local/bin/ask-ai-common.sh" ] \
    && [ ! -e "$H7/.local/bin/ask-ai-acp-client.py" ]; then
    pass "Scripts removed"
else
    fail "Scripts were not removed"
fi
if [ ! -e "$H7/.local/bin/locales/ru_RU" ] && [ ! -e "$H7/.local/bin/locales/en_EN" ]; then
    pass "Project locale files removed"
else
    fail "Project locale files left behind"
fi
if [ -f "$H7/.local/bin/locales/xx_XX" ]; then
    pass "Foreign locale file preserved"
else
    fail "Uninstaller deleted a file it does not own"
fi
if [ ! -e "$H7/.local/share/kio/servicemenus/ask-ai-dolphin.desktop" ]; then
    pass "Service menu removed"
else
    fail "Service menu left behind"
fi
if [ ! -e "$H7/.cache/ask-ai" ]; then
    pass "Runtime cache removed"
else
    fail "Runtime cache left behind"
fi
if [ -f "$H7/.config/ask-ai-dolphin.cfg" ] && [ -f "$H7/.config/ask-ai-dolphin.history" ]; then
    pass "User config and history preserved (documented as manual cleanup)"
else
    fail "Uninstaller deleted user config/history"
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
