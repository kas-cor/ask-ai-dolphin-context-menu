#!/bin/bash
# ask-ai-dolphin-run.sh — universal runner for launching opencode in Konsole
# Takes the query as $1, files as $2+
# Shows a header and streams the response through glow

# Clean exit on Ctrl+C (avoids Konsole's "Program error" message)
trap 'echo ""; exit 0' INT

QUERY="${1:-}"
if [ "$#" -gt 0 ]; then
    shift
fi

# Filter out empty arguments
FILES=()
for f in "$@"; do
    [ -n "$f" ] && FILES+=("$f")
done

# --- Install dir + shared helpers ---
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
    # Fallback if common.sh missing (partial install)
    LOCALE="en_EN"
    case "${ASK_AI_LOCALE:-}" in ru_RU|ru) LOCALE="ru_RU" ;; esac
    case "${LANG:-}" in ru_RU*|ru_UA*|be_BY*|uk_UA*) LOCALE="ru_RU" ;; esac
    [ -f "$INSTALL_DIR/locales/$LOCALE" ] && source "$INSTALL_DIR/locales/$LOCALE"
fi

# --- Localized strings ---
HDR_TITLE="${runner_hdr_title:-Ask AI about selected file(s)}"
LBL_FILES="${runner_lbl_files:-Selected files:}"
LBL_QUESTION="${runner_lbl_question:-Your question:}"
LBL_MODEL="${runner_lbl_model:-Model:}"
LBL_EFFORT="${runner_lbl_effort:-Effort:}"
LBL_MODE="${runner_lbl_mode:-Mode:}"
LBL_STREAMING="${runner_lbl_streaming:-Streaming AI response...}"
LBL_GLOW_MISSING="${runner_lbl_glow_missing:-glow not found -- output without formatting}"
LBL_ERR_OPENCODE="${runner_lbl_err_opencode:-Error: opencode not found in PATH}"
LBL_DONE="${runner_lbl_done:-Done. Press Ctrl+C or Enter to close.}"
LBL_SAVED="${runner_lbl_saved:-Saved to:}"
LBL_EXECUTING="${runner_lbl_executing:-Executing script...}"
LBL_SCRIPT_SAVED="${runner_lbl_script_saved:-Script saved to:}"
LBL_SCRIPT_FAILED="${runner_lbl_script_failed:-Script exited with an error}"
LBL_RUN_CONFIRM="${runner_lbl_run_confirm:-Run this script? [y/N] }"
LBL_SCRIPT_SKIPPED="${runner_lbl_script_skipped:-Script not executed (skipped).}"
LBL_OPENCODE_FAILED="${runner_lbl_opencode_failed:-opencode exited with an error (code %s)}"
LBL_ATTACHED="${runner_lbl_attached:-Attached files:}"
LBL_SKIPPED_ATTACH="${runner_lbl_skipped_attach:-Skipped (binary/large/dir):}"
LBL_CLIPBOARD="${runner_lbl_clipboard:-Copied response to clipboard.}"
FALLBACK_QUERY="${runner_fallback_query:-Explain these files}"

# Attachment limits
MAX_ATTACH_BYTES="${ASK_AI_MAX_ATTACH_BYTES:-204800}"  # 200 KiB
MAX_ATTACH_FILES="${ASK_AI_MAX_ATTACH_FILES:-20}"

# --- Defaults ---
if [ -z "$QUERY" ]; then
    QUERY="$FALLBACK_QUERY"
fi

if [ ${#FILES[@]} -eq 0 ]; then
    FILES=("$PWD")
fi

# --- Theme detection ---
DETECTED_THEME="light"
ask_theme_lower="${ASK_AI_THEME,,}"
case "${ask_theme_lower:-}" in
    dark|d) DETECTED_THEME="dark" ;;
    light|l) DETECTED_THEME="light" ;;
    *)
        colorfgbg_bg="${COLORFGBG#*;}"
        case "$colorfgbg_bg" in
            0|4|8) DETECTED_THEME="dark" ;;
        esac
        ;;
esac

NC='\033[0m'
BOLD='\033[1m'
if [ "$DETECTED_THEME" = "dark" ]; then
    HDR_BLUE='\033[1;34m'
    FILE_CYAN='\033[1;36m'
    FILE_GREEN='\033[1;32m'
    LABEL_YELLOW='\033[1;33m'
    ERR_RED='\033[1;31m'
