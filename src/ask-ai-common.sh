#!/bin/bash
# ask-ai-common.sh — shared helpers for Ask AI Dolphin scripts
# Sourced by ask-ai-dolphin.sh, ask-ai-dolphin-run.sh, and install.sh (local mode).
# Do not execute directly.

# --- Locale detection ---
# Priority: ASK_AI_LOCALE env → $LANG → en_EN
# Russian also from ru_UA*, be_BY*, uk_UA*.
ask_ai_detect_locale() {
    local ask_locale="${ASK_AI_LOCALE:-}"
    # Normalise before comparing: ASK_AI_LOCALE is documented as "ru_RU" /
    # "en_EN", but users also write RU, ru-RU or En_En.
    ask_locale="${ask_locale,,}"
    ask_locale="${ask_locale//-/_}"
    case "$ask_locale" in
        ru|ru_ru) echo "ru_RU"; return 0 ;;
        en|en_en) echo "en_EN"; return 0 ;;
    esac
    case "${LANG:-}" in
        ru_RU*|ru_UA*|be_BY*|uk_UA*) echo "ru_RU"; return 0 ;;
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
    # Fallback: reject if a NUL byte appears in the first 8 KiB.
    # grep cannot be used here: bash strings cannot hold NUL, so `$'\0'`
    # expands to an empty pattern that matches every file.
    if command -v od &>/dev/null; then
        local bytes
        bytes=$(od -An -tx1 -N 8192 -- "$f" 2>/dev/null) || return 1
        case "$bytes" in
            *" 00"*) return 1 ;;
        esac
        return 0
    fi
    # Neither file(1) nor od(1): assume text rather than dropping attachments.
    return 0
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

# Locate a usable opencode v2 binary and print its path.
#
# The GUI path (Dolphin → konsole -e) inherits the desktop session PATH, which
# does not source ~/.zshrc (or ~/.bashrc), so `opencode` can resolve to a system
# v1 build (e.g. /usr/sbin/opencode 1.x). v1 is incompatible with this plugin:
# its `run -f` flag is an array that swallows the prompt too and fails with
# "File not found: <prompt>". Candidates are checked in order — PATH hit,
# ~/.opencode/bin (the official v2 installer location), ~/.local/bin — and the
# first one whose major version is >= 2 wins. Every directory in $PATH is
# considered, not just the first hit: an older system v1 must not hide a v2
# that sits further along the PATH.
# Returns 1 when no v2 binary is found.
ask_ai_opencode_bin() {
    local candidates=() cand dir ver major seen=""
    local old_ifs="$IFS"
    IFS=':'
    for dir in $PATH; do
        [ -n "$dir" ] || continue
        [ -x "$dir/opencode" ] && candidates+=("$dir/opencode")
    done
    IFS="$old_ifs"
    candidates+=("${HOME:-}/.opencode/bin/opencode" "${HOME:-}/.local/bin/opencode")

    for cand in "${candidates[@]}"; do
        [ -n "$cand" ] && [ -x "$cand" ] || continue
        case "$seen" in *"|$cand|"*) continue ;; esac
        seen+="|$cand|"
        ver=$("$cand" --version 2>/dev/null | head -n1) || continue
        # Both "opencode v2.0.27" (v2) and bare "1.19.0" (v1) occur — pull
        # the first numeric version token, then check its major component.
        ver=$(printf '%s' "$ver" | grep -oE '[0-9]+(\.[0-9]+)*' | head -n1)
        major="${ver%%.*}"
        case "$major" in ''|*[!0-9]*) continue ;; esac
        [ "$major" -ge 2 ] 2>/dev/null || continue
        printf '%s\n' "$cand"
        return 0
    done
    return 1
}

