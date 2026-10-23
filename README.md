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
- **Model selection** — via the `ASK_AI_MODEL` environment variable (defaults to free `opencode/mimo-v2.6-flash-free`)
- **Streaming response** — the ACP answer is printed as the agent produces it (raw Markdown, no waiting for the turn to finish); with `glow` installed the finished answer then replaces the streamed text as one formatted message. The legacy `ASK_AI_HARNESS=cli` path is still piped through `glow`
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
- **[opencode](https://opencode.ai)** v2 — CLI for AI models
- **glow** (optional) — formatted Markdown output
- **file** (optional) — MIME-based detection of attachable text files (a NUL-byte check is used without it)

### Installing dependencies (Arch Linux)

```bash
sudo pacman -S python-pyqt5 konsole
yay -S glow-bin  # or sudo pacman -S glow if available
# opencode v2 — install:
curl -fsSL https://opencode.ai/v2/install | bash
# alternatives: sudo pacman -S opencode | npm i -g @opencode/cli | brew install anomalyco/tap/opencode-v2 | yay -S opencode-beta
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
| `ASK_AI_MODEL` | `opencode/mimo-v2.6-flash-free` | AI model for opencode. List: `opencode models` |
| `ASK_AI_EFFORT` | unset | Reasoning effort. opencode v2: applied as a model variant `provider/model#variant` (`--variant` was removed in v2). Values depend on the model (`high`, `max`, `minimal`, …); skipped with a warning if the model has no such variant |
| `ASK_AI_MODE` | `plan` | Operation mode (passed as `--agent` to opencode). Built-in: `plan`, `build`. `plan` is read-only — the model answers, never edits files. The flag is always passed explicitly: in opencode v2 an agent inherited from the opencode config adds a spurious second turn to the output |
| `ASK_AI_SAVE_DIR` | unset | Save AI responses to this directory (e.g., `~/ask-ai-results`). Creates `<query-slug>-<timestamp>.md` files |
| `ASK_AI_AUTO_EXEC` | `prompt` | Shebang script policy: `prompt` (ask y/N), `1`/`always`, `0`/`never` |
| `ASK_AI_CLIPBOARD` | unset | Set `1` to copy the response to the clipboard |
| `ASK_AI_MAX_ATTACH_BYTES` | `204800` | Max bytes per file attached with `opencode -f` |
| `ASK_AI_MAX_ATTACH_FILES` | `20` | Max number of attached text files |
| `GLOW_DISABLED` | unset | Set to `1` to turn glow off entirely: the ACP answer stays as it was streamed and `askr` prints it raw |
| `ASK_AI_LOCALE` | auto-detect (system `$LANG`) | Force UI language: `ru_RU` / `en_EN` |
| `ASK_AI_THEME` | auto-detect (system palette) | Force UI theme: `dark` / `light` |
| `TERMINAL` | unset | Preferred terminal (takes priority over konsole) |
| `ASK_AI_HARNESS` | `acp` | `acp` drives any [ACP](https://agentclientprotocol.com) agent; `cli` uses the legacy `opencode run` path |
| `ASK_AI_AGENT` | `opencode` | Agents from the built-in registry: `opencode`, `gemini`, `claude`, `codex`, `qwen`, `goose`, `copilot`. For `opencode` the runner prefers the v2 binary (`~/.opencode/bin`), because a GUI session's `PATH` often resolves to a system v1 with its own auth |
| `ASK_AI_AGENT_CMD` | unset | Any agent command line; overrides the registry (e.g. `npx -y some-acp-agent`) |
| `ASK_AI_PERMISSION` | `allow-read` | ACP tool permission policy: `allow-read` (read/search/fetch only), `ask` (y/N in the terminal for anything that changes files), `deny` |
| `ASK_AI_ACP_REUSE` | unset | `1` resumes the previous session for the same agent and directory (`session/load`) |
| `ASK_AI_ACP_IDLE_TIMEOUT` | `180` | Cancel the turn when no answer text arrives for this many seconds |
| `ASK_AI_ACP_SESSION_STORE` | `~/.cache/ask-ai/acp-sessions.json` | Where resumed session ids are remembered |
| `ASK_AI_ACP_VERBOSE` | unset | `1` prints agent thoughts and tool calls on stderr; without it a single `Thinking...` line says the agent is working |
| `ASK_AI_ACP_TRACE` | unset | Log JSON-RPC traffic to this file |
| `ASK_AI_ACP` | unset | Legacy alias: `0` selects the CLI path (same as `ASK_AI_HARNESS=cli`) |

`~/.ask_ai` is read both by the `ask`/`askr` shell functions and, directly, by the Dolphin menu entry and the terminal runner — the desktop session does not source your shell rc, and Konsole hands the command to an already running window without passing the launcher's environment, so both scripts would otherwise ignore these settings.

**Examples:**

```bash
export ASK_AI_MODEL="opencode/deepseek-v4-flash"
export ASK_AI_EFFORT="max"     # maximum reasoning effort
export ASK_AI_MODE="build"    # let the model edit files (default is plan)
export ASK_AI_AUTO_EXEC="0"    # never auto-run generated scripts
export ASK_AI_CLIPBOARD=1      # copy answer to clipboard
export GLOW_DISABLED=1
export ASK_AI_LOCALE="ru_RU"    # force Russian UI
export ASK_AI_THEME="dark"      # force dark theme
```

See [Localization](#localization) for locale details. The theme auto-detects from your KDE color scheme and works for both the dialog and the runner header.

### ACP harnesses

Queries go through ACP (Agent Client Protocol), so any harness that speaks it works out of the box — `opencode acp` is the default, and Gemini CLI, Claude Code, Codex, Qwen, Goose and others plug in with one variable:

```bash
export ASK_AI_AGENT="gemini"        # opencode (default), gemini, claude, codex, qwen, goose, copilot
export ASK_AI_PERMISSION="ask"     # y/N before tools that change files
export ASK_AI_HARNESS="cli"        # legacy `opencode run` path
```

| `ASK_AI_AGENT` | Command it starts | Install |
|---|---|---|
| `opencode` | `opencode acp` | `curl -fsSL https://opencode.ai/v2/install \| bash` |
| `gemini` | `gemini --experimental-acp` | `npm install -g @google/gemini-cli` |
| `claude` | `claude-agent-acp` | `npm install -g @agentclientprotocol/claude-agent-acp` |
| `codex` | `codex-acp` | `npm install -g @zed-industries/codex-acp` |
| `qwen` | `qwen --acp` | `npm install -g @qwen-code/qwen-code` |
| `goose` | `goose acp` | <https://block.github.io/goose> |
| `copilot` | `copilot --acp` | `npm install -g @github/copilot` |

A harness that is not in the table works through `ASK_AI_AGENT_CMD`; the runner only needs the binary on `PATH` and otherwise says so and prints the install command.

What maps onto what:

| Setting | ACP equivalent |
|---|---|
| `ASK_AI_MODEL` | `model` config option, when the agent exposes one |
| `ASK_AI_EFFORT` | `effort` / thought-level option, when the agent exposes one |
| `ASK_AI_MODE` | `mode` option (`plan` / `build`) |
| selected files | `resource_link` content blocks with absolute `file://` URIs |
| `ASK_AI_SAVE_DIR`, `ASK_AI_CLIPBOARD`, `ASK_AI_AUTO_EXEC` | unchanged — they work on the streamed Markdown |

Only the agent's answer text is printed, so the terminal stream, the saved `.md` and the script detection see clean Markdown; nothing buffers the answer, so it appears chunk by chunk instead of after the turn ends, and once it is complete `glow` renders it once more in place of the streamed text (unless `GLOW_DISABLED=1`). The stream runs on the terminal's alternate screen (the files/question/model header is printed there too, so it stays visible while the agent works), and leaving it replaces the streamed text completely whatever its length; the rendering goes through a temp file, so glow never probes the terminal and cannot stall; thoughts and tool calls go to stderr (see `ASK_AI_ACP_VERBOSE`). Unsupported options are reported and skipped instead of failing the query. With `ASK_AI_PERMISSION=ask` the runner asks `y/N` in the window before a tool may modify files (read-only tools are always allowed); without a terminal the answer is `no`. `ASK_AI_ACP_REUSE=1` continues the previous conversation in the same directory instead of starting over. If the agent needs a login, the runner tells you so and exits with code 3 — run the agent's login command in a terminal, then retry.

Diagnostics: `ASK_AI_ACP_TRACE=/tmp/acp.log` records every JSON-RPC message, and

```bash
python3 ~/.local/bin/ask-ai-acp-client.py --agent "gemini --experimental-acp" --probe
```

prints what an agent advertises (capabilities, auth methods, model/effort/mode options) without asking anything.

### `ask` / `askr` terminal functions

The installer sets these up automatically. After reopening your terminal, use them directly:

```bash
ask "Find bugs in this code"
askr "Show me the answer"
```

- `ask "..."` — streams the answer as it arrives, then shows it formatted through `glow`
- `ASK_AI_HARNESS=cli ask "..."` — legacy path, formatted through `glow`
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
4. Konsole opens — the answer streams into the window as it is generated, then appears formatted through `glow`
5. Press **Ctrl+C** or **Enter** to close the window

## Project structure

```
ask-ai-dolphin-context-menu/
├── src/
│   ├── ask-ai-common.sh           # Shared shell helpers (locale, file checks)
│   ├── ask-ai-dolphin.sh          # Entry point — dialog + terminal
│   ├── ask-ai-dolphin-run.sh      # Runner: ACP stream (glow for the CLI path), save, script confirm
│   └── ask-ai-dolphin-dialog.py   # Dialog: presets, history, multi-line input
├── servicemenu/
│   └── ask-ai-dolphin.desktop     # Dolphin service menu file
├── config/
│   ├── ask-ai-dolphin.cfg.example        # Example presets (EN)
│   └── ask-ai-dolphin.cfg.ru_RU.example  # Example presets (RU)
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