else
    HDR_BLUE='\033[0;34m'
    FILE_CYAN='\033[0;36m'
    FILE_GREEN='\033[0;32m'
    LABEL_YELLOW='\033[1;33m'
    ERR_RED='\033[0;31m'
fi

# --- Header (no fixed box — emoji / CJK break column math) ---
echo -e "${BOLD}${HDR_BLUE}════════════════════════════════════════${NC}"
echo -e "${BOLD}${HDR_BLUE}  ${HDR_TITLE}${NC}"
echo -e "${BOLD}${HDR_BLUE}════════════════════════════════════════${NC}"
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

# --- Build file attachments (-f) and prompt context ---
ATTACH_FLAGS=()
ATTACHED_NAMES=()
SKIPPED_NAMES=()
ATTACH_COUNT=0
DIR_CONTEXT=""

for f in "${FILES[@]}"; do
    if [ -d "$f" ]; then
        SKIPPED_NAMES+=("$f (dir)")
        if declare -F ask_ai_dir_listing &>/dev/null; then
            DIR_CONTEXT+="Directory listing of $f:"$'\n'
            DIR_CONTEXT+=$(ask_ai_dir_listing "$f")$'\n'
        fi
        continue
    fi
    if [ ! -f "$f" ]; then
        SKIPPED_NAMES+=("$f (missing)")
        continue
    fi
    size_b=0
    if declare -F ask_ai_file_size &>/dev/null; then
        size_b=$(ask_ai_file_size "$f")
    else
        size_b=$(wc -c < "$f" 2>/dev/null | tr -d ' ' || echo 0)
    fi
    is_text=0
    if declare -F ask_ai_is_text_file &>/dev/null; then
        ask_ai_is_text_file "$f" && is_text=1
    else
        is_text=1
    fi
    if [ "$is_text" -eq 1 ] && [ "$size_b" -le "$MAX_ATTACH_BYTES" ] && [ "$ATTACH_COUNT" -lt "$MAX_ATTACH_FILES" ]; then
        ATTACH_FLAGS+=(-f "$f")
        ATTACHED_NAMES+=("$f")
        ATTACH_COUNT=$((ATTACH_COUNT + 1))
    else
        reason="large/binary"
        [ "$is_text" -eq 0 ] && reason="binary"
        [ "$size_b" -gt "$MAX_ATTACH_BYTES" ] && reason="large"
        [ "$ATTACH_COUNT" -ge "$MAX_ATTACH_FILES" ] && reason="limit"
        SKIPPED_NAMES+=("$f ($reason)")
    fi
done

PROMPT="I have these selected files/directories:
$(printf '%s\n' "${FILES[@]}")
"
if [ -n "$DIR_CONTEXT" ]; then
    PROMPT+="
Directory contents (non-recursive):
$DIR_CONTEXT
"
fi
PROMPT+="
My question about them: $QUERY"

# --- Check opencode ---
if ! command -v opencode &>/dev/null; then
    echo -e "${BOLD}${ERR_RED}${LBL_ERR_OPENCODE}${NC}"
    exit 1
