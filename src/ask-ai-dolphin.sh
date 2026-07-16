#!/bin/bash
# ask-ai-dolphin.sh — called from the Dolphin service menu
# 1. PyQt5/6 dialog: preset buttons + custom input field
# 2. Terminal with glow for streaming AI response
#
# Model: set via ASK_AI_MODEL environment variable (export ASK_AI_MODEL="opencode/...")
# Preset queries: configured in ~/.config/ask-ai-dolphin.cfg

# --- Install directory ---
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    case "${ASK_AI_LOCALE:-}" in ru_RU|ru) LOCALE="ru_RU" ;; esac
    case "${LANG:-}" in ru_RU*|ru_UA*|be_BY*|uk_UA*) LOCALE="ru_RU" ;; esac
    [ -f "$INSTALL_DIR/locales/$LOCALE" ] && source "$INSTALL_DIR/locales/$LOCALE"
fi

LBL_SELECTED_FILES="${sh_lbl_selected_files:-Selected files:}"
LBL_CURRENT_DIR="${sh_lbl_current_dir:-Current directory:}"
ERR_NO_TERMINAL="${sh_err_no_terminal:-No terminal emulator found (konsole, kgx, gnome-terminal, xterm, or \$TERMINAL).}"

# --- Preset queries ---
ASK_AI_PRESETS=()
CONFIG_FILE="$HOME/.config/ask-ai-dolphin.cfg"
if [ -f "$CONFIG_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
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
QUERY=$(printf '%s' "$FILE_LIST" | "$DIALOG" "${ASK_AI_PRESETS[@]}")
DIALOG_STATUS=$?

if [ "$DIALOG_STATUS" -ne 0 ]; then
    exit 0
fi

if [ -z "$QUERY" ]; then
    exit 0
fi

# --- Launch runner in a terminal ---
RUNNER="$INSTALL_DIR/ask-ai-dolphin-run.sh"

launch_in_terminal() {
    # Priority: $TERMINAL (if set) → Konsole → kgx → gnome-terminal → xterm → inline TTY
    if [ -n "${TERMINAL:-}" ] && command -v "$TERMINAL" &>/dev/null; then
        if "$TERMINAL" -e "$RUNNER" "$QUERY" "${FILES[@]}" 2>/dev/null; then
            exit 0
        fi
        exec "$TERMINAL" -- "$RUNNER" "$QUERY" "${FILES[@]}"
    fi

    if command -v konsole &>/dev/null; then
        exec konsole -e "$RUNNER" "$QUERY" "${FILES[@]}"
    fi

    if command -v kgx &>/dev/null; then
        exec kgx -- "$RUNNER" "$QUERY" "${FILES[@]}"
    fi
    if command -v gnome-terminal &>/dev/null; then
        exec gnome-terminal -- "$RUNNER" "$QUERY" "${FILES[@]}"
    fi
    if command -v xterm &>/dev/null; then
        exec xterm -e "$RUNNER" "$QUERY" "${FILES[@]}"
    fi

    # Last resort: already in a TTY
    if [ -t 1 ]; then
        exec "$RUNNER" "$QUERY" "${FILES[@]}"
    fi

    echo "$ERR_NO_TERMINAL" >&2
    exit 1
}

launch_in_terminal
