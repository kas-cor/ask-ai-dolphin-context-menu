# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0](https://github.com/kas-cor/ask-ai-dolphin-context-menu/compare/v1.1.0...v1.2.0) (2026-06-08)


### Features

* add ASK_AI_SAVE_DIR and auto-executable scripts ([a09fa0e](https://github.com/kas-cor/ask-ai-dolphin-context-menu/commit/a09fa0eb8a6a2b780c706fe83cf077c2cc93bf8f))
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
