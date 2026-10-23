#!/bin/bash
# ask-ai-dolphin-run.sh — universal runner for launching opencode in Konsole
# Takes the query as $1, files as $2+
# Shows a header and streams the response through glow

# Clean exit on Ctrl+C (avoids Konsole's "Program error" message)
trap 'echo ""; exit 0' INT

# Strict mode: fail fast on unset vars and errors; pipefail enabled locally around
# the opencode pipeline (see below) to preserve its exit status.
set -eu
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

# --- User config ---
# Konsole hands `-e cmd` to an already running instance, so a session started
# from the service menu inherits *that* process's environment, not the one the
# entry script exported. Without this, ASK_AI_MODEL / ASK_AI_SAVE_DIR / locale
# settings from ~/.ask_ai silently fell back to the defaults on the Dolphin
# path while the dialog showed the configured ones. The file is read in a
# subshell, so its functions and any output stay out of the runner, and only
# values that are not already in the environment are taken: an explicit
# `ASK_AI_MODEL=… ask "…"` still wins over the file.
if [ -f "$HOME/.ask_ai" ]; then
    while IFS='=' read -r _cfg_key _cfg_val; do
        case "$_cfg_key" in
            ASK_AI_*|GLOW_DISABLED) ;;
            *) continue ;;
        esac
        [ -n "${!_cfg_key+set}" ] && continue
        printf -v "$_cfg_key" '%s' "$_cfg_val"
        # shellcheck disable=SC2163  # the variable name itself is dynamic
        export "$_cfg_key"
    done < <(bash -c 'set -a; . "$HOME/.ask_ai" >/dev/null 2>&1; exec env' 2>/dev/null)
fi

# --- Locale ---
if declare -F ask_ai_detect_locale &>/dev/null; then
    LOCALE=$(ask_ai_detect_locale)
    ask_ai_load_locale "$INSTALL_DIR" "$LOCALE" || true
else
    # Fallback if common.sh missing (partial install)
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

# --- Localized strings ---
HDR_TITLE="${runner_hdr_title:-Ask AI about selected file(s)}"
LBL_FILES="${runner_lbl_files:-Selected files:}"
LBL_QUESTION="${runner_lbl_question:-Your question:}"
LBL_MODEL="${runner_lbl_model:-Model:}"
LBL_EFFORT="${runner_lbl_effort:-Effort:}"
LBL_EFFORT_SKIPPED="${runner_lbl_effort_skipped:-Effort '%s' skipped: model %s has no such variant}"
LBL_EFFORT_UNKNOWN="${runner_lbl_effort_unknown:-Effort '%s' skipped: could not verify variant support}"
LBL_EFFORT_PINNED="${runner_lbl_effort_pinned:-Effort '%s' skipped: %s already specifies a variant}"
LBL_MODE="${runner_lbl_mode:-Mode:}"
LBL_STREAMING="${runner_lbl_streaming:-Streaming AI response...}"
LBL_GLOW_MISSING="${runner_lbl_glow_missing:-glow not found -- output without formatting}"
LBL_ERR_OPENCODE="${runner_lbl_err_opencode:-Error: opencode not found in PATH}"
LBL_ERR_OPENCODE_V2="${runner_lbl_err_opencode_v2:-Error: opencode v2 not found — only an older version is in PATH. Install: https://opencode.ai/v2/install}"
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
LBL_DONE_INLINE="${runner_lbl_done_inline:-✅ Done.}"
LBL_HARNESS="${runner_lbl_harness:-Harness:}"
LBL_MODEL_DEFAULT="${runner_lbl_model_default:-agent default}"
LBL_AGENT_FAILED="${runner_lbl_agent_failed:-agent exited with an error (code %s)}"
LBL_AGENT_AUTH="${runner_lbl_agent_auth:-The agent requires authentication — run its login command in a terminal, then retry.}"
LBL_ACP_UNAVAILABLE="${runner_lbl_acp_unavailable:-ACP requested (ASK_AI_ACP=1) but the client or python3 is missing — using the opencode CLI.}"
LBL_UNKNOWN_AGENT="${runner_lbl_unknown_agent:-Unknown ASK_AI_AGENT '%s' — falling back to opencode.}"
LBL_AGENT_MISSING="${runner_lbl_agent_missing:-Agent '%s' not found. Install: %s}"
FALLBACK_QUERY="${runner_fallback_query:-Explain these files}"

