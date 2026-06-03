# 🤖 Ask AI — Dolphin Context Menu

Интеграция AI-ассистента в контекстное меню файлового менеджера **Dolphin** (KDE Plasma).

Позволяет выделить файлы/папки → правый клик → **Ask AI** → выбрать пресет или ввести свой запрос → получить ответ с форматированием в Konsole.

## Возможности

- **Пресеты запросов** — настраиваемый список быстрых запросов (на русском)
- **Произвольный запрос** — поле ввода для своего вопроса
- **Выбор модели** — через переменную `ASK_MODEL` (по умолчанию бесплатная `opencode/deepseek-v4-flash-free`)
- **Стриминг ответа** — ответ выводится через `glow` с подсветкой Markdown в реальном времени
- **Работа без выделения** — если ничего не выделено, передаётся текущая директория
- **PyQt5 диалог** — красивый интерфейс в стиле KDE Breeze

## Зависимости

- **KDE Plasma** (Dolphin, Konsole, kdialog)
- **Python 3 + PyQt5**
- **[opencode](https://opencode.ai)** — CLI для AI-моделей
- **glow** (опционально) — форматированный вывод Markdown

### Установка зависимостей (Arch Linux)

```bash
sudo pacman -S python-pyqt5 kdialog konsole
yay -S glow-bin  # или sudo pacman -S glow, если есть в репозиториях
# opencode — установите по документации https://opencode.ai
```

## Установка

### Одной строкой (curl | bash)

```bash
curl -s https://raw.githubusercontent.com/kas-cor/ask_ai_dolphin_context_menu/main/install.sh | bash
```

Скрипт сам скачает проект из GitHub и выполнит установку. Ничего клонировать не нужно.

### Удаление одной строкой

```bash
curl -s https://raw.githubusercontent.com/kas-cor/ask_ai_dolphin_context_menu/main/uninstall.sh | bash
```

### Локальная установка (git clone)

```bash
git clone https://github.com/kas-cor/ask_ai_dolphin_context_menu.git
cd ask_ai_dolphin_context_menu
./install.sh
```

После установки (любым способом) перезапустите Dolphin: **Ctrl+Shift+R**

## Настройка

### Пресеты запросов

Отредактируйте файл `~/.config/ask-dolphin.cfg`:

```bash
nano ~/.config/ask-dolphin.cfg
```

— один запрос на строку, строки с `#` игнорируются.

### Модель AI

Добавьте в `~/.ask_ai` (или `~/.bashrc`):

```bash
export ASK_MODEL="opencode/deepseek-v4-flash-free"
```

Список доступных моделей: `opencode models`

Примеры:
- `opencode/deepseek-v4-flash-free` — бесплатная (по умолчанию)
- `opencode/deepseek-v4-flash`
- `opencode/claude-sonnet-4-6`
- `opencode/claude-haiku-4-5`
- `opencode/gpt-5.4-pro`
- `opencode/gemini-3.5-flash`
- `opencode/qwen3.5-plus`

### Функции `ask` / `askr` (терминал)

В `~/.ask_ai` можно добавить функции для быстрых запросов из терминала:

```bash
source ~/.ask_ai
ask "Найди баги в этом коде"
askr "Просто покажи ответ"
```

Пример `~/.ask_ai` можно взять прямо из репозитория:

```bash
curl -s https://raw.githubusercontent.com/kas-cor/ask_ai_dolphin_context_menu/main/dot-ask_ai/dot-ask_ai.example > ~/.ask_ai
```

## Использование

1. Выделите один или несколько файлов/папок в Dolphin
2. Правый клик → **🤖 Ask AI**
3. Выберите пресет (сразу отправит запрос) или введите свой вопрос и нажмите **Отправить**
4. Откроется Konsole — ответ стримится через `glow`
5. Нажмите **Ctrl+C** или **Enter**, чтобы закрыть окно

## Структура проекта

```
ask_ai_dolphin_context_menu/
├── src/
│   ├── ask-dolphin.sh          # Входная точка — PyQt5 диалог + Konsole
│   ├── ask-dolphin-run.sh      # Раннер: стриминг opencode через glow
│   └── ask-dolphin-dialog.py   # PyQt5 диалог с пресетами и полем ввода
├── servicemenu/
│   └── ask-dolphin.desktop     # Сервис-меню для Dolphin
├── config/
│   └── ask-dolphin.cfg.example # Пример конфига с пресетами
├── dot-ask_ai/
│   └── dot-ask_ai.example      # Пример ~/.ask_ai
├── install.sh                  # Скрипт установки (работает и через curl)
├── uninstall.sh                # Скрипт удаления (работает и через curl)
└── README.md                   # Этот файл
```

## Лицензия

MIT
