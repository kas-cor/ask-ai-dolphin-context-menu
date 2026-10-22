# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Features

- **ACP is the default harness** — queries run through `ask-ai-acp-client.py` and any agent that speaks the Agent Client Protocol (`opencode acp` by default, `gemini --experimental-acp`, `claude-agent-acp`, `codex-acp`, …): model / effort / mode map onto the agent's own config options, selected files become `resource_link` blocks, tool permissions are denied by default except reads, and only the answer text reaches stdout so glow, `.md` saving and script detection keep working. `ASK_AI_AGENT_CMD`, `ASK_AI_PERMISSION` (`allow-read` / `ask` / `deny`), `ASK_AI_ACP_REUSE` (resume the previous session), `ASK_AI_ACP_VERBOSE`, `ASK_AI_ACP_TRACE` and `ASK_AI_ACP_IDLE_TIMEOUT` tune it; `ASK_AI_HARNESS=cli` (or the legacy `ASK_AI_ACP=0`) keeps the old `opencode run` path, and `--probe` prints what an agent advertises

### Bug Fixes

- `ASK_AI_LOCALE=ru_RU` / `en_EN` is honoured again — the value was lower-cased and then compared against mixed case, so the documented full forms fell through to `$LANG`
- `./install.sh ru_RU` installs the Russian UI (the argument was lower-cased before matching `ru_RU`)
- Cancelling the dialog exits with 0 instead of aborting the entry script under `set -e`; a crashed dialog now reports its log path
- Without `file(1)`, text files are detected again instead of every file being treated as binary
- `~/.ask_ai` is read on the Dolphin path — by the entry script and by the runner — so model / mode / locale / save-dir settings apply to the menu, not only to `ask` / `askr` (Konsole does not pass the launcher's environment to an already running window; values already present in the environment still win)
- A multi-line query is stored as a single history entry; the history file is written atomically
- `$TERMINAL` may carry arguments (`konsole --hold`), and a failing runner no longer opens a second terminal window
- A failed `opencode` run no longer leaves a partial `.md` in `ASK_AI_SAVE_DIR`
- The Dolphin window still waits for Enter — the pause flag is now passed on the terminal command line, because Konsole hands the request to an already running instance and never inherits the launcher's environment (`ask` / `askr` still return to the prompt immediately)
- Non-numeric `ASK_AI_MAX_ATTACH_*` values fall back to the defaults instead of silently dropping attachments
- Paths starting with `-` are no longer passed to `opencode -f` as flags; CRLF preset configs are parsed correctly
- The model catalog for `ASK_AI_EFFORT` is cached for a day instead of being fetched on every query
- The installer no longer keeps a second copy of the locale strings (it had already drifted), copies every shipped locale, escapes `$HOME` in the generated `.desktop`, and warns about `opencode` v1

## [1.2.1](https://github.com/kas-cor/ask-ai-dolphin-context-menu/compare/v1.2.0...v1.2.1) (2026-10-12)


### Bug Fixes

* code review follow-up on v1.2.0 — strict mode + slug sanitize ([fcef647](https://github.com/kas-cor/ask-ai-dolphin-context-menu/commit/fcef6470b5020fa3ddd25e6a6e92de4add9e80c3))
* make script save and opencode launch reliable on real v2 setups ([1213bcd](https://github.com/kas-cor/ask-ai-dolphin-context-menu/commit/1213bcdcbeb8519a69df6160e57899932929d5d5))
* pass explicit --agent to opencode run to avoid v2 duplicate turn ([5566c0e](https://github.com/kas-cor/ask-ai-dolphin-context-menu/commit/5566c0e3ddeb628784d98b99ef79dec1304d557e))
* use printf for file/query display to prevent ANSI injection via paths ([84c7392](https://github.com/kas-cor/ask-ai-dolphin-context-menu/commit/84c7392993d48dc90dd2994b09a87ec4e7c2ef0c))

## [1.2.0](https://github.com/kas-cor/ask-ai-dolphin-context-menu/compare/v1.1.0...v1.2.0) (2026-07-16)


### Features

* add ASK_AI_EFFORT and ASK_AI_MODE env vars ([33c443a](https://github.com/kas-cor/ask-ai-dolphin-context-menu/commit/33c443a29edaedc1efcdd194b075d8c950a5c5f4))
* add ASK_AI_SAVE_DIR and auto-executable scripts ([a09fa0e](https://github.com/kas-cor/ask-ai-dolphin-context-menu/commit/a09fa0eb8a6a2b780c706fe83cf077c2cc93bf8f))
* add file attachments, query history, terminal fallback, and safe script handling ([b2d32a2](https://github.com/kas-cor/ask-ai-dolphin-context-menu/commit/b2d32a2b5a3665a27d21da49301692e3ab62c96a))
* initial release v1.0.0 ([14b09b5](https://github.com/kas-cor/ask-ai-dolphin-context-menu/commit/14b09b5e6c08db17087477096061037fc5e622fa))

## [1.1.0] — 2026-06-08

### 🚀 New Features

- **`ASK_AI_SAVE_DIR`** — save AI responses to a directory (creates `<query-slug>-<timestamp>.md` files)
- **Script auto-execution** — if AI response starts with `#!/bin/bash`, the runner saves it as `.sh`, makes it executable, and runs it automatically
- **Script persistence** — executable scripts are saved alongside the output (`.sh` next to `.md`)
- **Smart slug generation** — filenames derived from query text (supports English & Russian via Python)

### 📖 Documentation

- New **Use Cases** section in README (EN/RU) with developer and non-developer scenarios
- Image batch processing, collage/slideshow, crop-to-aspect-ratio examples documented

### ⚙️ Configuration

- `ASK_AI_SAVE_DIR` — set to a directory path (e.g., `~/ask-ai-results`) to persist all AI responses

### 🧪 CI & Testing

- New `test-runner-save.sh` — 20 tests covering shebang detection, slug generation, script save/exec, `ASK_AI_SAVE_DIR`, locale keys, and fallback defaults
- Locale files now have 48 keys each (+ `runner_lbl_saved`, `runner_lbl_executing`, `runner_lbl_script_saved`, `runner_lbl_script_failed`)

### 🌐 Localization

- 4 new locale keys for save/script-execution messages (EN + RU)
- Updated preset configs with non-programmer use cases (EN: `ask-ai-dolphin.cfg.example`, RU: `ask-ai-dolphin.cfg.ru_RU.example`)

## [1.0.0] — 2026-06-03

### 🚀 Initial release

Ask AI Dolphin Context Menu — AI assistant for KDE Dolphin file manager.

- KDE Dolphin context menu integration via service menu
- PyQt5 dialog with configurable preset queries and custom input
- Streaming AI response through `glow` Markdown formatter in Konsole
- Adaptive dark/light theme (auto-detected from system palette)
- `ask` / `askr` shell functions for terminal usage

### 🌐 Localization

- English and Russian UI (auto-detected from `$LANG`)
- Locale files: `locales/en_EN` and `locales/ru_RU` (44 keys each)
- Locale validation in CI (UTF-8, format, cross-file key parity)
- Russian documentation (`README_ru.md`)

### ⚙️ Configuration

- `ASK_AI_MODEL` — model selection (default: `opencode/deepseek-v4-flash-free`)
- `ASK_AI_LOCALE` — language override (`ru_RU` / `en_EN`)
- `ASK_AI_THEME` — theme override (`dark` / `light`, with `d`/`l` shortcuts)
- `GLOW_DISABLED` — disable Markdown formatting
- `~/.ask_ai` auto-created on install with conditional sourcing in `.bashrc`/`.zshrc`
- `~/.config/ask-ai-dolphin.cfg` for preset queries (last 8 shown)

### 🧪 CI & Testing

- Shell syntax check (4 scripts)
- Python syntax check (dialog + CI scripts)
- Locale file validation
- Qt `setFamilies()` compatibility test (Qt ≥ 5.13 / fallback for < 5.13)
- `ASK_AI_THEME` style selection test (6 tests)
- Release Please workflow for automated versioning

### 📦 Installation

- One-liner: `curl ... install.sh | bash`
- Local: `git clone && ./install.sh`
- Works via curl pipe mode (no cloning needed)
- Uninstall: `curl ... uninstall.sh | bash`
- Dependency checks in install script

### 🏗️ Infrastructure

- License: MIT
- AGENTS.md for AI coding assistants
- GitHub badges (CI, License, Release, Platform)
- CONTRIBUTING.md with conventional commits guide