# Attachment limits
MAX_ATTACH_BYTES="${ASK_AI_MAX_ATTACH_BYTES:-204800}"  # 200 KiB
MAX_ATTACH_FILES="${ASK_AI_MAX_ATTACH_FILES:-20}"

# A typo in ~/.ask_ai must not silently disable attachments: with a non-numeric
# value every `[ "$size" -le "$limit" ]` fails and all files are skipped.
case "$MAX_ATTACH_BYTES" in ''|*[!0-9]*) MAX_ATTACH_BYTES=204800 ;; esac
case "$MAX_ATTACH_FILES" in ''|*[!0-9]*) MAX_ATTACH_FILES=20 ;; esac

# --- Defaults ---
if [ -z "$QUERY" ]; then
    QUERY="$FALLBACK_QUERY"
fi

if [ ${#FILES[@]} -eq 0 ]; then
    FILES=("$PWD")
fi

# --- Theme detection ---
# ASK_AI_THEME / COLORFGBG are optional: expand with a default, otherwise
# `set -u` aborts the runner before any output (pre-existing crash).
DETECTED_THEME="light"
ask_theme_lower="${ASK_AI_THEME:-}"
ask_theme_lower="${ask_theme_lower,,}"
case "$ask_theme_lower" in
    dark|d) DETECTED_THEME="dark" ;;
    light|l) DETECTED_THEME="light" ;;
    *)
        colorfgbg_bg="${COLORFGBG:-}"
        colorfgbg_bg="${colorfgbg_bg#*;}"
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
        # A path starting with "-" would be parsed by opencode as a flag.
        attach_path="$f"
        case "$attach_path" in
            -*) attach_path="$PWD/$attach_path" ;;
        esac
        ATTACH_FLAGS+=(-f "$attach_path")
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

# --- Harness selection ---
# ACP is the default: it drives any agent that speaks the Agent Client Protocol
# (`opencode acp`, `gemini --experimental-acp`, `claude-agent-acp`,
# `codex-acp`, …) and ASK_AI_AGENT_CMD overrides the command.
#   ASK_AI_HARNESS=cli        legacy `opencode run` path
#   ASK_AI_HARNESS=acp        force ACP (the default)
#   ASK_AI_ACP=0 / =1         pre-1.4 alias for the two values above
ACP_MODE=0
ACP_CLIENT="$INSTALL_DIR/ask-ai-acp-client.py"
[ -f "$ACP_CLIENT" ] || ACP_CLIENT="$(dirname "$INSTALL_DIR")/src/ask-ai-acp-client.py"
WANT_ACP=1
case "${ASK_AI_HARNESS:-}" in
    cli|opencode|legacy) WANT_ACP=0 ;;
    acp) WANT_ACP=1 ;;
    "")
        case "${ASK_AI_ACP:-}" in
            0|no|false|off) WANT_ACP=0 ;;
        esac
        ;;
esac
if [ "$WANT_ACP" -eq 1 ]; then
    if [ -f "$ACP_CLIENT" ] && command -v python3 &>/dev/null; then
        ACP_MODE=1
    else
        echo -e "${BOLD}${LABEL_YELLOW}${LBL_ACP_UNAVAILABLE}${NC}"
    fi
fi

