#!/bin/bash
# install.sh — Install Ask AI into the Dolphin context menu
#
# Supports two modes:
#   1. Local:   ./install.sh [locale]  — from a cloned repository
#   2. One-liner:  curl -s https://raw.githubusercontent.com/.../install.sh | bash -s [locale]
#
# Locale: auto-detected from LANG, override with argument (ru_RU or en_EN).

set -euo pipefail

# --- Localization (bootstrap before common.sh is available) ---
# LANG first, then an explicit CLI argument (ru_RU, RU, ru-RU, en_EN, …).
# Unknown arguments keep the LANG-based detection instead of forcing English.
DETECTED_LOCALE="en_EN"
case "${LANG:-}" in
    ru_RU*|ru_UA*|be_BY*|uk_UA*) DETECTED_LOCALE="ru_RU" ;;
esac
if [ -n "${1:-}" ]; then
    _arg_lower="${1,,}"
    _arg_lower="${_arg_lower//-/_}"
    case "$_arg_lower" in
        ru_ru|ru) DETECTED_LOCALE="ru_RU" ;;
        en_en|en) DETECTED_LOCALE="en_EN" ;;
    esac
fi

LOCALE="$DETECTED_LOCALE"

# Get localized message
# Usage: msg "key" [args...]
msg() {
    local key="$1"
    shift

    local var_name="install_${key}"
    local str="${!var_name:-}"

    # Only the messages printed before the tarball is downloaded need an inline
    # fallback; everything else comes from locales/* once they are sourced.
    # (Keeping a full second copy here drifted from the locale files.)
    if [ -z "$str" ]; then
        case "$LOCALE" in
            ru_RU)
                case "$key" in
                    downloading)   str="📦 Загрузка проекта с GitHub..." ;;
                    curl_required) str="❌ Требуется curl. Установите: sudo pacman -S curl" ;;
                esac
                ;;
            *)
                case "$key" in
                    downloading)   str="📦 Downloading project from GitHub..." ;;
                    curl_required) str="❌ curl is required. Install: sudo pacman -S curl" ;;
                esac
                ;;
        esac
        [ -n "$str" ] || str="[msg_%s]"
    fi

    # Safe printf: format string is from our locale table, not user input
    # shellcheck disable=SC2059
    printf -- "$str\n" "$@"
}

e() { msg "$@"; }

REPO="kas-cor/ask-ai-dolphin-context-menu"
BRANCH="main"
GITHUB_TAR="https://github.com/$REPO/archive/$BRANCH.tar.gz"

# --- Detect mode: local or curl pipe ---
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo "")"

if [ -z "$SCRIPT_DIR" ] || [ ! -f "$SCRIPT_DIR/src/ask-ai-dolphin.sh" ]; then
    e downloading

    if ! command -v curl &>/dev/null; then
        e curl_required
        exit 1
    fi

    TMP_DIR="$(mktemp -d)"
    curl -sfL "$GITHUB_TAR" | tar xz -C "$TMP_DIR" --strip-components=1
    bash "$TMP_DIR/install.sh" "$@" && rc=0 || rc=$?
    rm -rf "$TMP_DIR"
    exit "$rc"
fi

# --- Local mode ---
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Prefer locale file + common helpers when available
if [ -f "$PROJECT_DIR/src/ask-ai-common.sh" ]; then
    # shellcheck disable=SC1091
    source "$PROJECT_DIR/src/ask-ai-common.sh"
    if declare -F ask_ai_detect_locale &>/dev/null && [ -z "${1:-}" ]; then
        LOCALE=$(ask_ai_detect_locale)
    fi
fi
# shellcheck disable=SC1090
[ -f "$PROJECT_DIR/locales/$LOCALE" ] && source "$PROJECT_DIR/locales/$LOCALE"

e checking_deps

MISSING=""
for cmd in python3 konsole opencode; do
    if ! command -v "$cmd" &>/dev/null; then
        # konsole is preferred but not strictly required if another terminal exists
        if [ "$cmd" = "konsole" ]; then
            if command -v kgx &>/dev/null || command -v gnome-terminal &>/dev/null \
                || command -v xterm &>/dev/null || [ -n "${TERMINAL:-}" ]; then
                continue
            fi
        fi
        MISSING="$MISSING  - $cmd\n"
    fi
done

if ! python3 -c "import PyQt5" 2>/dev/null && ! python3 -c "import PyQt6" 2>/dev/null; then
    MISSING="$MISSING  - python3-PyQt5 (or PyQt6)\n"
fi

if [ -n "$MISSING" ]; then
    echo ""
    e missing_deps
    echo -e "$MISSING"
    echo ""
    e install_them
    e opencode_url
    echo ""
    exit 1
fi

# A v1 opencode in PATH is detected only at run time (its `run -f` breaks the
# plugin), so warn during installation instead of failing after a right click.
if declare -F ask_ai_opencode_bin &>/dev/null && ! ask_ai_opencode_bin &>/dev/null; then
    e opencode_v2_warning
fi

if ! command -v glow &>/dev/null; then
    e glow_warning
    e glow_install
fi

echo ""

BIN_DIR="$HOME/.local/bin"
LOCALE_DIR="$BIN_DIR/locales"
SERVICEMENU_DIR="$HOME/.local/share/kio/servicemenus"
CONFIG_DIR="$HOME/.config"

e installing

mkdir -p "$BIN_DIR"
mkdir -p "$LOCALE_DIR"
mkdir -p "$SERVICEMENU_DIR"
mkdir -p "$CONFIG_DIR"

