#!/bin/bash
# ask-ai-dolphin.sh — called from the Dolphin service menu
# 1. PyQt5/6 dialog: preset buttons + custom input field
# 2. Terminal with glow for streaming AI response
#
# Model: set via ASK_AI_MODEL environment variable (export ASK_AI_MODEL="opencode/...")
# Preset queries: configured in ~/.config/ask-ai-dolphin.cfg

# --- Install directory ---
# Strict mode: fail fast on unset vars and errors.
set -eu

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- User config ---
# The service menu inherits the desktop session environment, which does not
# source ~/.bashrc / ~/.zshrc. Without this, settings from ~/.ask_ai (model,
# mode, locale, save dir, …) would silently not apply when started from Dolphin.
if [ -f "$HOME/.ask_ai" ]; then
    # shellcheck disable=SC1090
    source "$HOME/.ask_ai" || true
fi

# --- Shared helpers ---
# shellcheck source=ask-ai-common.sh
if [ -f "$INSTALL_DIR/ask-ai-common.sh" ]; then
    # shellcheck disable=SC1091
    source "$INSTALL_DIR/ask-ai-common.sh"
elif [ -f "$(dirname "$INSTALL_DIR")/src/ask-ai-common.sh" ]; then
    # shellcheck disable=SC1091
    source "$(dirname "$INSTALL_DIR")/src/ask-ai-common.sh"
fi

# --- Locale ---
if declare -F ask_ai_detect_locale &>/dev/null; then
    LOCALE=$(ask_ai_detect_locale)
    ask_ai_load_locale "$INSTALL_DIR" "$LOCALE" || true
else
    LOCALE="en_EN"
    _lc="${ASK_AI_LOCALE:-}"
    _lc="${_lc,,}"
    _lc="${_lc//-/_}"
    case "$_lc" in
        ru|ru_ru) LOCALE="ru_RU" ;;
        en|en_en) LOCALE="en_EN" ;;
    esac
    case "${LANG:-}" in ru_RU*|ru_UA*|be_BY*|uk_UA*) LOCALE="ru_RU" ;; esac
    # shellcheck disable=SC1090
    [ -f "$INSTALL_DIR/locales/$LOCALE" ] && source "$INSTALL_DIR/locales/$LOCALE"
fi

LBL_SELECTED_FILES="${sh_lbl_selected_files:-Selected files:}"
LBL_CURRENT_DIR="${sh_lbl_current_dir:-Current directory:}"
ERR_NO_TERMINAL="${sh_err_no_terminal:-No terminal emulator found (konsole, kgx, gnome-terminal, xterm, or \$TERMINAL).}"
ERR_DIALOG="${sh_err_dialog:-Dialog failed — details: %s}"

