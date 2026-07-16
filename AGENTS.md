# AGENTS.md — Project Description for AI Agents

This document helps AI coding assistants (like Codebuff, Cursor, Claude, etc.) understand the structure and conventions of this project.

## Project Overview

**Ask AI Dolphin Context Menu** integrates an AI assistant into the KDE Dolphin file manager via a right-click context menu.

**Stack:** Bash · Python 3 / PyQt5 (PyQt6 fallback) · opencode CLI

## Architecture

```
User selects files in Dolphin
       │
       ▼
ask-ai-dolphin.desktop (service menu)
       │  Exec: ask-ai-dolphin.sh %F
       ▼
ask-ai-dolphin.sh  — reads config, launches dialog, opens terminal
       │
       ├── ask-ai-dolphin-dialog.py (PyQt5/6)
       │     Presets + history + multi-line input
       │     Sends query via stdout
       │
       ▼
ask-ai-dolphin-run.sh  — attaches files (-f), streams via opencode/glow
       │
       ▼
Terminal ($TERMINAL / konsole / fallback) — formatted Markdown output
```

## Key Files

| File | Purpose |
|---|---|
| `src/ask-ai-common.sh` | Shared helpers: locale detect/load, text-file check, dir listing |
| `src/ask-ai-dolphin.sh` | Entry point: config, dialog, terminal launch |
| `src/ask-ai-dolphin-run.sh` | Runner: opencode + glow, save, script confirm |
| `src/ask-ai-dolphin-dialog.py` | Dialog: presets, history, multi-line input (i18n EN/RU) |
| `servicemenu/ask-ai-dolphin.desktop` | KDE service menu (`Name[ru]`) |
| `config/ask-ai-dolphin.cfg.example` | Example presets (EN) |
| `config/ask-ai-dolphin.cfg.ru_RU.example` | Example presets (RU) |
| `dot-ask_ai/dot-ask_ai.example` | Example `~/.ask_ai` |
| `locales/en_EN` / `locales/ru_RU` | Locale KEY="value" files |
| `install.sh` / `uninstall.sh` | Installer / uninstaller |

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `ASK_AI_MODEL` | `opencode/deepseek-v4-flash-free` | AI model for opencode. List: `opencode models` |
| `ASK_AI_EFFORT` | unset | Reasoning effort (`--variant`). Values: `high`, `max`, `minimal` |
| `ASK_AI_MODE` | unset | Agent mode (`--agent`). Built-in: `plan`, `build` |
| `ASK_AI_SAVE_DIR` | unset | Save responses as `<query-slug>-<timestamp>.md` |
| `ASK_AI_AUTO_EXEC` | `prompt` | Script run policy: `prompt` (ask y/N), `1`/`always`, `0`/`never` |
| `ASK_AI_CLIPBOARD` | unset | Set `1` to copy response to clipboard (wl-copy/xclip/xsel) |
| `ASK_AI_MAX_ATTACH_BYTES` | `204800` | Max size per file attached via `opencode -f` |
| `ASK_AI_MAX_ATTACH_FILES` | `20` | Max number of attached text files |
| `GLOW_DISABLED` | unset | Set `1` for raw output without glow (`askr`) |
| `ASK_AI_LOCALE` | auto (`$LANG`) | Force UI language: `ru_RU` / `en_EN` |
| `ASK_AI_THEME` | auto (palette / COLORFGBG) | Force UI theme: `dark` / `light` |
| `TERMINAL` | unset | Preferred terminal (takes priority over konsole) |

## Data Flow

1. Dolphin calls `ask-ai-dolphin.sh %F` with selected file paths
2. Entry script sources `ask-ai-common.sh`, loads locale, reads presets from `~/.config/ask-ai-dolphin.cfg` (locale-aware built-in fallbacks if missing)
3. Launches dialog with presets on argv and file info on stdin
4. Dialog prints query to stdout (0 = OK, 1 = Cancel); saves to `~/.config/ask-ai-dolphin.history`
5. Opens terminal with `ask-ai-dolphin-run.sh "<query>" <files...>` (`$TERMINAL` → konsole → kgx/gnome-terminal/xterm → inline TTY)
6. Runner attaches readable text files via `opencode run -f …`, streams through `glow` (unless `GLOW_DISABLED=1`)
7. If response is a shebang script: save `.sh`, then run only per `ASK_AI_AUTO_EXEC` (default: confirm)

## Config Presets

Located at `~/.config/ask-ai-dolphin.cfg`. One query per line, `#` for comments. Only the last **8 presets** are shown. Missing config uses EN or RU built-in fallbacks based on locale.

Query history: `~/.config/ask-ai-dolphin.history` (last 10).

## Terminal Functions

`~/.ask_ai` (created by installer):

- `ask "..."` — query with PWD as context, through glow
- `askr "..."` — raw output

Installer adds `source ~/.ask_ai` to the rc file for `$SHELL` (zsh → `.zshrc`, bash → `.bashrc`, etc.).

## Coding Conventions

- **Conventional Commits:** `<type>: <description>` — see CONTRIBUTING.md
- **Shell:** `#!/bin/bash`; install/uninstall use `set -euo pipefail`
- **Python:** PEP 8; PyQt5 preferred, PyQt6 fallback
- **Paths:** `INSTALL_DIR` / `@HOME@`, never hardcode absolute user paths in sources
- **Shared shell helpers:** live in `src/ask-ai-common.sh`; install copies it to `~/.local/bin/`
- **i18n:** locale files `KEY="VALUE"`; prefixes `install_*`, `runner_*`, `dialog_*`, `sh_*`
- **Locale detection:** shared via `ask_ai_detect_locale` / dialog `detect_locale()` — `ASK_AI_LOCALE` → `$LANG` → `en_EN`; Russian from `ru_RU*`, `ru_UA*`, `be_BY*`, `uk_UA*`
- **Adding a locale:** new file in `locales/`, extend `ask_ai_detect_locale` + Python `detect_locale`, optional preset config + `Name[xx]` in `.desktop`, update install config selection

## Security notes

- AI-generated scripts are **not** auto-run by default (`ASK_AI_AUTO_EXEC=prompt`)
- Only text-like files under size/count limits are attached with `-f`
- Do not reintroduce always-on auto-exec without an opt-in flag

## CI Tests

Located in `.github/scripts/`, run via `.github/workflows/ci.yml`.

| File | Purpose |
|---|---|
| `validate-locales.py` | Locale format, UTF-8, key parity |
| `test-qt-compat.py` | `setFamilies()` fallback for Qt &lt; 5.13 |
| `test-ask-theme.py` | `ASK_AI_THEME` + STYLE_DARK ≠ STYLE_LIGHT |
| `test-runner-save.sh` | Shebang, slug, AUTO_EXEC matrix, common.sh, attach limits |

CI pipeline: Shell syntax → Python syntax → Locale validation → PyQt5 → Qt compat → ASK_AI_THEME → Runner tests.