# --- Which ACP agent ---
# ASK_AI_AGENT=opencode|gemini|claude|codex|qwen|goose|copilot resolves through
# the registry in ask-ai-common.sh; ASK_AI_AGENT_CMD wins over it and accepts
# any command line, so a harness missing from the table still works.
AGENT_ID="${ASK_AI_AGENT:-opencode}"
AGENT_CMD="${ASK_AI_AGENT_CMD:-}"
if [ "$ACP_MODE" -eq 1 ] && [ -z "$AGENT_CMD" ]; then
    if declare -F ask_ai_agent_command &>/dev/null; then
        AGENT_CMD=$(ask_ai_agent_command "$AGENT_ID" 2>/dev/null || true)
    fi
    if [ -z "$AGENT_CMD" ]; then
        # shellcheck disable=SC2059
        printf "${BOLD}${LABEL_YELLOW}${LBL_UNKNOWN_AGENT}${NC}\n" "$AGENT_ID"
        AGENT_ID="opencode"
        AGENT_CMD="opencode acp"
    fi
fi
if [ "$ACP_MODE" -eq 1 ]; then
    AGENT_BIN="${AGENT_CMD%% *}"
    if ! command -v "$AGENT_BIN" &>/dev/null; then
        AGENT_HINT=""
        if declare -F ask_ai_agent_install_hint &>/dev/null; then
            AGENT_HINT=$(ask_ai_agent_install_hint "$AGENT_ID" 2>/dev/null || true)
        fi
        # shellcheck disable=SC2059
        printf "${BOLD}${ERR_RED}${LBL_AGENT_MISSING}${NC}\n" "$AGENT_BIN" "${AGENT_HINT:-$AGENT_ID}"
        exit 1
    fi
    # Exported, so the client (and the trace) see the resolved command even
    # when it came from the registry rather than the environment.
    export ASK_AI_AGENT_CMD="$AGENT_CMD"
fi

# --- Check opencode (v2 required, CLI path only) ---
# The GUI session PATH may resolve `opencode` to a system v1 build; v1 breaks
# `run -f` (it swallows the prompt and dies with "File not found: <prompt>").
# ask_ai_opencode_bin picks the first v2 binary (PATH → ~/.opencode/bin →
# ~/.local/bin); without common.sh fall back to whatever is in PATH.
OPENCODE_BIN=""
if [ "$ACP_MODE" -eq 0 ]; then
    if declare -F ask_ai_opencode_bin &>/dev/null; then
        OPENCODE_BIN=$(ask_ai_opencode_bin 2>/dev/null || true)
    else
        OPENCODE_BIN=$(command -v opencode 2>/dev/null || true)
    fi
    if [ -z "$OPENCODE_BIN" ]; then
        if command -v opencode &>/dev/null; then
            echo -e "${BOLD}${ERR_RED}${LBL_ERR_OPENCODE_V2}${NC}"
        else
            echo -e "${BOLD}${ERR_RED}${LBL_ERR_OPENCODE}${NC}"
        fi
        exit 1
    fi
fi

# ACP: an empty ASK_AI_MODEL means "whatever the agent is configured with",
# and the CLI-style default below is not a valid ACP model id.
ACP_MODEL_VALUE="${ASK_AI_MODEL:-}"
if [ "$ACP_MODE" -eq 1 ] && [ -z "$ACP_MODEL_VALUE" ]; then
    MODEL="$LBL_MODEL_DEFAULT"
else
    MODEL="${ASK_AI_MODEL:-opencode/mimo-v2.6-flash-free}"
fi

# opencode v2: always pass an explicit agent. Without a --agent flag the model
# is taken from the user's opencode config (default_agent), and v2 then appends
# a spurious second assistant turn to `opencode run` output — it pollutes the
# terminal and every saved .md. An explicit --agent suppresses that turn.
# `plan` keeps the plugin read-only: the model answers and plans, but never
# edits the selected files. Set ASK_AI_MODE=build to let it modify them.
MODE="${ASK_AI_MODE:-plan}"

