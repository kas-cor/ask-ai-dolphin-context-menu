#!/bin/bash
# ask-ai-common.sh — shared helpers for Ask AI Dolphin scripts
# Sourced by ask-ai-dolphin.sh, ask-ai-dolphin-run.sh, and install.sh (local mode).
# Do not execute directly.

# --- Locale detection ---
# Priority: ASK_AI_LOCALE env → $LANG → en_EN
# Russian also from ru_UA*, be_BY*, uk_UA*.
ask_ai_detect_locale() {
    _locale_lower="${ASK_AI_LOCALE:-}"
    _locale_lower="${_locale_lower,,}"
    case "$_locale_lower" in
        ru_RU|ru) echo "ru_RU"; return ;;
        en_EN|en) echo "en_EN"; return ;;
    esac
    case "${LANG:-}" in
        ru_RU*|ru_UA*|be_BY*|uk_UA*) echo "ru_RU"; return ;;
    esac
    echo "en_EN"
}

# Load locale file into the current shell (KEY=value exports via source).
# Tries: <script_dir>/locales/<locale>, then <parent>/locales/<locale>.
# Usage: ask_ai_load_locale "$SCRIPT_DIR" "$LOCALE"
ask_ai_load_locale() {
    local script_dir="$1"
    local locale="$2"
    local locale_file="$script_dir/locales/$locale"
    if [ ! -f "$locale_file" ]; then
        locale_file="$(dirname "$script_dir")/locales/$locale"
    fi
    if [ -f "$locale_file" ]; then
        # shellcheck disable=SC1090
        source "$locale_file"
        return 0
    fi
    return 1
}

# True if path looks like a text file suitable for opencode -f attachment.
# Uses file(1) MIME when available; otherwise rejects NUL in the first 8 KiB.
ask_ai_is_text_file() {
    local f="$1"
    [ -f "$f" ] || return 1
    [ -r "$f" ] || return 1
    if command -v file &>/dev/null; then
        local mime
        mime=$(file --brief --mime-type -- "$f" 2>/dev/null || true)
        case "$mime" in
            text/*|application/json|application/xml|application/javascript|\
            application/x-sh|application/x-shellscript|application/x-python|\
            application/toml|application/x-yaml|application/yaml|\
            application/sql|inode/x-empty|application/csv)
                return 0
                ;;
            *)
                return 1
                ;;
        esac
    fi
    # Fallback: reject if NUL byte in first 8k
    if command -v grep &>/dev/null; then
        ! grep -a -q $'\0' < <(head -c 8192 -- "$f" 2>/dev/null)
    else
        return 0
    fi
}

# File size in bytes (portable).
ask_ai_file_size() {
    local f="$1"
    if stat --version &>/dev/null 2>&1; then
        # GNU stat
        stat -c%s -- "$f" 2>/dev/null || echo 0
    else
        # BSD stat
        stat -f%z -- "$f" 2>/dev/null || wc -c < "$f" | tr -d ' '
    fi
}

# Build a short directory listing for the prompt (non-recursive, max 50 entries).
ask_ai_dir_listing() {
    local d="$1"
    local max="${2:-50}"
    local count=0
    local entry
    # shellcheck disable=SC2012
    for entry in "$d"/* "$d"/.[!.]* "$d"/..?*; do
        [ -e "$entry" ] || continue
        printf '  %s\n' "$(basename "$entry")"
        count=$((count + 1))
        [ "$count" -ge "$max" ] && { echo "  …"; break; }
    done
}
