> **🌐 Русская версия:** [README_ru.md](./README_ru.md)

<div align="center">

# 🤖 Ask AI — Dolphin Context Menu

[![CI](https://github.com/kas-cor/ask-ai-dolphin-context-menu/actions/workflows/ci.yml/badge.svg)](https://github.com/kas-cor/ask-ai-dolphin-context-menu/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub Release](https://img.shields.io/github/v/release/kas-cor/ask-ai-dolphin-context-menu)](https://github.com/kas-cor/ask-ai-dolphin-context-menu/releases)
[![Platform](https://img.shields.io/badge/Platform-Linux--KDE-blue)](https://kde.org)
[![Changelog](https://img.shields.io/badge/Changelog-CHANGELOG.md-blue)](CHANGELOG.md)

Integrate an AI assistant into the **Dolphin** file manager context menu (KDE Plasma).

</div>

Select files/folders → right-click → **Ask AI** → choose a preset or type your query → get a formatted response in Konsole.

## Features

- **Query presets** — configurable list of quick queries
- **Custom query** — free-text input field for your own question
- **Model selection** — via the `ASK_AI_MODEL` environment variable (defaults to free `opencode/deepseek-v4-flash-free`)
- **Streaming response** — output is piped through `glow` for real-time Markdown highlighting
- **No selection fallback** — if nothing is selected, the current directory is used as context
- **PyQt dialog** — multi-line input, presets, recent history; Breeze-styled (PyQt5 / PyQt6)
- **File attachments** — text files attached to opencode via `-f` (size/count limits)
- **Safe script handling** — shebang responses saved as `.sh`; run only after confirm (or `ASK_AI_AUTO_EXEC`)

## Use Cases

### For developers

| Use case | Example query | How it works |
|---|---|---|
| **Code review** | `Find bugs in these files` | AI analyzes selected source files and lists issues |
| **Generate docs** | `Generate documentation` | Creates Markdown docs from code |
| **Write tests** | `Write tests for these files` | Outputs test code you can save |
| **Refactoring** | `Refactor this code` | Suggests improvements with diffs |
| **Security audit** | `Find security vulnerabilities` | Scans for OWASP-top issues |

### For everyone (non-programmers)

| Use case | Example query | How it works |
|---|---|---|
| **Summarize** | `Summarize this text and save to file` | AI reads the file and writes a summary to `ASK_AI_SAVE_DIR` |
| **Explain** | `Explain this like I'm five` | Breaks down complex documents / configs |
| **Translate** | `Translate this to English` | Translates text files in-place |
| **Data to tables** | `Create a Markdown table from this data` | Converts raw CSV / lists into formatted tables |
| **Image batch processing** | `Write a script to resize images to 1920x1080` | AI writes a bash script → saved as `.sh` → you confirm run |
| **Collage / slideshow** | `Write a script to make a collage from these images` | AI generates ImageMagick / ffmpeg script; confirm to run |
| **Crop to aspect ratio** | `Write a script to crop photos to 1:1` | Script saved next to selection; optional auto-run |

> **Script handling:** if the AI response starts with a shebang (`#!/bin/bash`, …) or a fenced code block containing one, the runner saves it as an executable `.sh` and asks **Run this script? [y/N]**. Set `ASK_AI_AUTO_EXEC=1` to always run, or `ASK_AI_AUTO_EXEC=0` to never run. Informational answers are shown as-is.

These are just examples — the only limit is your imagination. Any question you can ask an AI, any script it can write, any file you can point it at — it's all one right-click away.

### Quick terminal usage

After installation, use `ask` / `askr` from any terminal:

```bash
ask "Summarize this directory"
askr "Raw output without glow"
```

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

Edit `~/.config/ask-ai-dolphin.cfg`:

```bash
nano ~/.config/ask-ai-dolphin.cfg
```

— one query per line, lines starting with `#` are ignored. Only the last **8 presets** are shown in the dialog.

### Environment variables

The installer automatically creates `~/.ask_ai` with the default model and adds `source ~/.ask_ai` to your shell config (`.bashrc` / `.zshrc`).

Edit `~/.ask_ai` to configure:

```bash
nano ~/.ask_ai
# Change ASK_AI_MODEL to any available model
# Uncomment ASK_AI_LOCALE or ASK_AI_THEME to override auto-detection
```

| Variable | Default | Description |
|---|---|---|
| `ASK_AI_MODEL` | `opencode/deepseek-v4-flash-free` | AI model for opencode. List: `opencode models` |
| `ASK_AI_EFFORT` | unset | Reasoning effort (passed as `--variant` to opencode). Values: `high`, `max`, `minimal` |
| `ASK_AI_MODE` | unset | Operation mode (passed as `--agent` to opencode). Built-in: `plan`, `build`. List: `opencode agent list` |
| `ASK_AI_SAVE_DIR` | unset | Save AI responses to this directory (e.g., `~/ask-ai-results`). Creates `<query-slug>-<timestamp>.md` files |
| `ASK_AI_AUTO_EXEC` | `prompt` | Shebang script policy: `prompt` (ask y/N), `1`/`always`, `0`/`never` |
| `ASK_AI_CLIPBOARD` | unset | Set `1` to copy the response to the clipboard |
| `ASK_AI_MAX_ATTACH_BYTES` | `204800` | Max bytes per file attached with `opencode -f` |
| `ASK_AI_MAX_ATTACH_FILES` | `20` | Max number of attached text files |
| `GLOW_DISABLED` | unset | Set to `1` for raw output without glow formatting (`askr`) |
| `ASK_AI_LOCALE` | auto-detect (system `$LANG`) | Force UI language: `ru_RU` / `en_EN` |
| `ASK_AI_THEME` | auto-detect (system palette) | Force UI theme: `dark` / `light` |
| `TERMINAL` | unset | Preferred terminal (takes priority over konsole) |

**Examples:**

```bash
export ASK_AI_MODEL="opencode/deepseek-v4-flash"
export ASK_AI_EFFORT="max"     # maximum reasoning effort
export ASK_AI_MODE="plan"      # plan mode (uses --agent plan)
export ASK_AI_AUTO_EXEC="0"    # never auto-run generated scripts
export ASK_AI_CLIPBOARD=1      # copy answer to clipboard
export GLOW_DISABLED=1
export ASK_AI_LOCALE="ru_RU"    # force Russian UI
export ASK_AI_THEME="dark"      # force dark theme
```

See [Localization](#localization) for locale details. The theme auto-detects from your KDE color scheme and works for both the dialog and the runner header.

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
| Presets config | `ask-ai-dolphin.cfg.example` | `ask-ai-dolphin.cfg.ru_RU.example` |
| PyQt5 dialog (title, labels, buttons) | ✅ | ✅ |
| Runner header (Konsole) | ✅ | ✅ |
| Service menu name (Dolphin) | 🤖 Ask AI | 🤖 Спросить AI |
| Documentation | `README.md` | `README_ru.md` |

### Locale detection priority

1. **Installer:** CLI arg → `$LANG` → `en_EN`
2. **Dialog / Runner:** `ASK_AI_LOCALE` env var → `$LANG` → `en_EN`

### How to change the language

**During installation** — pass locale as argument:

```bash
./install.sh ru_RU          # force Russian
curl ...install.sh | bash -s ru_RU   # via curl pipe
```

**After installation (dialog & runner)** — set `ASK_AI_LOCALE` in `~/.ask_ai`:

```bash
export ASK_AI_LOCALE="ru_RU"    # force Russian UI
# or
export ASK_AI_LOCALE="en_EN"    # force English UI
```

Without `ASK_AI_LOCALE`, the system `$LANG` variable is used (e.g., `LANG=ru_RU.UTF-8` → Russian). Russian is also detected from `ru_UA*`, `be_BY*`, and `uk_UA*` locales.

### Config presets by locale

During installation, the appropriate presets file is copied to `~/.config/ask-ai-dolphin.cfg`:

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

2. **Install locale detection** — extend shared detection:

   - `src/ask-ai-common.sh` — `ask_ai_detect_locale()` (used by shell scripts + install)
   - `src/ask-ai-dolphin-dialog.py` — `detect_locale()`
   - `install.sh` — CLI arg bootstrap case (for curl-pipe before common.sh is available)

3. **Create a preset config** (optional) — create `config/ask-ai-dolphin.cfg.xx_XX.example` with translated preset queries

4. **Update install.sh** — add locale-based config selection logic for your locale (see existing `ru_RU` block)

5. **Update the .desktop file** — add `Name[xx]=Your Translation` to `servicemenu/ask-ai-dolphin.desktop`

6. **Document your locale** — add `README_xx_XX.md` (or update the existing documentation table)

7. **Submit a pull request** with all the changes!

**Key prefixes** for reference:
- `install_*` — installer messages (`install.sh`)
- `runner_*` — runner labels (`ask-ai-dolphin-run.sh`)
- `dialog_*` — dialog UI strings (`ask-ai-dolphin-dialog.py`)
- `sh_*` — shell entry point headers (`ask-ai-dolphin.sh`)

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
│   ├── ask-ai-common.sh           # Shared shell helpers (locale, file checks)
│   ├── ask-ai-dolphin.sh          # Entry point — dialog + terminal
│   ├── ask-ai-dolphin-run.sh      # Runner: opencode -f, glow, script confirm
│   └── ask-ai-dolphin-dialog.py   # Dialog: presets, history, multi-line input
├── servicemenu/
│   └── ask-ai-dolphin.desktop     # Dolphin service menu file
├── config/
│   └── ask-ai-dolphin.cfg.example # Example presets config
├── dot-ask_ai/
│   └── dot-ask_ai.example         # Example ~/.ask_ai file
├── locales/                       # en_EN, ru_RU
├── install.sh                     # Install script (works via curl too)
├── uninstall.sh                   # Uninstall script (works via curl too)
├── AGENTS.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── README.md
└── README_ru.md
```

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for contribution guidelines and conventional commits guide.

## License

MIT
