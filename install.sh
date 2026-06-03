#!/bin/bash
# install.sh — Install Ask AI into the Dolphin context menu
#
# Supports two modes:
#   1. Local:   ./install.sh — from a cloned repository
#   2. One-liner:  curl -s https://raw.githubusercontent.com/kas-cor/ask-ai-dolphin-context-menu/main/install.sh | bash
#
# Copies scripts to ~/.local/bin/
# Installs the service menu to ~/.local/share/kio/servicemenus/
# Copies the example config if it doesn't exist

set -euo pipefail

REPO="kas-cor/ask-ai-dolphin-context-menu"
BRANCH="main"
GITHUB_RAW="https://raw.githubusercontent.com/$REPO/$BRANCH"
GITHUB_TAR="https://github.com/$REPO/archive/$BRANCH.tar.gz"

# --- Detect mode: local or curl pipe ---
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo "")"

if [ -z "$SCRIPT_DIR" ] || [ ! -f "$SCRIPT_DIR/src/ask-dolphin.sh" ]; then
    # --- Curl pipe mode: download the project to a temp directory ---
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

# --- Local mode: use files from the repository ---

# --- Dependency checks ---
echo "🔍 Checking dependencies..."

MISSING=""
for cmd in python3 konsole opencode; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING="$MISSING  - $cmd\n"
    fi
done

if ! python3 -c "import PyQt5" 2>/dev/null; then
    MISSING="$MISSING  - python3-PyQt5\n"
fi

if [ -n "$MISSING" ]; then
    echo ""
    echo "❌ Missing required dependencies:"
    echo -e "$MISSING"
    echo ""
    echo "  Install them with:"
    echo "    sudo pacman -S python-pyqt5 konsole"
    echo "    # opencode: see https://opencode.ai"
    echo ""
    exit 1
fi

# Optional: glow
if ! command -v glow &> /dev/null; then
    echo "  ⚠️  glow not found — Markdown formatting will not be available"
    echo "       Install: sudo pacman -S glow"
fi

echo ""

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
SERVICEMENU_DIR="$HOME/.local/share/kio/servicemenus"
CONFIG_DIR="$HOME/.config"

echo "📦 Installing Ask AI Dolphin context menu..."

# --- Create directories ---
mkdir -p "$BIN_DIR"
mkdir -p "$SERVICEMENU_DIR"
mkdir -p "$CONFIG_DIR"

# --- Copy scripts ---
echo "  → Copying scripts to $BIN_DIR/"
install -m 755 "$PROJECT_DIR/src/ask-dolphin.sh"         "$BIN_DIR/ask-dolphin.sh"
install -m 755 "$PROJECT_DIR/src/ask-dolphin-run.sh"     "$BIN_DIR/ask-dolphin-run.sh"
install -m 755 "$PROJECT_DIR/src/ask-dolphin-dialog.py"  "$BIN_DIR/ask-dolphin-dialog.py"

# --- Copy .desktop, replacing @HOME@ ---
echo "  → Installing service menu to $SERVICEMENU_DIR/"
sed "s|@HOME@|$HOME|g" "$PROJECT_DIR/servicemenu/ask-dolphin.desktop" \
    > "$SERVICEMENU_DIR/ask-dolphin.desktop"
chmod +x "$SERVICEMENU_DIR/ask-dolphin.desktop"

# --- Copy example config (don't overwrite existing) ---
if [ ! -f "$CONFIG_DIR/ask-dolphin.cfg" ]; then
    echo "  → Creating default config at $CONFIG_DIR/ask-dolphin.cfg"
    cp "$PROJECT_DIR/config/ask-dolphin.cfg.example" "$CONFIG_DIR/ask-dolphin.cfg"
else
    echo "  → Config already exists at $CONFIG_DIR/ask-dolphin.cfg (keeping)"
fi

# --- .ask_ai — automatic setup ---
ASK_AI_FILE="$HOME/.ask_ai"
if [ ! -f "$ASK_AI_FILE" ]; then
    echo "  → Creating ~/.ask_ai with terminal functions (ask / askr)"
    cp "$PROJECT_DIR/dot-ask_ai/dot-ask_ai.example" "$ASK_AI_FILE"
fi

# --- Add source ~/.ask_ai to shell config ---
SHELL_CONFIG=""
if [ -f "$HOME/.bashrc" ]; then
    SHELL_CONFIG="$HOME/.bashrc"
elif [ -f "$HOME/.zshrc" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [ -f "$HOME/.bash_profile" ]; then
    SHELL_CONFIG="$HOME/.bash_profile"
elif [ -f "$HOME/.profile" ]; then
    SHELL_CONFIG="$HOME/.profile"
fi

LINE="source \"$ASK_AI_FILE\""
if [ -n "$SHELL_CONFIG" ]; then
    if ! grep -Fxq "$LINE" "$SHELL_CONFIG" 2>/dev/null; then
        echo "" >> "$SHELL_CONFIG"
        echo "# Ask AI terminal functions" >> "$SHELL_CONFIG"
        echo "$LINE" >> "$SHELL_CONFIG"
        echo "  → Added 'source ~/.ask_ai' to $SHELL_CONFIG"
    fi
else
    echo ""
    echo "  ⚠️  Could not detect shell config file."
    echo "       Add this line manually:"
    echo "         echo 'source ~/.ask_ai' >> ~/.bashrc"
fi

echo ""
echo "✅ Installation complete!"
echo ""
echo "To apply, restart Dolphin: Ctrl+Shift+R"
echo "Or from terminal: killall dolphin && dolphin --new-window &"
echo ""
echo "📝 Optional:"
echo "  - Edit presets:  nano $CONFIG_DIR/ask-dolphin.cfg"
echo "  - Set model:     nano ~/.ask_ai  (change ASK_MODEL)"

