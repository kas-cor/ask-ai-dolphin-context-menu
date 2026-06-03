#!/bin/bash
# install.sh — установка Ask AI в контекстное меню Dolphin
#
# Поддерживает два режима:
#   1. Локальный: ./install.sh — из клонированного репозитория
#   2. Одна строка: curl -s https://raw.githubusercontent.com/kas-cor/ask_ai_dolphin_context_menu/main/install.sh | bash
#
# Копирует скрипты в ~/.local/bin/
# Устанавливает сервис-меню в ~/.local/share/kio/servicemenus/
# Копирует пример конфига, если его ещё нет

set -euo pipefail

REPO="kas-cor/ask_ai_dolphin_context_menu"
BRANCH="main"
GITHUB_RAW="https://raw.githubusercontent.com/$REPO/$BRANCH"
GITHUB_TAR="https://github.com/$REPO/archive/$BRANCH.tar.gz"

# --- Определяем режим: локальный или curl pipe ---
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo "")"

if [ -z "$SCRIPT_DIR" ] || [ ! -f "$SCRIPT_DIR/src/ask-dolphin.sh" ]; then
    # --- Режим curl pipe: скачиваем проект во временную папку ---
    echo "📦 Downloading project from GitHub..."

    if ! command -v curl &>/dev/null; then
        echo "❌ curl is required. Install: sudo pacman -S curl"
        exit 1
    fi

    TMP_DIR="$(mktemp -d)"
    curl -sfL "$GITHUB_TAR" | tar xz -C "$TMP_DIR" --strip-components=1
    bash "$TMP_DIR/install.sh" && rc=0 || rc=$?
    rm -rf "$TMP_DIR"
    exit "$rc"
fi

# --- Локальный режим: используем файлы из репозитория ---

# --- Проверка зависимостей ---
echo "🔍 Checking dependencies..."

MISSING=""
for cmd in python3 konsole opencode; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING="$MISSING  • $cmd\n"
    fi
done

if ! python3 -c "import PyQt5" 2>/dev/null; then
    MISSING="$MISSING  • python3-PyQt5\n"
fi

if [ -n "$MISSING" ]; then
    echo ""
    echo "❌ Missing required dependencies:"
    echo -e "$MISSING"
    echo ""
    echo "Install them with:"
    echo "  sudo pacman -S python-pyqt5 konsole"
    echo "  # opencode: see https://opencode.ai"
    echo ""
    exit 1
fi

# Опционально: glow
if ! command -v glow &> /dev/null; then
    echo "  ⚠️  glow not found — Markdown formatting will not be available"
    echo "     Install: sudo pacman -S glow"
fi

echo ""

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
SERVICEMENU_DIR="$HOME/.local/share/kio/servicemenus"
CONFIG_DIR="$HOME/.config"

echo "📦 Installing Ask AI Dolphin context menu..."

# --- Создаём директории ---
mkdir -p "$BIN_DIR"
mkdir -p "$SERVICEMENU_DIR"
mkdir -p "$CONFIG_DIR"

# --- Копируем скрипты ---
echo "  → Copying scripts to $BIN_DIR/"
install -m 755 "$PROJECT_DIR/src/ask-dolphin.sh"         "$BIN_DIR/ask-dolphin.sh"
install -m 755 "$PROJECT_DIR/src/ask-dolphin-run.sh"     "$BIN_DIR/ask-dolphin-run.sh"
install -m 755 "$PROJECT_DIR/src/ask-dolphin-dialog.py"  "$BIN_DIR/ask-dolphin-dialog.py"

# --- Копируем .desktop, подставляя HOME ---
echo "  → Installing service menu to $SERVICEMENU_DIR/"
sed "s|@HOME@|$HOME|g" "$PROJECT_DIR/servicemenu/ask-dolphin.desktop" \
    > "$SERVICEMENU_DIR/ask-dolphin.desktop"
chmod +x "$SERVICEMENU_DIR/ask-dolphin.desktop"

# --- Копируем пример конфига (не перезаписываем существующий) ---
if [ ! -f "$CONFIG_DIR/ask-dolphin.cfg" ]; then
    echo "  → Creating default config at $CONFIG_DIR/ask-dolphin.cfg"
    cp "$PROJECT_DIR/config/ask-dolphin.cfg.example" "$CONFIG_DIR/ask-dolphin.cfg"
else
    echo "  → Config already exists at $CONFIG_DIR/ask-dolphin.cfg (keeping)"
fi

# --- Пример .ask_ai (опционально) ---
if [ ! -f "$HOME/.ask_ai" ]; then
    echo ""
    echo "ℹ️  You don't have ~/.ask_ai yet. You can use the example:"
    echo "   source <(curl -s $GITHUB_RAW/dot-ask_ai/dot-ask_ai.example)"
    echo "   Or copy from the config: cat $GITHUB_RAW/dot-ask_ai/dot-ask_ai.example > ~/.ask_ai"
    echo "   Then add 'source ~/.ask_ai' to your ~/.bashrc or ~/.zshrc"
fi

echo ""
echo "✅ Installation complete!"
echo ""
echo "To apply, restart Dolphin: Ctrl+Shift+R"
echo "Or from terminal: killall dolphin && dolphin --new-window &"
echo ""
echo "📝 Optional:"
echo "  - Edit presets:  nano $CONFIG_DIR/ask-dolphin.cfg"
echo "  - Set model:     export ASK_MODEL=\"opencode/claude-sonnet-4-6\""
echo "                    (add to ~/.ask_ai or ~/.bashrc)"
