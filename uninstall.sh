#!/bin/bash
# uninstall.sh — Remove Ask AI from the Dolphin context menu
#
# Usage:
#   ./uninstall.sh                — from a cloned repository
#   curl -s https://raw.githubusercontent.com/.../uninstall.sh | bash

set -euo pipefail

BIN_DIR="$HOME/.local/bin"
LOCALE_DIR="$BIN_DIR/locales"
SERVICEMENU_DIR="$HOME/.local/share/kio/servicemenus"

echo "Uninstalling Ask AI Dolphin context menu..."

# --- Remove scripts ---
for f in ask-ai-common.sh ask-ai-dolphin.sh ask-ai-dolphin-run.sh ask-ai-dolphin-dialog.py; do
    if [ -f "$BIN_DIR/$f" ]; then
        rm -v "$BIN_DIR/$f"
    fi
done

# --- Remove locale files installed by this project ---
for f in en_EN ru_RU; do
    if [ -f "$LOCALE_DIR/$f" ]; then
        rm -v "$LOCALE_DIR/$f"
    fi
done
# Remove locales dir only if empty
if [ -d "$LOCALE_DIR" ]; then
    rmdir "$LOCALE_DIR" 2>/dev/null || true
fi

# --- Remove service menu ---
if [ -f "$SERVICEMENU_DIR/ask-ai-dolphin.desktop" ]; then
    rm -v "$SERVICEMENU_DIR/ask-ai-dolphin.desktop"
fi

echo ""
echo "Uninstall complete."
echo ""
echo "Optional cleanup (not removed automatically):"
echo "  rm ~/.config/ask-ai-dolphin.cfg       # custom presets"
echo "  rm ~/.config/ask-ai-dolphin.history   # query history"
echo "  rm ~/.ask_ai                          # terminal functions / env"
echo ""
echo "If install added a source line to your shell rc, you may remove:"
echo "  # Ask AI terminal functions"
echo "  [[ -f ~/.ask_ai ]] && . ~/.ask_ai"
echo ""
echo "Restart Dolphin to apply: Ctrl+Shift+R"
echo "Or: killall dolphin && dolphin --new-window &"