# opencode v2: effort is a model variant (provider/model#variant), not --variant.
# Only applied when the model actually declares it, so the query never fails.
EXTRA_FLAGS=()
if [ "$ACP_MODE" -eq 1 ]; then
    # The ACP client maps the effort onto the agent's own config option and
    # warns when the agent has none, so no model catalog is queried here.
    EFFORT_LINE=""
    [ -n "${ASK_AI_EFFORT:-}" ] && EFFORT_LINE=$'\n'"${BOLD}${LBL_EFFORT}${NC} ${FILE_CYAN}${ASK_AI_EFFORT}${NC}"
elif [ -n "${ASK_AI_EFFORT:-}" ]; then
    EFFORT_RC=0
    _effort_model=""
    if declare -F ask_ai_apply_effort &>/dev/null; then
        _effort_model=$(ask_ai_apply_effort "$MODEL" "$ASK_AI_EFFORT") || EFFORT_RC=$?
    else
        EFFORT_RC=2
    fi
    case "$EFFORT_RC" in
        0)
            MODEL="$_effort_model"
            EFFORT_LINE=$'\n'"${BOLD}${LBL_EFFORT}${NC} ${FILE_CYAN}${ASK_AI_EFFORT}${NC}"
            ;;
        1)
            # shellcheck disable=SC2059
            EFFORT_LINE=$'\n'"$(printf "${LABEL_YELLOW}${LBL_EFFORT_SKIPPED}${NC}" "$ASK_AI_EFFORT" "$MODEL")"
            ;;
        3)
            # shellcheck disable=SC2059
            EFFORT_LINE=$'\n'"$(printf "${LABEL_YELLOW}${LBL_EFFORT_PINNED}${NC}" "$ASK_AI_EFFORT" "$MODEL")"
            ;;
        *)
            # shellcheck disable=SC2059
            EFFORT_LINE=$'\n'"$(printf "${LABEL_YELLOW}${LBL_EFFORT_UNKNOWN}${NC}" "$ASK_AI_EFFORT")"
            ;;
    esac
fi

if [ "$ACP_MODE" -eq 1 ]; then
    AGENT_LABEL="${ASK_AI_AGENT:-${AGENT_CMD%% *}}"
fi
EXTRA_FLAGS+=(--agent "$MODE")