fi

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
if [ ${#ATTACHED_NAMES[@]} -gt 0 ]; then
    echo -e "${BOLD}${LBL_ATTACHED}${NC} ${FILE_CYAN}${#ATTACHED_NAMES[@]}${NC}"
    for a in "${ATTACHED_NAMES[@]}"; do
        echo -e "  ${FILE_GREEN}+ $a${NC}"
    done
fi
if [ ${#SKIPPED_NAMES[@]} -gt 0 ]; then
    echo -e "${BOLD}${LBL_SKIPPED_ATTACH}${NC}"
    for s in "${SKIPPED_NAMES[@]}"; do
        echo -e "  ${LABEL_YELLOW}- $s${NC}"
    done
fi
echo ""

# --- Temp output + cleanup ---
TEMP_OUTPUT=$(mktemp)
# Preserve INT trap behavior; also clean temp on exit (incl. extracted script)
trap 'rm -f "$TEMP_OUTPUT" "${TEMP_OUTPUT}.script"; echo ""; exit 0' INT
trap 'rm -f "$TEMP_OUTPUT" "${TEMP_OUTPUT}.script"' EXIT

SAVE_FILE=""
if [ -n "${ASK_AI_SAVE_DIR:-}" ]; then
    mkdir -p "$ASK_AI_SAVE_DIR"
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    QUERY_SLUG=$(printf '%s' "$QUERY" | python3 -c "
import sys, re
s = sys.stdin.read().strip().lower()
s = re.sub(r'[^a-zа-я0-9 ]', '', s).strip().replace(' ', '_')[:40]
print(s or 'result')
" 2>/dev/null) || QUERY_SLUG=$(printf '%s' "$QUERY" | tr ' ' '_' | head -c 40)
    [ -z "$QUERY_SLUG" ] && QUERY_SLUG="result"
    SAVE_FILE="$ASK_AI_SAVE_DIR/${QUERY_SLUG}-${TIMESTAMP}.md"
fi

# --- Stream with pipefail so opencode failures are visible ---
echo -e "${BOLD}${LBL_STREAMING}${NC}"
echo ""

set -o pipefail
OPENCODE_STATUS=0
if [ "${GLOW_DISABLED:-0}" = "1" ]; then
    opencode run --model "$MODEL" "${EXTRA_FLAGS[@]}" "${ATTACH_FLAGS[@]}" "$PROMPT" | tee "$TEMP_OUTPUT" || OPENCODE_STATUS=$?
elif command -v glow &>/dev/null; then
    opencode run --model "$MODEL" "${EXTRA_FLAGS[@]}" "${ATTACH_FLAGS[@]}" "$PROMPT" | tee "$TEMP_OUTPUT" | glow - || OPENCODE_STATUS=$?
else
    echo -e "${LABEL_YELLOW}${LBL_GLOW_MISSING}${NC}"
    opencode run --model "$MODEL" "${EXTRA_FLAGS[@]}" "${ATTACH_FLAGS[@]}" "$PROMPT" | tee "$TEMP_OUTPUT" || OPENCODE_STATUS=$?
fi
set +o pipefail

if [ "$OPENCODE_STATUS" -ne 0 ]; then
    # shellcheck disable=SC2059
    printf "${BOLD}${ERR_RED}${LBL_OPENCODE_FAILED}${NC}\n" "$OPENCODE_STATUS"
fi

# --- Save markdown output ---
SCRIPT_FILE=""
if [ -n "$SAVE_FILE" ]; then
    cp "$TEMP_OUTPUT" "$SAVE_FILE"
fi

# Optional clipboard copy
if [ "${ASK_AI_CLIPBOARD:-0}" = "1" ] && [ -s "$TEMP_OUTPUT" ]; then
    if command -v wl-copy &>/dev/null; then
        wl-copy < "$TEMP_OUTPUT" && echo -e "${BOLD}${FILE_GREEN}${LBL_CLIPBOARD}${NC}"
    elif command -v xclip &>/dev/null; then
        xclip -selection clipboard < "$TEMP_OUTPUT" && echo -e "${BOLD}${FILE_GREEN}${LBL_CLIPBOARD}${NC}"
    elif command -v xsel &>/dev/null; then
        xsel --clipboard < "$TEMP_OUTPUT" && echo -e "${BOLD}${FILE_GREEN}${LBL_CLIPBOARD}${NC}"
    fi
fi

# --- Shebang / script detection ---
# First non-empty line; if markdown fence (```), peek next line for shebang.
SCRIPT_SOURCE="$TEMP_OUTPUT"
FIRST_CONTENT=""
while IFS= read -r _line || [ -n "$_line" ]; do
    [ -z "$_line" ] && continue
    FIRST_CONTENT="$_line"
    break
done < "$TEMP_OUTPUT"

IS_SCRIPT=0
if [[ "$FIRST_CONTENT" == "#!"* ]]; then
    IS_SCRIPT=1
elif [[ "$FIRST_CONTENT" == \`\`\`* ]]; then
    _seen_fence=0
    while IFS= read -r _line || [ -n "$_line" ]; do
        [ -z "$_line" ] && continue
        if [ "$_seen_fence" -eq 0 ]; then
            _seen_fence=1
            continue
        fi
        if [[ "$_line" == "#!"* ]]; then
            IS_SCRIPT=1
            EXTRACTED="${TEMP_OUTPUT}.script"
            # Extract the first fenced code block only (non-greedy .*?).
            # If the response has multiple code blocks, only the first one
            # becomes the saved/executed script. To keep the full response
            # (including all blocks), set ASK_AI_SAVE_DIR.
            if python3 -c "
import sys, re
text = open(sys.argv[1], encoding='utf-8', errors='replace').read()
# Non-greedy capture: first \`\`\` … \`\`\` pair
m = re.search(r'^\`\`\`[^\n]*\n(.*?)(?:\n\`\`\`|\Z)', text, re.S | re.M)
body = m.group(1) if m else text
open(sys.argv[2], 'w', encoding='utf-8').write(body if body.endswith('\n') else body + '\n')
" "$TEMP_OUTPUT" "$EXTRACTED" 2>/dev/null; then
                SCRIPT_SOURCE="$EXTRACTED"
            fi
        fi
        break
    done < "$TEMP_OUTPUT"
fi

if [ "$IS_SCRIPT" -eq 1 ]; then
    if [ -n "$SAVE_FILE" ]; then
        SCRIPT_FILE="${SAVE_FILE%.md}.sh"
        cp "$SCRIPT_SOURCE" "$SCRIPT_FILE"
    else
        SCRIPT_OUT_DIR="${FILES[0]:-$PWD}"
        [ -f "$SCRIPT_OUT_DIR" ] && SCRIPT_OUT_DIR=$(dirname "$SCRIPT_OUT_DIR")
        TIMESTAMP=$(date +%Y%m%d-%H%M%S)
        SCRIPT_FILE="$SCRIPT_OUT_DIR/ask-ai-script-$TIMESTAMP.sh"
        cp "$SCRIPT_SOURCE" "$SCRIPT_FILE"
    fi
    chmod +x "$SCRIPT_FILE"

    echo ""
    echo -e "${BOLD}${LABEL_YELLOW}${LBL_SCRIPT_SAVED}${NC} ${FILE_CYAN}$SCRIPT_FILE${NC}"

    # ASK_AI_AUTO_EXEC: 1/always → run; 0/never → skip; unset/prompt → ask
    _do_exec=0
    _auto_exec_lower="${ASK_AI_AUTO_EXEC:-prompt}"
    _auto_exec_lower="${_auto_exec_lower,,}"
    case "$_auto_exec_lower" in
        1|yes|true|always)
            _do_exec=1
            ;;
        0|no|false|never)
            # _do_exec is already 0 (default)
            ;;
        *)
            # Interactive confirm; default N on empty / non-tty
            if [ -t 0 ]; then
                echo -ne "${BOLD}${LBL_RUN_CONFIRM}${NC}"
                read -r _ans || _ans=""
                _ans_lower="${_ans,,}"
                case "$_ans_lower" in
                    y|yes) _do_exec=1 ;;
                esac
            else
                _do_exec=0
            fi
            ;;
    esac

    if [ "$_do_exec" -eq 1 ]; then
        echo ""
        echo -e "${BOLD}${FILE_GREEN}${LBL_EXECUTING}${NC} ${FILE_CYAN}$SCRIPT_FILE${NC}"
        echo ""
        RUN_DIR="${FILES[0]:-$PWD}"
        [ -f "$RUN_DIR" ] && RUN_DIR=$(dirname "$RUN_DIR")
        cd "$RUN_DIR" 2>/dev/null || true
        "$SCRIPT_FILE" 2>&1 || echo -e "${BOLD}${LABEL_YELLOW}${LBL_SCRIPT_FAILED}${NC}"
        echo ""
    else
        echo -e "${BOLD}${LABEL_YELLOW}${LBL_SCRIPT_SKIPPED}${NC}"
    fi
fi

echo ""
if [ "$OPENCODE_STATUS" -eq 0 ]; then
    echo -e "${BOLD}${FILE_GREEN}${LBL_DONE}${NC}"
else
    echo -e "${BOLD}${ERR_RED}${LBL_DONE}${NC}"
fi
if [ -n "$SAVE_FILE" ]; then
    echo -e "${BOLD}${LABEL_YELLOW}${LBL_SAVED}${NC} ${FILE_CYAN}$SAVE_FILE${NC}"
fi
echo -n ""
read -r 2>/dev/null || true