e copying_scripts "$BIN_DIR/"
install -m 755 "$PROJECT_DIR/src/ask-ai-common.sh"        "$BIN_DIR/ask-ai-common.sh"
install -m 755 "$PROJECT_DIR/src/ask-ai-dolphin.sh"       "$BIN_DIR/ask-ai-dolphin.sh"
install -m 755 "$PROJECT_DIR/src/ask-ai-dolphin-run.sh"   "$BIN_DIR/ask-ai-dolphin-run.sh"
install -m 755 "$PROJECT_DIR/src/ask-ai-dolphin-dialog.py" "$BIN_DIR/ask-ai-dolphin-dialog.py"
# ACP client (experimental, ASK_AI_ACP=1): optional, the CLI path works without it.
if [ -f "$PROJECT_DIR/src/ask-ai-acp-client.py" ]; then
    install -m 755 "$PROJECT_DIR/src/ask-ai-acp-client.py" "$BIN_DIR/ask-ai-acp-client.py"
fi

# Copy every locale shipped with this checkout: adding a language must not
# require editing the installer.
cp "$PROJECT_DIR"/locales/* "$LOCALE_DIR"/

e installing_servicemenu "$SERVICEMENU_DIR/"
# Escape sed replacement metacharacters: a $HOME containing & or | used to
# produce a broken .desktop file.
_home_escaped="${HOME//\\/\\\\}"
_home_escaped="${_home_escaped//&/\\&}"
_home_escaped="${_home_escaped//|/\\|}"
sed "s|@HOME@|$_home_escaped|g" "$PROJECT_DIR/servicemenu/ask-ai-dolphin.desktop" \
    > "$SERVICEMENU_DIR/ask-ai-dolphin.desktop"
chmod +x "$SERVICEMENU_DIR/ask-ai-dolphin.desktop"

CONFIG_SRC="ask-ai-dolphin.cfg.example"
if [ "$LOCALE" = "ru_RU" ]; then
    RU_CONFIG="$PROJECT_DIR/config/ask-ai-dolphin.cfg.ru_RU.example"
    [ -f "$RU_CONFIG" ] && CONFIG_SRC="ask-ai-dolphin.cfg.ru_RU.example"
fi

if [ ! -f "$CONFIG_DIR/ask-ai-dolphin.cfg" ]; then
    e creating_config "$CONFIG_DIR/ask-ai-dolphin.cfg"
    cp "$PROJECT_DIR/config/$CONFIG_SRC" "$CONFIG_DIR/ask-ai-dolphin.cfg"
else
    e config_exists "$CONFIG_DIR/ask-ai-dolphin.cfg"
fi

ASK_AI_FILE="$HOME/.ask_ai"
if [ ! -f "$ASK_AI_FILE" ]; then
    e creating_ask_ai
    cp "$PROJECT_DIR/dot-ask_ai/dot-ask_ai.example" "$ASK_AI_FILE"
else
    e ask_ai_exists
    e ask_ai_see_example
fi

# --- Shell config: prefer $SHELL ---
SHELL_CONFIG=""
SHELL_NAME="$(basename "${SHELL:-bash}")"
case "$SHELL_NAME" in
    zsh)
        [ -f "$HOME/.zshrc" ] && SHELL_CONFIG="$HOME/.zshrc"
        ;;
    bash)
        if [ -f "$HOME/.bashrc" ]; then
            SHELL_CONFIG="$HOME/.bashrc"
        elif [ -f "$HOME/.bash_profile" ]; then
            SHELL_CONFIG="$HOME/.bash_profile"
        elif [ -f "$HOME/.profile" ]; then
            SHELL_CONFIG="$HOME/.profile"
        fi
        ;;
    fish)
        e fish_note
        ;;
    *)
        if [ -f "$HOME/.bashrc" ]; then
            SHELL_CONFIG="$HOME/.bashrc"
        elif [ -f "$HOME/.zshrc" ]; then
            SHELL_CONFIG="$HOME/.zshrc"
        elif [ -f "$HOME/.bash_profile" ]; then
            SHELL_CONFIG="$HOME/.bash_profile"
        elif [ -f "$HOME/.profile" ]; then
            SHELL_CONFIG="$HOME/.profile"
        fi
        ;;
esac

LINE='[[ -f ~/.ask_ai ]] && . ~/.ask_ai'
if [ -n "$SHELL_CONFIG" ]; then
    if ! grep -Fxq '[[ -f ~/.ask_ai ]] && . ~/.ask_ai' "$SHELL_CONFIG" 2>/dev/null \
        && ! grep -Fq 'source ~/.ask_ai' "$SHELL_CONFIG" 2>/dev/null \
        && ! grep -Fq '. ~/.ask_ai' "$SHELL_CONFIG" 2>/dev/null; then
        echo "" >> "$SHELL_CONFIG"
        echo "# Ask AI terminal functions" >> "$SHELL_CONFIG"
        echo "$LINE" >> "$SHELL_CONFIG"
        e added_source "$SHELL_CONFIG"
    fi
elif [ "$SHELL_NAME" != "fish" ]; then
    echo ""
    e no_shell_config
    e add_manually
    e add_manually_cmd
fi

echo ""
e install_complete
echo ""
e restart_dolphin
e restart_terminal
echo ""
e optional
e edit_presets "$CONFIG_DIR/ask-ai-dolphin.cfg"
e set_model
e set_effort
e set_mode
