#!/bin/bash
# ask-dolphin.sh — called from the Dolphin service menu
# 1. PyQt5 dialog: preset buttons + custom input field
# 2. Konsole with glow for streaming AI response
#
# Model: set via ASK_MODEL environment variable (export ASK_MODEL="opencode/...")
# Preset queries: configured in ~/.config/ask-dolphin.cfg

# --- Determine install directory (look alongside this script) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Locale detection ---
# Priority: ASK_LOCALE env → $LANG → en_EN (same as runner + dialog)
DETECTED_LOCALE="en_EN"
case "${ASK_LOCALE:-}" in
    ru_RU|ru) DETECTED_LOCALE="ru_RU" ;;
    en_EN|en) DETECTED_LOCALE="en_EN" ;;
    *)
        case "${LANG:-}" in
            ru_RU*|ru_UA*|be_BY*|uk_UA*) DETECTED_LOCALE="ru_RU" ;;
        esac
        ;;
esac
LOCALE="$DETECTED_LOCALE"

# Load locale file if available (check next to script or project root for source runs)
LOCALE_FILE="$SCRIPT_DIR/locales/$LOCALE"
[ -f "$LOCALE_FILE" ] || LOCALE_FILE="$(dirname "$SCRIPT_DIR")/locales/$LOCALE"
[ -f "$LOCALE_FILE" ] && source "$LOCALE_FILE"

# Localized strings (from locale file or inline defaults)
LBL_SELECTED_FILES="${sh_lbl_selected_files:-Selected files:}"
LBL_CURRENT_DIR="${sh_lbl_current_dir:-Current directory:}"

# --- Preset queries (read from ~/.config/ask-dolphin.cfg) ---
ASK_PRESETS=()
CONFIG_FILE="$HOME/.config/ask-dolphin.cfg"
if [ -f "$CONFIG_FILE" ]; then
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" == \#* ]] && continue
        ASK_PRESETS+=("$line")
    done < "$CONFIG_FILE"
fi
# Fallback if config is empty or missing
if [ ${#ASK_PRESETS[@]} -eq 0 ]; then
    ASK_PRESETS=(
        "Describe these files"
        "Find bugs in these files"
        "Optimize this code"
        "Review code quality"
        "Generate documentation"
        "Refactor this code"
        "Write tests for these files"
    )
fi

# Limit to last 8 presets (dialog fits max 8 buttons comfortably)
MAX_PRESETS=8
if [ ${#ASK_PRESETS[@]} -gt $MAX_PRESETS ]; then
    ASK_PRESETS=("${ASK_PRESETS[@]: -$MAX_PRESETS}")
fi

# Filter out empty arguments (in case Dolphin passes an empty string)
FILES=()
for f in "$@"; do
    [ -n "$f" ] && FILES+=("$f")
done

# If nothing is selected — use the current directory
HAS_SELECTION=true
if [ ${#FILES[@]} -eq 0 ]; then
    HAS_SELECTION=false
    FILES=("$PWD")
fi

# --- Collect file info ---
if [ "$HAS_SELECTION" = true ]; then
    FILE_LIST="${LBL_SELECTED_FILES}\
"
else
    FILE_LIST="${LBL_CURRENT_DIR}\
"
fi
for f in "${FILES[@]}"; do
    BASENAME=$(basename "$f")
    if [ -d "$f" ]; then
        FILE_LIST+="📁 $BASENAME\n"
    else
        SIZE=$(du -h "$f" 2>/dev/null | cut -f1)
        FILE_LIST+="📄 $BASENAME  ($SIZE)\\n"
    fi
done

# --- PyQt5 dialog: preset buttons + input field ---
DIALOG="$SCRIPT_DIR/ask-dolphin-dialog.py"
QUERY=$(echo -e "$FILE_LIST" | "$DIALOG" "${ASK_PRESETS[@]}")

# If Cancel was pressed
if [ $? -ne 0 ]; then
    exit 0
fi

# If query is empty — exit
if [ -z "$QUERY" ]; then
    exit 0
fi

# --- Open Konsole with the runner (ASK_MODEL is passed from environment) ---
RUNNER="$SCRIPT_DIR/ask-dolphin-run.sh"
exec konsole -e "$RUNNER" "$QUERY" "${FILES[@]}"
