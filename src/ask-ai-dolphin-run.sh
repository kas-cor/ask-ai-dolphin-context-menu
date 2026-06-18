#!/bin/bash
# ask-ai-dolphin-run.sh — universal runner for launching opencode in Konsole
# Takes the query as $1, files as $2+
# Shows a header and streams the response through glow

# Clean exit on Ctrl+C (avoids Konsole's "Program error" message)
trap 'echo ""; exit 0' INT

QUERY="$1"
shift

# Filter out empty arguments
FILES=()
for f in "$@"; do
    [ -n "$f" ] && FILES+=("$f")
done

# --- Locale detection (same logic as dialog + install) ---
# Priority: ASK_AI_LOCALE env → $LANG → en_EN
DETECTED_LOCALE="en_EN"
case "${ASK_AI_LOCALE:-}" in
    ru_RU|ru) DETECTED_LOCALE="ru_RU" ;;
    en_EN|en) DETECTED_LOCALE="en_EN" ;;
    *)
        case "${LANG:-}" in
            ru_RU*|ru_UA*|be_BY*|uk_UA*) DETECTED_LOCALE="ru_RU" ;;
        esac
        ;;
esac
LOCALE="$DETECTED_LOCALE"

# Load locale file (check next to script or project root for source runs)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCALE_FILE="$SCRIPT_DIR/locales/$LOCALE"
[ -f "$LOCALE_FILE" ] || LOCALE_FILE="$(dirname "$SCRIPT_DIR")/locales/$LOCALE"
[ -f "$LOCALE_FILE" ] && source "$LOCALE_FILE"

# --- Localized strings (from locale file or inline defaults) ---
HDR_TITLE="${runner_hdr_title:-🤖  Ask AI about selected file(s)}"
LBL_FILES="${runner_lbl_files:-Selected files:}"
LBL_QUESTION="${runner_lbl_question:-Your question:}"
LBL_MODEL="${runner_lbl_model:-Model:}"
LBL_EFFORT="${runner_lbl_effort:-Effort:}"
LBL_MODE="${runner_lbl_mode:-Mode:}"
LBL_STREAMING="${runner_lbl_streaming:-⏳ Streaming AI response...}"
LBL_GLOW_MISSING="${runner_lbl_glow_missing:-glow not found -- output without formatting}"
LBL_ERR_OPENCODE="${runner_lbl_err_opencode:-Error: opencode not found in PATH}"
LBL_DONE="${runner_lbl_done:-✅ Done. Press Ctrl+C or Enter to close.}"
LBL_SAVED="${runner_lbl_saved:-💾 Saved to:}"
LBL_EXECUTING="${runner_lbl_executing:-▶️ Executing script...}"
LBL_SCRIPT_SAVED="${runner_lbl_script_saved:-📜 Script saved to:}"
LBL_SCRIPT_FAILED="${runner_lbl_script_failed:-⚠️ Script exited with an error}"
FALLBACK_QUERY="${runner_fallback_query:-Explain these files}"

# --- Defaults ---
if [ -z "$QUERY" ]; then
    QUERY="$FALLBACK_QUERY"
fi

# If no files provided — use the current directory
if [ ${#FILES[@]} -eq 0 ]; then
    FILES=("$PWD")
fi

# --- Theme detection ---
# Priority: ASK_AI_THEME env → COLORFGBG → light (default)
DETECTED_THEME="light"
# Case-insensitive comparison using ${var,,} (bash 4+)
ask_theme_lower="${ASK_AI_THEME,,}"
case "${ask_theme_lower:-}" in
    dark|d) DETECTED_THEME="dark" ;;
    light|l) DETECTED_THEME="light" ;;
    *)
        # COLORFGBG is set by Konsole: "fg;bg" color indices
        # 0=black, 7=white, 15=white(bright) — dark when bg is 0, 4, or 8
        # Extract bg value (everything after ';')
        colorfgbg_bg="${COLORFGBG#*;}"
        case "$colorfgbg_bg" in
            0|4|8) DETECTED_THEME="dark" ;;
        esac
        ;;
esac

# --- Colors ---
NC='\033[0m'
BOLD='\033[1m'

if [ "$DETECTED_THEME" = "dark" ]; then
    # Dark theme — lighter colors visible on dark background
    HDR_BLUE='\033[1;34m'
    FILE_CYAN='\033[1;36m'
    FILE_GREEN='\033[1;32m'
    LABEL_YELLOW='\033[1;33m'
else
    # Light theme — normal colors visible on light background
    HDR_BLUE='\033[0;34m'
    FILE_CYAN='\033[0;36m'
    FILE_GREEN='\033[0;32m'
    LABEL_YELLOW='\033[1;33m'
fi

# --- Header ---
echo -e "${BOLD}${HDR_BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${HDR_BLUE}║      ${HDR_TITLE}   ║${NC}"
echo -e "${BOLD}${HDR_BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}${LABEL_YELLOW}${LBL_FILES}${NC}"
for f in "${FILES[@]}"; do
    if [ -d "$f" ]; then
        echo -e "  ${FILE_CYAN}📁 $f${NC}"
    else
        SIZE=$(du -h "$f" 2>/dev/null | cut -f1)
        echo -e "  ${FILE_GREEN}📄 $f${NC}  ${BOLD}(${SIZE})${NC}"
    fi
done
echo ""
echo -e "${BOLD}${LBL_QUESTION}${NC}"
echo -e "  ${LABEL_YELLOW}$QUERY${NC}"
echo ""

# --- Build the prompt ---
PROMPT="I have these selected files/directories:
$(printf '%s\n' "${FILES[@]}")

