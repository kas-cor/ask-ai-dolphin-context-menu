#!/bin/bash
# uninstall.sh — Remove Ask AI from the Dolphin context menu
#
# Usage:
#   ./uninstall.sh                — from a cloned repository
#   curl -s https://raw.githubusercontent.com/kas-cor/ask-ai-dolphin-context-menu/main/uninstall.sh | bash

set -euo pipefail

BIN_DIR="$HOME/.local/bin"
SERVICEMENU_DIR="$HOME/.local/share/kio/servicemenus"

echo "🗑️  Uninstalling Ask AI Dolphin context menu..."

# --- Remove scripts ---
for f in ask-ai-dolphin.sh ask-ai-dolphin-run.sh ask-ai-dolphin-dialog.py; do
    if [ -f "$BIN_DIR/$f" ]; then
        rm -v "$BIN_DIR/$f"
    fi
done

# --- Remove service menu ---
if [ -f "$SERVICEMENU_DIR/ask-ai-dolphin.desktop" ]; then
    rm -v "$SERVICEMENU_DIR/ask-ai-dolphin.desktop"
fi

echo ""
echo "✅ Uninstall complete."
echo ""
echo "To keep things clean, you may also want to remove:"
echo "  rm ~/.config/ask-ai-dolphin.cfg   (your custom presets)"
echo ""
echo "Restart Dolphin to apply: Ctrl+Shift+R"
echo "Or: killall dolphin && dolphin --new-window &"
