> **🌐 Русская версия:** [README_ru.md](./README_ru.md)

# 🤖 Ask AI — Dolphin Context Menu

Integrate an AI assistant into the **Dolphin** file manager context menu (KDE Plasma).

Select files/folders → right-click → **Ask AI** → choose a preset or type your query → get a formatted response in Konsole.

## Features

- **Query presets** — configurable list of quick queries
- **Custom query** — free-text input field for your own question
- **Model selection** — via the `ASK_MODEL` environment variable (defaults to free `opencode/deepseek-v4-flash-free`)
- **Streaming response** — output is piped through `glow` for real-time Markdown highlighting
- **No selection fallback** — if nothing is selected, the current directory is used as context
- **PyQt5 dialog** — polished UI styled for KDE Breeze

## Dependencies

- **KDE Plasma** (Dolphin, Konsole)
- **Python 3 + PyQt5**
- **[opencode](https://opencode.ai)** — CLI for AI models
- **glow** (optional) — formatted Markdown output

### Installing dependencies (Arch Linux)

```bash
sudo pacman -S python-pyqt5 konsole
yay -S glow-bin  # or sudo pacman -S glow if available
# opencode — install from https://opencode.ai
```

## Installation

### One-liner (curl | bash)

```bash
curl -s https://raw.githubusercontent.com/kas-cor/ask-ai-dolphin-context-menu/main/install.sh | bash
```

The script downloads the project from GitHub and installs it. No cloning needed.

### One-liner uninstall

```bash
curl -s https://raw.githubusercontent.com/kas-cor/ask-ai-dolphin-context-menu/main/uninstall.sh | bash
```

### Local install (git clone)

```bash
git clone https://github.com/kas-cor/ask-ai-dolphin-context-menu.git
cd ask-ai-dolphin-context-menu
./install.sh
```

After installation (any method), restart Dolphin: **Ctrl+Shift+R**

## Configuration

### Query presets

Edit `~/.config/ask-dolphin.cfg`:

```bash
nano ~/.config/ask-dolphin.cfg
```

— one query per line, lines starting with `#` are ignored. Only the last **8 presets** are shown in the dialog.

### AI model

The installer automatically creates `~/.ask_ai` with the default model and adds `source ~/.ask_ai` to your shell config (`.bashrc` / `.zshrc`).

To change the model, edit:

```bash
nano ~/.ask_ai
# Change ASK_MODEL to any of the available models
```

List available models: `opencode models`

Examples:
- `opencode/deepseek-v4-flash-free` — free (default)
- `opencode/deepseek-v4-flash`
- `opencode/claude-sonnet-4-6`
- `opencode/claude-haiku-4-5`
- `opencode/gpt-5.4-pro`
- `opencode/gemini-3.5-flash`
- `opencode/qwen3.5-plus`

### `ask` / `askr` terminal functions

The installer sets these up automatically. After reopening your terminal, use them directly:

```bash
ask "Find bugs in this code"
askr "Show me the answer"
```

- `ask "..."` — streams response through `glow` (formatted Markdown)
- `askr "..."` — raw output (no formatting)

## Usage

1. Select one or more files/folders in Dolphin
2. Right-click → **🤖 Ask AI**
3. Choose a preset (sends immediately) or type your query and click **Send**
4. Konsole opens — the response streams through `glow`
5. Press **Ctrl+C** or **Enter** to close the window

## Project structure

```
ask-ai-dolphin-context-menu/
├── src/
│   ├── ask-dolphin.sh          # Entry point — PyQt5 dialog + Konsole
│   ├── ask-dolphin-run.sh      # Runner: stream opencode through glow
│   └── ask-dolphin-dialog.py   # PyQt5 dialog with presets and input field
├── servicemenu/
│   └── ask-dolphin.desktop     # Dolphin service menu file
├── config/
│   └── ask-dolphin.cfg.example # Example presets config
├── dot-ask_ai/
│   └── dot-ask_ai.example      # Example ~/.ask_ai file
├── install.sh                  # Install script (works via curl too)
├── uninstall.sh                # Uninstall script (works via curl too)
├── AGENTS.md                   # AI agents description
├── README.md                   # This file (English)
└── README_ru.md                # Russian documentation
```

## License

MIT
