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
DETECTED_LOCALE="en_EN"
if [ -n "${1:-}" ]; then
    _arg_lower="${1,,}"
    case "$_arg_lower" in
        ru_RU|ru) DETECTED_LOCALE="ru_RU" ;;
        *)        DETECTED_LOCALE="en_EN" ;;
    esac
else
    case "${LANG:-}" in
        ru_RU*|ru_UA*|be_BY*|uk_UA*) DETECTED_LOCALE="ru_RU" ;;
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

    if [ -z "$str" ]; then
        case "$LOCALE" in
            ru_RU)
                case "$key" in
                    downloading)       str="📦 Загрузка проекта с GitHub..." ;;
                    curl_required)     str="❌ Требуется curl. Установите: sudo pacman -S curl" ;;
                    checking_deps)     str="🔍 Проверка зависимостей..." ;;
                    missing_deps)      str="❌ Отсутствуют необходимые зависимости:" ;;
                    install_them)      str="  Установите их:" ;;
                    opencode_url)      str="    # opencode: см. https://opencode.ai" ;;
                    glow_warning)      str="  ⚠️  glow не найден — форматирование Markdown недоступно" ;;
                    glow_install)      str="       Установите: sudo pacman -S glow" ;;
                    installing)        str="📦 Установка Ask AI Dolphin context menu..." ;;
                    copying_scripts)   str="  → Копирование скриптов в %s" ;;
                    installing_servicemenu) str="  → Установка сервис-меню в %s" ;;
                    creating_config)   str="  → Создание конфига по умолчанию в %s" ;;
                    config_exists)     str="  → Конфиг уже существует в %s (оставлен)" ;;
                    creating_ask_ai)   str="  → Создание ~/.ask_ai с функциями терминала (ask / askr)" ;;
                    ask_ai_exists)     str="  → ~/.ask_ai уже существует (оставлен)" ;;
                    ask_ai_see_example) str="       Новые опции: см. example в репозитории (dot-ask_ai/dot-ask_ai.example)" ;;
                    added_source)      str="  → Добавлено 'source ~/.ask_ai' в %s" ;;
                    no_shell_config)   str="  ⚠️  Не удалось определить файл конфигурации оболочки." ;;
                    add_manually)      str="       Добавьте эту строку вручную:" ;;
                    add_manually_cmd)  str="         echo '[[ -f ~/.ask_ai ]] && . ~/.ask_ai' >> ~/.bashrc" ;;
                    fish_note)         str="  ⚠️  Fish: функции ask/askr — bash/zsh. Добавьте обёртку вручную или используйте bash." ;;
                    install_complete)  str="✅ Установка завершена!" ;;
                    restart_dolphin)   str="Чтобы применить, перезапустите Dolphin: Ctrl+Shift+R" ;;
                    restart_terminal)  str="Или из терминала: killall dolphin && dolphin --new-window &" ;;
                    optional)          str="📝 Дополнительно:" ;;
                    edit_presets)      str="  - Изменить пресеты:  nano %s" ;;
                    set_model)         str="  - Сменить модель:    nano ~/.ask_ai  (изменить ASK_AI_MODEL)" ;;
                    set_effort)        str="  - Уровень усилий:   nano ~/.ask_ai  (изменить ASK_AI_EFFORT)" ;;
                    set_mode)          str="  - Режим работы:     nano ~/.ask_ai  (изменить ASK_AI_MODE)" ;;
                    *)                 str="[msg_%s]" ;;
                esac
                ;;
            *)
                case "$key" in
                    downloading)       str="📦 Downloading project from GitHub..." ;;
                    curl_required)     str="❌ curl is required. Install: sudo pacman -S curl" ;;
                    checking_deps)     str="🔍 Checking dependencies..." ;;
                    missing_deps)      str="❌ Missing required dependencies:" ;;
                    install_them)      str="  Install them with:" ;;
                    opencode_url)      str="    # opencode: see https://opencode.ai" ;;
                    glow_warning)      str="  ⚠️  glow not found — Markdown formatting will not be available" ;;
                    glow_install)      str="       Install: sudo pacman -S glow" ;;
                    installing)        str="📦 Installing Ask AI Dolphin context menu..." ;;
                    copying_scripts)   str="  → Copying scripts to %s" ;;
                    installing_servicemenu) str="  → Installing service menu to %s" ;;
                    creating_config)   str="  → Creating default config at %s" ;;
                    config_exists)     str="  → Config already exists at %s (keeping)" ;;
                    creating_ask_ai)   str="  → Creating ~/.ask_ai with terminal functions (ask / askr)" ;;
                    ask_ai_exists)     str="  → ~/.ask_ai already exists (keeping)" ;;
                    ask_ai_see_example) str="       New options: see dot-ask_ai/dot-ask_ai.example in the repo" ;;
                    added_source)      str="  → Added 'source ~/.ask_ai' to %s" ;;
                    no_shell_config)   str="  ⚠️  Could not detect shell config file." ;;
                    add_manually)      str="       Add this line manually:" ;;
                    add_manually_cmd)  str="         echo '[[ -f ~/.ask_ai ]] && . ~/.ask_ai' >> ~/.bashrc" ;;
                    fish_note)         str="  ⚠️  Fish: ask/askr are bash/zsh functions. Add a wrapper manually or use bash." ;;
                    install_complete)  str="✅ Installation complete!" ;;
                    restart_dolphin)   str="To apply, restart Dolphin: Ctrl+Shift+R" ;;
                    restart_terminal)  str="Or from terminal: killall dolphin && dolphin --new-window &" ;;
                    optional)          str="📝 Optional:" ;;
                    edit_presets)      str="  - Edit presets:  nano %s" ;;
                    set_model)         str="  - Set model:     nano ~/.ask_ai  (change ASK_AI_MODEL)" ;;
                    set_effort)        str="  - Set effort:   nano ~/.ask_ai  (change ASK_AI_EFFORT)" ;;
                    set_mode)          str="  - Set mode:     nano ~/.ask_ai  (change ASK_AI_MODE)" ;;
                    *)                 str="[msg_%s]" ;;
                esac
                ;;
        esac
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

cp "$PROJECT_DIR/locales/en_EN" "$LOCALE_DIR/en_EN"
cp "$PROJECT_DIR/locales/ru_RU" "$LOCALE_DIR/ru_RU"

e installing_servicemenu "$SERVICEMENU_DIR/"
sed "s|@HOME@|$HOME|g" "$PROJECT_DIR/servicemenu/ask-ai-dolphin.desktop" \
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
