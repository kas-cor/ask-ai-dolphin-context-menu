# AGENTS.md — Project Description for AI Agents

This document helps AI coding assistants (like Codebuff, Cursor, Claude, etc.) understand the structure and conventions of this project.

## Project Overview

**Ask AI Dolphin Context Menu** integrates an AI assistant into the KDE Dolphin file manager via a right-click context menu.

**Stack:** Bash · Python 3 / PyQt5 · opencode CLI

## Architecture

```
User selects files in Dolphin
       │
       ▼
ask-ai-dolphin.desktop (service menu)
       │  Exec: ask-ai-dolphin.sh %F
       ▼
ask-ai-dolphin.sh  — reads config, launches PyQt5 dialog
       │
       ├── PyQt5 dialog (ask-ai-dolphin-dialog.py)
       │     Shows preset buttons + custom input field
       │     Sends query via stdout
       │
       ▼
ask-ai-dolphin-run.sh  — streams AI response through glow/opencode
       │
       ▼
Konsole window — user sees formatted Markdown output
```

## Key Files

| File | Purpose |
|---|---|
| `src/ask-ai-dolphin.sh` | Entry point: reads config, launches dialog, opens Konsole |
| `src/ask-ai-dolphin-run.sh` | Runner: pipes query to opencode, streams through glow |
| `src/ask-ai-dolphin-dialog.py` | PyQt5 dialog with preset buttons + text input (i18n: EN/RU) |
| `servicemenu/ask-ai-dolphin.desktop` | KDE service menu definition (i18n: EN/RU via `Name[ru]`) |
| `config/ask-ai-dolphin.cfg.example` | Example presets config (English) |
| `config/ask-ai-dolphin.cfg.ru_RU.example` | Example presets config (Russian) |
| `dot-ask_ai/dot-ask_ai.example` | Example ~/.ask_ai for shell functions |
| `locales/en_EN` | English locale file (key=value pairs for all components) |
| `locales/ru_RU` | Russian locale file (key=value pairs for all components) |
| `install.sh` | Install script with i18n (EN/RU), locale detection, locale-based config copy |
| `uninstall.sh` | Uninstall script (self-contained) |

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `ASK_AI_MODEL` | `opencode/deepseek-v4-flash-free` | AI model for opencode. List: `opencode models` |
| `GLOW_DISABLED` | unset | Set to `1` for raw output without glow formatting (`askr`) |
| `ASK_AI_LOCALE` | auto-detect (system `$LANG`) | Force UI language: `ru_RU` / `en_EN` |
| `ASK_AI_THEME` | auto-detect (system palette) | Force UI theme: `dark` / `light` |

## Data Flow

1. Dolphin calls `ask-ai-dolphin.sh %F` with selected file paths
2. `ask-ai-dolphin.sh` reads presets from `~/.config/ask-ai-dolphin.cfg`
3. Launches `ask-ai-dolphin-dialog.py` with preset list on CLI args and file info on stdin
4. Dialog prints chosen query to stdout (exit 0 = OK, exit 1 = Cancel)
5. On confirmation, opens `konsole -e ask-ai-dolphin-run.sh "<query>" <files...>`
6. Runner builds a prompt, calls `opencode run` and pipes through `glow` (unless `GLOW_DISABLED=1`)

## Config Presets

Located at `~/.config/ask-ai-dolphin.cfg`. One query per line, `#` for comments. Only the last **8 presets** are shown in the dialog (to keep the UI compact). If the file is missing, built-in fallbacks are used:

```
Describe these files
Find bugs in these files
Optimize this code
Review code quality
Generate documentation
Refactor this code
Write tests for these files
```

### Locale-based config selection

During installation, `install.sh` copies the appropriate config file based on detected locale:

- **ru_RU** → `config/ask-ai-dolphin.cfg.ru_RU.example` (Russian presets)
- **en_EN / other** → `config/ask-ai-dolphin.cfg.example` (English presets)

The existing config is never overwritten on reinstall.

## Terminal Functions

The `~/.ask_ai` file provides two shell functions (created automatically by `install.sh`):

- `ask "..."` — sends query with current directory as context, streams through glow
- `askr "..."` — same but raw output (no glow formatting)

The installer also adds `source ~/.ask_ai` to the user's shell config (`.bashrc` / `.zshrc`).

## Coding Conventions