# --- Preset queries ---
ASK_AI_PRESETS=()
CONFIG_FILE="$HOME/.config/ask-ai-dolphin.cfg"
if [ -f "$CONFIG_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"   # tolerate CRLF configs
        [[ -z "$line" || "$line" == \#* ]] && continue
        ASK_AI_PRESETS+=("$line")
    done < "$CONFIG_FILE"
fi

# Locale-aware fallbacks if config is empty or missing
if [ ${#ASK_AI_PRESETS[@]} -eq 0 ]; then
    if [ "$LOCALE" = "ru_RU" ]; then
        ASK_AI_PRESETS=(
            "Опиши эти файлы"
            "Найди ошибки в этих файлах"
            "Оптимизируй этот код"
            "Проверь качество кода"
            "Сгенерируй документацию"
            "Отрефактори этот код"
            "Напиши тесты для этих файлов"
        )
    else
        ASK_AI_PRESETS=(
            "Describe these files"
            "Find bugs in these files"
            "Optimize this code"
            "Review code quality"
            "Generate documentation"
            "Refactor this code"
            "Write tests for these files"
        )
    fi
fi

MAX_PRESETS=8
if [ ${#ASK_AI_PRESETS[@]} -gt $MAX_PRESETS ]; then
    ASK_AI_PRESETS=("${ASK_AI_PRESETS[@]: -$MAX_PRESETS}")
fi

# Filter empty args from Dolphin
FILES=()
for f in "$@"; do
    [ -n "$f" ] && FILES+=("$f")
done

HAS_SELECTION=true
if [ ${#FILES[@]} -eq 0 ]; then
    HAS_SELECTION=false
    FILES=("$PWD")
fi

# --- Collect file info (printf-safe, no echo -e on user paths) ---
FILE_LIST=""
if [ "$HAS_SELECTION" = true ]; then
    FILE_LIST="${LBL_SELECTED_FILES}"$'\n'
else
    FILE_LIST="${LBL_CURRENT_DIR}"$'\n'
fi
for f in "${FILES[@]}"; do
    BASENAME=$(basename -- "$f")
    if [ -d "$f" ]; then
        FILE_LIST+="📁 ${BASENAME}"$'\n'
    else
        SIZE=$(du -h -- "$f" 2>/dev/null | cut -f1)
        FILE_LIST+="📄 ${BASENAME}  (${SIZE})"$'\n'
    fi
done

# --- PyQt dialog ---
DIALOG="$INSTALL_DIR/ask-ai-dolphin-dialog.py"

# Keep the dialog's stderr (Qt warnings, Python tracebacks): otherwise a crash
# looks exactly like the user closing the window.
DIALOG_LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ask-ai"
mkdir -p "$DIALOG_LOG_DIR" 2>/dev/null || true
DIALOG_LOG="$DIALOG_LOG_DIR/dialog.log"
: >"$DIALOG_LOG" 2>/dev/null || DIALOG_LOG="/dev/null"

DIALOG_STATUS=0
QUERY=$(printf '%s' "$FILE_LIST" | "$DIALOG" "${ASK_AI_PRESETS[@]}" 2>>"$DIALOG_LOG") \
    || DIALOG_STATUS=$?

if [ "$DIALOG_STATUS" -ne 0 ]; then
    # 0 — query submitted, 1 — cancel, 2+ — the dialog crashed.
    if [ "$DIALOG_STATUS" -eq 1 ]; then
        exit 0
    fi
    # shellcheck disable=SC2059
    printf "$ERR_DIALOG\n" "$DIALOG_LOG" >&2
    exit 1
fi

if [ -z "$QUERY" ]; then
    exit 0
fi

# --- Launch runner in a terminal ---
RUNNER="$INSTALL_DIR/ask-ai-dolphin-run.sh"

# Run the runner inside a terminal and replace this process with it.
# Two families of terminals exist: -e takes the command (konsole, xterm, …),
# the rest take it after -- (kgx, gnome-terminal, kitty, foot, …). One attempt
# only: retrying with the other form opened a second window whenever the
# command itself exited non-zero.
#
# ASK_AI_PAUSE is set on the command line, not exported: Konsole hands the
# request to an already running instance, so the new session inherits that
# process's environment and never sees the variables exported here. Without
# the flag the runner ended without waiting and the window closed right after
# the answer. `env` sets it for the runner process itself — the terminal passes
# the command through verbatim.
# Usage: exec_in_terminal <binary> [extra args...]
exec_in_terminal() {
    local bin="$1"
    shift
    case "$(basename -- "$bin")" in
        konsole|xterm|urxvt|rxvt|st|alacritty|eterm)
            exec "$bin" "$@" -e env ASK_AI_PAUSE=1 "$RUNNER" "$QUERY" "${FILES[@]}"
            ;;
        *)
            exec "$bin" "$@" -- env ASK_AI_PAUSE=1 "$RUNNER" "$QUERY" "${FILES[@]}"
            ;;
    esac
}

launch_in_terminal() {
    # Priority: $TERMINAL (may carry arguments) → Konsole → kgx → gnome-terminal → xterm → inline TTY
    if [ -n "${TERMINAL:-}" ]; then
        # Split on whitespace so "konsole --hold" works.
        read -r -a _term <<<"$TERMINAL"
        if [ "${#_term[@]}" -gt 0 ] && command -v "${_term[0]}" &>/dev/null; then
            exec_in_terminal "${_term[0]}" "${_term[@]:1}"
        fi
    fi

    if command -v konsole &>/dev/null; then
        exec_in_terminal konsole
    fi
    if command -v kgx &>/dev/null; then
        exec_in_terminal kgx
    fi
    if command -v gnome-terminal &>/dev/null; then
        exec_in_terminal gnome-terminal
    fi
    if command -v xterm &>/dev/null; then
        exec_in_terminal xterm
    fi

    # Last resort: already in a TTY
    if [ -t 1 ]; then
        export ASK_AI_PAUSE=1
        exec "$RUNNER" "$QUERY" "${FILES[@]}"
    fi

    echo "$ERR_NO_TERMINAL" >&2
    exit 1
}

launch_in_terminal