# --- Header (no fixed box — emoji / CJK break column math) ---
# One function, because the header is printed twice when the answer is rendered:
# inside the alternate screen next to the live stream, and again on the normal
# screen together with the finished answer.
print_run_header() {
    echo -e "${BOLD}${HDR_BLUE}════════════════════════════════════════${NC}"
    echo -e "${BOLD}${HDR_BLUE}  ${HDR_TITLE}${NC}"
    echo -e "${BOLD}${HDR_BLUE}════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BOLD}${LABEL_YELLOW}${LBL_FILES}${NC}"
    for f in "${FILES[@]}"; do
        if [ -d "$f" ]; then
            # printf '%s' keeps escape sequences in paths verbatim (no ANSI injection)
            printf '  %b📁 %s%b\n' "$FILE_CYAN" "$f" "$NC"
        else
            SIZE=$(du -h -- "$f" 2>/dev/null | cut -f1 || true)
            printf '  %b📄 %s%b  %b(%s)%b\n' "$FILE_GREEN" "$f" "$NC" "$BOLD" "$SIZE" "$NC"
        fi
    done
    echo ""
    echo -e "${BOLD}${LBL_QUESTION}${NC}"
    printf '  %b%s%b\n' "$LABEL_YELLOW" "$QUERY" "$NC"
    echo ""
    if [ "$ACP_MODE" -eq 1 ]; then
        echo -e "${BOLD}${LBL_HARNESS}${NC} ${FILE_CYAN}ACP${NC} (${AGENT_LABEL}) ${BOLD}${LBL_MODEL}${NC} ${FILE_CYAN}${MODEL}${NC}"
    else
        echo -e "${BOLD}${LBL_MODEL}${NC} ${FILE_CYAN}${MODEL}${NC}"
    fi
    if [ -n "${EFFORT_LINE:-}" ]; then
        echo -e "$EFFORT_LINE"
    fi
    echo -e "${BOLD}${LBL_MODE}${NC} ${FILE_CYAN}${MODE}${NC}"
    if [ ${#ATTACHED_NAMES[@]} -gt 0 ]; then
        echo -e "${BOLD}${LBL_ATTACHED}${NC} ${FILE_CYAN}${#ATTACHED_NAMES[@]}${NC}"
        for a in "${ATTACHED_NAMES[@]}"; do
            printf '  %b+ %s%b\n' "$FILE_GREEN" "$a" "$NC"
        done
    fi
    if [ ${#SKIPPED_NAMES[@]} -gt 0 ]; then
        echo -e "${BOLD}${LBL_SKIPPED_ATTACH}${NC}"
        for s in "${SKIPPED_NAMES[@]}"; do
            printf '  %b- %s%b\n' "$LABEL_YELLOW" "$s" "$NC"
        done
    fi
    echo ""
}

echo ""

# --- Temp output + cleanup ---
TEMP_OUTPUT=$(mktemp)
# Preserve INT trap behavior; also clean temp on exit (incl. extracted script).
# Leaving the alternate screen (only when it was entered) keeps a Ctrl+C or any
# early exit from stranding the terminal on a screen that goes away with the
# process.
RENDER_ANSWER=0
leave_alt_screen() {
    if [ "$RENDER_ANSWER" -eq 1 ]; then
        printf '\033[?1049l'
    fi
}
trap 'leave_alt_screen; rm -f "$TEMP_OUTPUT" "${TEMP_OUTPUT}.script" "${TEMP_OUTPUT}.render"; echo ""; exit 0' INT
trap 'leave_alt_screen; rm -f "$TEMP_OUTPUT" "${TEMP_OUTPUT}.script" "${TEMP_OUTPUT}.render"' EXIT

SAVE_FILE=""
if [ -n "${ASK_AI_SAVE_DIR:-}" ]; then
    mkdir -p "$ASK_AI_SAVE_DIR"
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    QUERY_SLUG=$(printf '%s' "$QUERY" | python3 -c "
import sys, re
s = sys.stdin.read().strip().lower()
s = re.sub(r'[^a-zа-я0-9 ]', '', s).strip().replace(' ', '_')[:40]
print(s or 'result')
" 2>/dev/null) || QUERY_SLUG=$(printf '%s' "$QUERY" | tr -cd 'a-zA-Zа-яА-Я0-9 _-' | tr ' ' '_' | head -c 40)
    [ -z "$QUERY_SLUG" ] && QUERY_SLUG="result"
    SAVE_FILE="$ASK_AI_SAVE_DIR/${QUERY_SLUG}-${TIMESTAMP}.md"
fi

# --- Ask the agent ---
# Both paths print the answer as Markdown on stdout, so the surrounding
# pipeline (save, script detection, clipboard) stays exactly the same.
ACP_CWD=""
run_agent() {
    if [ "$ACP_MODE" -eq 1 ]; then
        ACP_ARGS=("$ACP_CLIENT" --cwd "$ACP_CWD" --mode "$MODE"
            --permission "${ASK_AI_PERMISSION:-allow-read}")
        # A selected directory has no file to attach; its non-recursive listing
        # goes along as a text block, the way the CLI prompt carries it.
        if [ -n "$DIR_CONTEXT" ]; then
            ACP_ARGS+=(--context "$DIR_CONTEXT")
        fi
        if [ -n "$ACP_MODEL_VALUE" ]; then
            ACP_ARGS+=(--model "$ACP_MODEL_VALUE")
        fi
        if [ -n "${ASK_AI_EFFORT:-}" ]; then
            ACP_ARGS+=(--effort "$ASK_AI_EFFORT")
        fi
        if [ "${ASK_AI_ACP_VERBOSE:-0}" = "1" ]; then
            ACP_ARGS+=(--verbose)
        fi
        if [ "${ASK_AI_ACP_REUSE:-0}" = "1" ]; then
            ACP_ARGS+=(--reuse-session)
        fi
        python3 "${ACP_ARGS[@]}" "$QUERY" "${ATTACHED_NAMES[@]}"
    else
        "$OPENCODE_BIN" run --model "$MODEL" "${EXTRA_FLAGS[@]}" "${ATTACH_FLAGS[@]}" "$PROMPT"
    fi
}

if [ "$ACP_MODE" -eq 1 ]; then
    ACP_CWD="${FILES[0]:-$PWD}"
    if [ -f "$ACP_CWD" ]; then
        ACP_CWD=$(dirname -- "$ACP_CWD")
    fi
fi

# pipefail keeps an agent failure visible instead of letting a formatting stage
# swallow it.
#
# ACP answers arrive token by token and must reach the terminal as they are
# produced, so that path prints raw Markdown: glow can only render a finished
# document, and piping the stream through it held the whole answer back until
# the turn ended. tee writes each chunk straight through, so the .md file and
# the script detection get the answer without buffering it on the way to the
# screen. The legacy CLI path keeps glow.
#
# When the answer will be rendered at the end, the stream runs on the alternate
# screen: a terminal cannot erase lines that have already scrolled into the
# scrollback, so replacing the streamed text in place only ever worked for
# answers shorter than the window. Leaving the alternate screen throws the
# stream away in one step, and the formatted answer is printed under the header
# on the normal screen — whatever its length.
RENDER_ANSWER=0
if [ "$ACP_MODE" -eq 1 ] && [ "${GLOW_DISABLED:-0}" != "1" ] \
    && [ -t 1 ] && command -v glow &>/dev/null; then
    RENDER_ANSWER=1
    printf '\033[?1049h'
fi

# Inside the alternate screen when it is used, so the window shows what is being
# asked while the agent works; neither this header nor the stream survives the
# rendering.
print_run_header
echo -e "${BOLD}${LBL_STREAMING}${NC}"
echo ""

set -o pipefail
OPENCODE_STATUS=0
if [ "$ACP_MODE" -eq 1 ] || [ "${GLOW_DISABLED:-0}" = "1" ]; then
    run_agent | tee "$TEMP_OUTPUT" || OPENCODE_STATUS=$?
elif command -v glow &>/dev/null; then
    run_agent | tee "$TEMP_OUTPUT" | glow - || OPENCODE_STATUS=$?
else
    echo -e "${LABEL_YELLOW}${LBL_GLOW_MISSING}${NC}"
    run_agent | tee "$TEMP_OUTPUT" || OPENCODE_STATUS=$?
fi
set +o pipefail

# --- Replace the streamed answer with a rendered one ---
if [ "$RENDER_ANSWER" -eq 1 ]; then
    # glow probes the terminal for its colours and cursor position and waits for
    # the reply as long as its stdout is a TTY — and it reads that reply from
    # stdin, which here is the answer file. The window sat blank for seconds.
    # Rendering into a file keeps glow off the terminal entirely; the explicit
    # style and width stand in for what the probe would have detected.
    GCOLS=$(tput cols 2>/dev/null || true)
    case "${GCOLS:-}" in
        ''|*[!0-9]*) GCOLS=80 ;;
    esac
    RENDERED=0
    if [ "$OPENCODE_STATUS" -eq 0 ] \
        && glow -s "$DETECTED_THEME" -w "$GCOLS" - <"$TEMP_OUTPUT" >"${TEMP_OUTPUT}.render" 2>/dev/null; then
        RENDERED=1
    fi
    printf '\033[?1049l'
    RENDER_ANSWER=0  # the traps must not leave the alternate screen again
    print_run_header
    if [ "$RENDERED" -eq 1 ]; then
        cat -- "${TEMP_OUTPUT}.render"
    else
        # Nothing to render (failed turn or failing glow): the partial answer
        # must not disappear together with the alternate screen.
        cat -- "$TEMP_OUTPUT"
    fi
fi

if [ "$OPENCODE_STATUS" -ne 0 ]; then
    if [ "$ACP_MODE" -eq 1 ] && [ "$OPENCODE_STATUS" -eq 3 ]; then
        echo -e "${BOLD}${ERR_RED}${LBL_AGENT_AUTH}${NC}"
    elif [ "$ACP_MODE" -eq 1 ]; then
        # shellcheck disable=SC2059
        printf "${BOLD}${ERR_RED}${LBL_AGENT_FAILED}${NC}\n" "$OPENCODE_STATUS"
    else
        # shellcheck disable=SC2059
        printf "${BOLD}${ERR_RED}${LBL_OPENCODE_FAILED}${NC}\n" "$OPENCODE_STATUS"
    fi
fi

# --- Save markdown output ---
SCRIPT_FILE=""
if [ -n "$SAVE_FILE" ]; then
    if [ "$OPENCODE_STATUS" -eq 0 ]; then
        cp "$TEMP_OUTPUT" "$SAVE_FILE" || SAVE_FILE=""
    else
        # A failed run leaves a partial answer: it must not look like a saved one.
        SAVE_FILE=""
    fi
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

# --- Shebang / script detection (opencode v2 output shapes) ---
# Raw shebang on the first non-empty line → the whole response is a script.
# Otherwise scan the response for the first fenced block whose first non-empty
# line is a shebang: opencode v2 (plan-style answers) often starts with prose
# before the code, and may add commentary after it. Only that block is
# extracted into the .sh — the full response stays in the .md.
SCRIPT_SOURCE="$TEMP_OUTPUT"
EXTRACTED="${TEMP_OUTPUT}.script"
FIRST_CONTENT=""
while IFS= read -r _line || [ -n "$_line" ]; do
    [ -z "$_line" ] && continue
    FIRST_CONTENT="$_line"
    break
done < "$TEMP_OUTPUT"

IS_SCRIPT=0
if [[ "$FIRST_CONTENT" == "#!"* ]]; then
    IS_SCRIPT=1
else
    # Detection and extraction are one step: a script is reported only when
    # the block body was actually written (no half-extracted .sh files).
    if python3 - "$TEMP_OUTPUT" "$EXTRACTED" <<'PY' 2>/dev/null
import sys

src, dst = sys.argv[1], sys.argv[2]
with open(src, encoding="utf-8", errors="replace") as fh:
    lines = fh.read().splitlines()

i = 0
while i < len(lines):
    if lines[i].lstrip().startswith("```"):
        # opening fence → scan to the closing fence
        j = i + 1
        while j < len(lines) and not lines[j].lstrip().startswith("```"):
            j += 1
        body = lines[i + 1:j]
        first = next((ln for ln in body if ln.strip()), "")
        if first.startswith("#!"):
            with open(dst, "w", encoding="utf-8") as out:
                out.write("\n".join(body).rstrip("\n") + "\n")
            sys.exit(0)
        i = j + 1  # no shebang in this block → keep looking
        continue
    i += 1
sys.exit(1)
PY
    then
        IS_SCRIPT=1
        SCRIPT_SOURCE="$EXTRACTED"
    fi
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
# The "press Enter to close" hint only makes sense in the terminal window the
# service menu opened; from `ask` / `askr` the prompt must come back at once.
if [ "${ASK_AI_PAUSE:-0}" = "1" ]; then
    DONE_LABEL="$LBL_DONE"
else
    DONE_LABEL="$LBL_DONE_INLINE"
fi
if [ "$OPENCODE_STATUS" -eq 0 ]; then
    echo -e "${BOLD}${FILE_GREEN}${DONE_LABEL}${NC}"
else
    echo -e "${BOLD}${ERR_RED}${DONE_LABEL}${NC}"
fi
if [ -n "$SAVE_FILE" ]; then
    echo -e "${BOLD}${LABEL_YELLOW}${LBL_SAVED}${NC} ${FILE_CYAN}$SAVE_FILE${NC}"
fi
echo -n ""
if [ "${ASK_AI_PAUSE:-0}" = "1" ]; then
    read -r 2>/dev/null || true
fi
