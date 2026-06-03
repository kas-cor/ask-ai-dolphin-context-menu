#!/bin/bash
# uninstall.sh — удаление Ask AI из контекстного меню Dolphin

set -euo pipefail

BIN_DIR="$HOME/.local/bin"
SERVICEMENU_DIR="$HOME/.local/share/kio/servicemenus"

echo "🗑️  Uninstalling Ask AI Dolphin context menu..."

# --- Удаляем скрипты ---
for f in ask-dolphin.sh ask-dolphin-run.sh ask-dolphin-dialog.py; do
    if [ -f "$BIN_DIR/$f" ]; then
        rm -v "$BIN_DIR/$f"
    fi
done

# --- Удаляем сервис-меню ---
if [ -f "$SERVICEMENU_DIR/ask-dolphin.desktop" ]; then
    rm -v "$SERVICEMENU_DIR/ask-dolphin.desktop"
fi

echo ""
echo "✅ Uninstall complete."
echo ""
echo "To keep things clean, you may also want to remove:"
echo "  rm ~/.config/ask-dolphin.cfg   (your custom presets)"
echo ""
echo "Restart Dolphin to apply: Ctrl+Shift+R"
echo "Or: killall dolphin && dolphin --new-window &"
