> **🌐 Русская версия:** [README_ru.md](./README_ru.md)

<div align="center">

# 🤖 Ask AI — Dolphin Context Menu

[![CI](https://github.com/kas-cor/ask-ai-dolphin-context-menu/actions/workflows/ci.yml/badge.svg)](https://github.com/kas-cor/ask-ai-dolphin-context-menu/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub Release](https://img.shields.io/github/v/release/kas-cor/ask-ai-dolphin-context-menu)](https://github.com/kas-cor/ask-ai-dolphin-context-menu/releases)
[![Platform](https://img.shields.io/badge/Platform-Linux--KDE-blue)](https://kde.org)

Integrate an AI assistant into the **Dolphin** file manager context menu (KDE Plasma).

</div>

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

### Environment variables

The installer automatically creates `~/.ask_ai` with the default model and adds `source ~/.ask_ai` to your shell config (`.bashrc` / `.zshrc`).

Edit `~/.ask_ai` to configure:

```bash
nano ~/.ask_ai
# Change ASK_MODEL to any available model
# Uncomment ASK_LOCALE or ASK_THEME to override auto-detection
```

| Variable | Default | Description |
|---|---|---|
| `ASK_MODEL` | `opencode/deepseek-v4-flash-free` | AI model for opencode. List: `opencode models` |
| `GLOW_DISABLED` | unset | Set to `1` for raw output without glow formatting (`askr`) |
| `ASK_LOCALE` | auto-detect (system `$LANG`) | Force UI language: `ru_RU` / `en_EN` |
| `ASK_THEME` | auto-detect (system palette) | Force UI theme: `dark` / `light` |

**Examples:**

```bash
export ASK_MODEL="opencode/deepseek-v4-flash"
export GLOW_DISABLED=1
export ASK_LOCALE="ru_RU"    # force Russian UI
export ASK_THEME="dark"      # force dark theme
```

See [Localization](#localization) for locale details. The theme auto-detects from your KDE color scheme and works for both the PyQt5 dialog and the Konsole runner header.

### `ask` / `askr` terminal functions

The installer sets these up automatically. After reopening your terminal, use them directly:

```bash
ask "Find bugs in this code"
askr "Show me the answer"
```

- `ask "..."` — streams response through `glow` (formatted Markdown)
- `askr "..."` — raw output (no formatting)

## Localization

The project supports **English** and **Russian** (Русский). The language is auto-detected from your system locale and can be overridden.

### What is localized

| Component | English | Russian |
|---|---|---|
| Installer (`install.sh`) | All messages | Все сообщения |
| Presets config | `ask-dolphin.cfg.example` | `ask-dolphin.cfg.ru_RU.example` |
| PyQt5 dialog (title, labels, buttons) | ✅ | ✅ |
| Runner header (Konsole) | ✅ | ✅ |
| Service menu name (Dolphin) | 🤖 Ask AI | 🤖 Спросить AI |
| Documentation | `README.md` | `README_ru.md` |

### Locale detection priority

1. **Installer:** CLI arg → `$LANG` → `en_EN`
2. **Dialog / Runner:** `ASK_LOCALE` env var → `$LANG` → `en_EN`

### How to change the language

**During installation** — pass locale as argument:

```bash
./install.sh ru_RU          # force Russian
curl ...install.sh | bash -s ru_RU   # via curl pipe
```

**After installation (dialog & runner)** — set `ASK_LOCALE` in `~/.ask_ai`:

```bash
export ASK_LOCALE="ru_RU"    # force Russian UI
# or
export ASK_LOCALE="en_EN"    # force English UI
```

Without `ASK_LOCALE`, the system `$LANG` variable is used (e.g., `LANG=ru_RU.UTF-8` → Russian). Russian is also detected from `ru_UA*`, `be_BY*`, and `uk_UA*` locales.

### Config presets by locale

During installation, the appropriate presets file is copied to `~/.config/ask-dolphin.cfg`:

- **ru_RU** → Russian presets (`Опиши эти файлы`, `Найди ошибки…`, etc.)
- **en_EN / other** → English presets (`Describe these files`, `Find bugs…`, etc.)

The existing config is never overwritten on reinstall.

### Contributing a new locale

Want to add support for your language? Here's how:

1. **Create a locale file** — copy `locales/en_EN` to `locales/xx_XX` (where `xx_XX` is your locale code, e.g., `de_DE`, `fr_FR`, `pl_PL`) and translate all values:

```bash
cp locales/en_EN locales/de_DE
# Edit locales/de_DE — translate everything after the =
```

2. **Install locale detection** — add your locale to the case statements in all 4 scripts. Look for the existing `ru_RU*|ru_UA*|be_BY*|uk_UA*` pattern and the `ASK_LOCALE` handling:

   - `install.sh` — add to both: `ru_RU*|ru_UA*|be_BY*|uk_UA*) DETECTED_LOCALE="ru_RU" ;;` and the `ASK_LOCALE` case block
   - `src/ask-dolphin.sh` — same two locations
   - `src/ask-dolphin-run.sh` — same two locations
   - `src/ask-dolphin-dialog.py` — in `detect_locale()` function (both `ASK_LOCALE` and `LANG` checks)

3. **Create a preset config** (optional) — create `config/ask-dolphin.cfg.xx_XX.example` with translated preset queries

4. **Update install.sh** — add locale-based config selection logic for your locale (see existing `ru_RU` block)

5. **Update the .desktop file** — add `Name[xx]=Your Translation` to `servicemenu/ask-dolphin.desktop`

6. **Document your locale** — add `README_xx_XX.md` (or update the existing documentation table)

7. **Submit a pull request** with all the changes!

**Key prefixes** for reference:
- `install_*` — installer messages (`install.sh`)
- `runner_*` — runner labels (`ask-dolphin-run.sh`)
- `dialog_*` — dialog UI strings (`ask-dolphin-dialog.py`)
- `sh_*` — shell entry point headers (`ask-dolphin.sh`)

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