# Resolve reasoning effort for opencode v2.
# v2 removed the `--variant` flag — effort is now a model variant passed inside
# the model id: --model "provider/model#variant". Variants are model-specific
# (e.g. deepseek-v4-flash: low/high/max; mimo-v2.6-flash-free: none), so the
# model catalog is queried before applying.
# Prints "<model>#<effort>" on success, nothing otherwise.
# Return codes:
#   0 — variant supported, output is the model with the variant appended
#   1 — model does not declare this variant
#   2 — could not verify (opencode/python3 missing, catalog unavailable)
#   3 — model id already pins a variant (…#…)
# Usage: ask_ai_apply_effort "opencode/deepseek-v4-flash" "high"
ask_ai_apply_effort() {
    local model="${1:-}" effort="${2:-}"
    [ -n "$model" ] && [ -n "$effort" ] || return 2
    case "$model" in *\#*) return 3 ;; esac
    local oc_bin
    oc_bin=$(ask_ai_opencode_bin 2>/dev/null) || return 2
    command -v python3 &>/dev/null || return 2

    # The catalog changes rarely and fetching it costs a network round-trip on
    # every query, so it is cached for a day. A stale catalog is still used
    # when the API is unavailable.
    local cache_dir="${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}/ask-ai"
    local cache_file="$cache_dir/models.json"
    local ttl=86400 mtime="" now payload_file=""

    if [ -f "$cache_file" ]; then
        mtime=$(stat -c %Y -- "$cache_file" 2>/dev/null \
            || stat -f %m -- "$cache_file" 2>/dev/null \
            || true)
        case "$mtime" in ''|*[!0-9]*) mtime=0 ;; esac
        now=$(date +%s)
        if [ "$mtime" -gt 0 ] && [ $((now - mtime)) -lt "$ttl" ]; then
            payload_file="$cache_file"
        fi
    fi

    if [ -z "$payload_file" ]; then
        mkdir -p "$cache_dir" 2>/dev/null || true
        # opencode v2 truncates stdout to 256 KiB when it is a pipe/command
        # substitution; a redirect to a regular file yields the full catalog.
        payload_file=$(mktemp) || return 2
        if "$oc_bin" api GET /api/model > "$payload_file" 2>/dev/null \
            && [ -s "$payload_file" ]; then
            if mv -f "$payload_file" "$cache_file" 2>/dev/null; then
                payload_file="$cache_file"
            fi
        else
            rm -f "$payload_file"
            [ -s "$cache_file" ] || return 2
            payload_file="$cache_file"
        fi
    fi

    # Exit codes from python: 0 = variant found, 1 = not declared, 2 = bad catalog
    local py_rc=0
    python3 - "$payload_file" "$model" "$effort" <<'PY' || py_rc=$?
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        data = json.load(fh).get("data") or []
except Exception:
    sys.exit(2)
model, effort = sys.argv[2], sys.argv[3]
provider, _, mid = model.partition("/")
for m in data:
    if m.get("providerID") == provider and m.get("modelID") == mid:
        for v in (m.get("variants") or []):
            if v.get("id") == effort:
                sys.exit(0)
        sys.exit(1)
sys.exit(1)
PY
    if [ "$payload_file" != "$cache_file" ]; then
        rm -f "$payload_file"
    fi
    [ "$py_rc" -eq 0 ] || return "$py_rc"

    printf '%s#%s\n' "$model" "$effort"
}

# Build a short directory listing for the prompt (non-recursive, max 50 entries).
ask_ai_dir_listing() {
    local d="$1"
    local max="${2:-50}"
    local count=0
    local entry

    [ -d "$d" ] || return 0

    # find(1) stops as soon as the limit is reached; globbing "$d"/* first
    # would expand every entry of a huge directory before trimming.
    if command -v find &>/dev/null; then
        while IFS= read -r -d '' entry; do
            printf '  %s\n' "${entry##*/}"
            count=$((count + 1))
            if [ "$count" -ge "$max" ]; then
                echo "  …"
                break
            fi
        done < <(find "$d" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
        return 0
    fi

    # Fallback without find(1): glob, including hidden entries.
    for entry in "$d"/* "$d"/.[!.]* "$d"/..?*; do
        [ -e "$entry" ] || continue
        printf '  %s\n' "$(basename -- "$entry")"
        count=$((count + 1))
        if [ "$count" -ge "$max" ]; then
            echo "  …"
            break
        fi
    done
    return 0
}
