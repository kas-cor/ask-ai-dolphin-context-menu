# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1](https://github.com/kas-cor/ask-ai-dolphin-context-menu/compare/ask-ai-dolphin-context-menu-v1.1.0...ask-ai-dolphin-context-menu-v1.1.1) (2026-06-03)


### Bug Fixes

* use conditional sourcing [[ -f ~/.ask_ai ]] && . ~/.ask_ai in shell config ([77b7dcc](https://github.com/kas-cor/ask-ai-dolphin-context-menu/commit/77b7dcc1ceabc5fd3336e196a33f81124290e9b6))

## [1.1.0] — 2026-06-03

### 🎨 Added
- **Dark/Light theme support** for PyQt5 dialog — auto-detected from KDE color scheme
- **Adaptive runner header** — `ask-ai-dolphin-run.sh` now uses bright colors on dark backgrounds
- New `ASK_AI_THEME` env var (`dark` / `light`) with `d` / `l` shortcuts (case-insensitive)

### 🌐 Changed
- **Renamed all env vars** (`ASK_` → `ASK_AI_`): `ASK_MODEL` → `ASK_AI_MODEL`, `ASK_LOCALE` → `ASK_AI_LOCALE`, `ASK_THEME` → `ASK_AI_THEME`, `ASK_PRESETS` → `ASK_AI_PRESETS`
- **Renamed all files** (`ask-dolphin` → `ask-ai-dolphin`): scripts, desktop file, config files

### 🧪 Added (CI & Testing)
- Qt `setFamilies()` compatibility test (validates try/except fallback for Qt < 5.13)
- `ASK_AI_THEME` style selection test (6 tests: dark/light, case-insensitive, palette auto-detect)
- Locale file validation (UTF-8, format, cross-file key parity) — 44 keys in en_EN and ru_RU

### 🐛 Fixed
- `setFamilies()` wrapped in `try/except AttributeError` for Qt < 5.12 compatibility
- `\n` literal display in dialog — now renders actual emoji and newlines correctly
- Locale file path fallback for source vs installed paths
- Shell `case` syntax error in `ask-ai-dolphin-run.sh` (semicolon inside regex)
- `detect_dark_theme()` now handles single-letter shortcuts (`d`/`l`) matching the shell script behavior

### 📄 Documentation
- README.md and README_ru.md: env var table, CI badges, locale contributing guide
- AGENTS.md: comprehensive i18n section, CI Tests section, env var sync with README
- dot-ask_ai.example: `GLOW_DISABLED` documented as permanent env var, `ASK_AI_LOCALE`, `ASK_AI_THEME` examples
- Environment variable table added to both README.md and README_ru.md

## [1.0.0] — 2026-06-03

### 🚀 Initial release
- KDE Dolphin context menu integration via service menu
- PyQt5 dialog with configurable preset queries and custom input
- Streaming AI response through `glow` Markdown formatter in Konsole
- `ask` / `askr` shell functions for terminal usage (streaming through the runner script)

### 🌐 Localization
- English and Russian UI (auto-detected from `$LANG`)
- Locale files: `locales/en_EN` and `locales/ru_RU` (44 keys each)
- Russian preset config (`ask-ai-dolphin.cfg.ru_RU.example`)
- Russian service menu name in `.desktop` file (`Name[ru]`)
- Russian documentation (`README_ru.md`)

### ⚙️ Configuration
- `ASK_MODEL` env var for model selection
- `ASK_LOCALE` env var for language override
- `~/.ask_ai` auto-created on install with `source` in shell config
- `~/.config/ask-ai-dolphin.cfg` for preset queries (last 8 shown)

### 📦 Installation
- One-liner: `curl ... install.sh | bash`
- Local: `git clone && ./install.sh`
- Works via curl pipe mode (no cloning needed)
- Uninstall: `curl ... uninstall.sh | bash`
- Dependency checks in install script

### 🧪 CI
- GitHub Actions: shell syntax, Python syntax checks
- Locale validation

### 🏗️ Infrastructure
- License: MIT
- AGENTS.md for AI coding assistants
- GitHub badges (CI, License, Release, Platform)

[1.1.0]: https://github.com/kas-cor/ask-ai-dolphin-context-menu/releases/tag/v1.1
[1.0.0]: https://github.com/kas-cor/ask-ai-dolphin-context-menu/releases/tag/v1.0
