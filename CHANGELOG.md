# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0](https://github.com/kas-cor/ask-ai-dolphin-context-menu/compare/v1.1.0...v1.2.0) (2026-07-16)


### Features

* add ASK_AI_EFFORT and ASK_AI_MODE env vars ([33c443a](https://github.com/kas-cor/ask-ai-dolphin-context-menu/commit/33c443a29edaedc1efcdd194b075d8c950a5c5f4))
* add ASK_AI_SAVE_DIR and auto-executable scripts ([a09fa0e](https://github.com/kas-cor/ask-ai-dolphin-context-menu/commit/a09fa0eb8a6a2b780c706fe83cf077c2cc93bf8f))
* add file attachments, query history, terminal fallback, and safe script handling ([b2d32a2](https://github.com/kas-cor/ask-ai-dolphin-context-menu/commit/b2d32a2b5a3665a27d21da49301692e3ab62c96a))
* initial release v1.0.0 ([14b09b5](https://github.com/kas-cor/ask-ai-dolphin-context-menu/commit/14b09b5e6c08db17087477096061037fc5e622fa))

## [Unreleased]

### Security

- **Script auto-execution is no longer automatic by default** — shebang responses are saved as `.sh`, then you are prompted `Run this script? [y/N]`. Use `ASK_AI_AUTO_EXEC=1` to always run, or `0`/`never` to never run.

### Features

- **File attachments** — selected text files are passed to `opencode run -f` (limits: `ASK_AI_MAX_ATTACH_BYTES`, `ASK_AI_MAX_ATTACH_FILES`); directories get a short listing in the prompt
- **Multi-line query input** and **recent query history** (`~/.config/ask-ai-dolphin.history`)
- **Model / effort / mode** shown in the dialog header
- **Terminal fallback** — `$TERMINAL` → konsole → kgx / gnome-terminal / xterm → current TTY
- **Optional clipboard copy** via `ASK_AI_CLIPBOARD=1` (wl-copy / xclip / xsel)
- **PyQt6 fallback** if PyQt5 is not installed
- **Shared `ask-ai-common.sh`** for locale detection and helpers
- **Locale-aware built-in presets** when config is missing (EN/RU)
- **Installer** prefers `$SHELL` rc file; notes for fish; hints when `~/.ask_ai` already exists
- **Uninstaller** removes `ask-ai-common.sh` and installed locale files

### Fixes

- Report `opencode` failures (`pipefail` + status message)
- Dynamic-width runner header for long localized titles
- Avoid `echo -e` on file paths; safer `printf` in installer
- Rename install path vs script-output dir (`INSTALL_DIR` / `SCRIPT_OUT_DIR`)

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