My question about them: $QUERY"

# --- Check opencode ---
if ! command -v opencode &> /dev/null; then
    echo -e "${BOLD}${LBL_ERR_OPENCODE}${NC}"
    exit 1
fi

# --- Determine model, effort, and mode (from environment or default) ---
MODEL="${ASK_AI_MODEL:-opencode/deepseek-v4-flash-free}"
echo -e "${BOLD}${LBL_MODEL}${NC} ${FILE_CYAN}${MODEL}${NC}"

EXTRA_FLAGS=()
if [ -n "${ASK_AI_EFFORT:-}" ]; then
    EXTRA_FLAGS+=(--variant "$ASK_AI_EFFORT")
    echo -e "${BOLD}${LBL_EFFORT}${NC} ${FILE_CYAN}${ASK_AI_EFFORT}${NC}"
fi
if [ -n "${ASK_AI_MODE:-}" ]; then
    EXTRA_FLAGS+=(--agent "$ASK_AI_MODE")
    echo -e "${BOLD}${LBL_MODE}${NC} ${FILE_CYAN}${ASK_AI_MODE}${NC}"
fi
echo ""

# --- Prepare output file (if ASK_AI_SAVE_DIR is set) ---
TEMP_OUTPUT=$(mktemp)
trap 'rm -f "$TEMP_OUTPUT"' EXIT

SAVE_FILE=""
if [ -n "${ASK_AI_SAVE_DIR:-}" ]; then
    mkdir -p "$ASK_AI_SAVE_DIR"
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    # Generate a short slug from the query for readability
    QUERY_SLUG=$(echo "$QUERY" | python3 -c "
import sys, re
s = sys.stdin.read().strip().lower()
s = re.sub(r'[^a-zа-я0-9 ]', '', s).strip().replace(' ', '_')[:40]
print(s or 'result')
" 2>/dev/null) || QUERY_SLUG=$(echo "$QUERY" | tr ' ' '_' | head -c 40)
    [ -z "$QUERY_SLUG" ] && QUERY_SLUG="result"
    SAVE_FILE="$ASK_AI_SAVE_DIR/${QUERY_SLUG}-${TIMESTAMP}.md"
fi

# --- Stream ---
echo -e "${BOLD}${LBL_STREAMING}${NC}"
echo ""

if [ "${GLOW_DISABLED:-0}" = "1" ]; then
    # Raw mode (askr) — tee saves raw output
    opencode run --model "$MODEL" "${EXTRA_FLAGS[@]}" "$PROMPT" | tee "$TEMP_OUTPUT"
elif command -v glow &> /dev/null; then
    # Tee captures raw output BEFORE glow adds ANSI codes
    opencode run --model "$MODEL" "${EXTRA_FLAGS[@]}" "$PROMPT" | tee "$TEMP_OUTPUT" | glow -
else
    echo -e "${LABEL_YELLOW}${LBL_GLOW_MISSING}${NC}"
    opencode run --model "$MODEL" "${EXTRA_FLAGS[@]}" "$PROMPT" | tee "$TEMP_OUTPUT"
fi

# --- Save output to file if requested ---
SCRIPT_FILE=""
if [ -n "$SAVE_FILE" ]; then
    cp "$TEMP_OUTPUT" "$SAVE_FILE"
fi

# --- Check if output is an executable script (starts with shebang) ---
FIRST_LINE=$(head -1 "$TEMP_OUTPUT" 2>/dev/null || true)
if [[ "$FIRST_LINE" == "#!"* ]]; then
    # Determine where to save the script
    if [ -n "$SAVE_FILE" ]; then
        SCRIPT_FILE="${SAVE_FILE%.md}.sh"
        cp "$TEMP_OUTPUT" "$SCRIPT_FILE"
    else
        # No SAVE_DIR — save next to first file or in current dir
        SCRIPT_DIR="${FILES[0]:-$PWD}"
        [ -f "$SCRIPT_DIR" ] && SCRIPT_DIR=$(dirname "$SCRIPT_DIR")
        TIMESTAMP=$(date +%Y%m%d-%H%M%S)
        SCRIPT_FILE="$SCRIPT_DIR/ask-ai-script-$TIMESTAMP.sh"
        cp "$TEMP_OUTPUT" "$SCRIPT_FILE"
    fi
    chmod +x "$SCRIPT_FILE"

    echo ""
    echo -e "${BOLD}${FILE_GREEN}${LBL_EXECUTING}${NC} ${FILE_CYAN}$SCRIPT_FILE${NC}"
    echo ""
    # Run from the directory of the first selected file (or current dir)
    RUN_DIR="${FILES[0]:-$PWD}"
    [ -f "$RUN_DIR" ] && RUN_DIR=$(dirname "$RUN_DIR")
    cd "$RUN_DIR" 2>/dev/null || true
    "$SCRIPT_FILE" 2>&1 || echo -e "${BOLD}${LABEL_YELLOW}${LBL_SCRIPT_FAILED}${NC}"
    echo ""
fi

echo ""
echo -e "${BOLD}${FILE_GREEN}${LBL_DONE}${NC}"
if [ -n "$SAVE_FILE" ]; then
    echo -e "${BOLD}${LABEL_YELLOW}${LBL_SAVED}${NC} ${FILE_CYAN}$SAVE_FILE${NC}"
fi
if [ -n "$SCRIPT_FILE" ]; then
    echo -e "${BOLD}${LABEL_YELLOW}${LBL_SCRIPT_SAVED}${NC} ${FILE_CYAN}$SCRIPT_FILE${NC}"
fi
echo -n ""
read -r 2>/dev/null || true