- **Conventional Commits:** All commits must follow `<type>: <description>` format. See [CONTRIBUTING.md](./CONTRIBUTING.md) for details. Types: `feat` (minor), `fix` (patch), `BREAKING CHANGE` (major), plus `docs`, `chore`, `refactor`, `test`, `ci`, `style`, `perf` (no release)
- **Shell scripts:** `#!/bin/bash` (`install.sh`/`uninstall.sh` use `set -euo pipefail`; runner scripts relax strict mode for interactive use)
- **Python:** PEP 8, PyQt5 for GUI
- **Config files:** One item per line, `#` for comments
- **Paths:** Use `SCRIPT_DIR` or `@HOME@` placeholder, never hardcode absolute paths
- **Install:** `install.sh` copies to `~/.local/bin/` + `~/.local/share/kio/servicemenus/`, creates `~/.ask_ai` and adds `source ~/.ask_ai` to shell config
- **i18n (localization):**
  - **Locale files:** All strings are stored in `locales/en_EN` and `locales/ru_RU` as `KEY="VALUE"` pairs. Files are sourced by shell scripts and parsed by Python. Copied to `~/.local/bin/locales/` during install. Key prefixes:
    - `install_*` — installer messages (`install.sh`)
    - `runner_*` — runner labels and messages (`ask-ai-dolphin-run.sh`)
    - `dialog_*` — PyQt5 dialog UI strings (`ask-ai-dolphin-dialog.py`)
    - `sh_*` — shell entry point headers (`ask-ai-dolphin.sh`)
  - **Script loading mechanism:** Each script detects locale (same priority: `ASK_AI_LOCALE` → `$LANG` → `en_EN`) and loads the locale file from `$(dirname $0)/locales/$LOCALE`. Fallback to inline hardcoded strings if the locale file is not available (e.g., curl pipe mode)
  - **Documentation:** English (`README.md`) and Russian (`README_ru.md`)
  - **Installer (`install.sh`):** All messages translated. Locale detection priority: CLI arg → `$LANG` → `en_EN`. Russian detected from `ru_RU*`, `ru_UA*`, `be_BY*`, `uk_UA*`. Override: `./install.sh ru_RU` or `curl ... | bash -s ru_RU`
  - **Shell entry point (`ask-ai-dolphin.sh`):** Header labels for file info (`sh_lbl_selected_files`, `sh_lbl_current_dir`) localized. Passed as piped text to the dialog ($FILE_LIST)
  - **Runner (`ask-ai-dolphin-run.sh`):** Konsole header, file/query labels, model label, streaming status, completion message, fallback query — all via `runner_*` keys with `${var:-default}` fallback
  - **PyQt5 dialog (`ask-ai-dolphin-dialog.py`):** All UI strings (title, labels, buttons, placeholders) via `dialog_*` keys. Fallback via `_("key", "default")` function. Parses locale file with `KEY="VALUE"` format
  - **Service menu (`ask-ai-dolphin.desktop`):** KDE native localization via `Name[ru]="🤖 Спросить AI"` — KDE automatically selects the right name based on system locale; no script changes needed
  - **Config presets:** `config/ask-ai-dolphin.cfg.example` (EN) and `config/ask-ai-dolphin.cfg.ru_RU.example` (RU); auto-selected by locale during install
  - **Locale detection:** Priority for all components: `ASK_AI_LOCALE` env var → `$LANG` → `en_EN`. Russian detected from `ru_RU*`, `ru_UA*`, `be_BY*`, `uk_UA*`. Override with `./install.sh ru_RU` or set `ASK_AI_LOCALE=ru_RU` in `~/.ask_ai`
  - **Adding a new locale:** Create `locales/xx_XX` with all keys translated, add locale code to `detect_locale()`/case blocks in all 4 scripts (`install.sh`, `ask-ai-dolphin.sh`, `ask-ai-dolphin-run.sh`, `ask-ai-dolphin-dialog.py`), optionally create a preset config `config/ask-ai-dolphin.cfg.xx_XX.example` and update `install.sh` config selection logic, add `Name[xx]` to `.desktop` file

## CI Tests

Located in `.github/scripts/`, run on every push/PR via `.github/workflows/ci.yml`.

| File | Purpose |
|---|---|
| `validate-locales.py` | Validates locale files: UTF-8, `KEY="value"` format, no duplicates, cross-file key parity |
| `test-qt-compat.py` | Tests `setFamilies()` try/except fallback for Qt < 5.13: normal path, mock fallback, real code path |
| `test-ask-theme.py` | Tests `ASK_AI_THEME=dark\|light\|d\|l` selection (case-insensitive), auto-detect from palette, `STYLE_DARK ≠ STYLE_LIGHT` |

CI pipeline: `Shell syntax` → `Python syntax` → `Locale validation` → `Install PyQt5` → `Qt compat test` → `ASK_AI_THEME test`.
