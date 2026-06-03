> **🌐 English version available:** [README.md](./README.md)

<div align="center">

# 🤖 Спросить AI — Dolphin Context Menu

[![CI](https://github.com/kas-cor/ask-ai-dolphin-context-menu/actions/workflows/ci.yml/badge.svg)](https://github.com/kas-cor/ask-ai-dolphin-context-menu/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub Release](https://img.shields.io/github/v/release/kas-cor/ask-ai-dolphin-context-menu)](https://github.com/kas-cor/ask-ai-dolphin-context-menu/releases)
[![Platform](https://img.shields.io/badge/Platform-Linux--KDE-blue)](https://kde.org)

Интеграция AI-ассистента в контекстное меню файлового менеджера **Dolphin** (KDE Plasma).

</div>

Позволяет выделить файлы/папки → правый клик → **🤖 Спросить AI** → выбрать пресет или ввести свой запрос → получить ответ с форматированием в Konsole.

## Возможности

- **Пресеты запросов** — настраиваемый список быстрых запросов
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
curl -s https://raw.githubusercontent.com/kas-cor/ask-ai-dolphin-context-menu/main/install.sh | bash
```

Скрипт сам скачает проект из GitHub и выполнит установку. Ничего клонировать не нужно.

### Удаление одной строкой

```bash
curl -s https://raw.githubusercontent.com/kas-cor/ask-ai-dolphin-context-menu/main/uninstall.sh | bash
```

### Локальная установка (git clone)

```bash
git clone https://github.com/kas-cor/ask-ai-dolphin-context-menu.git
cd ask-ai-dolphin-context-menu
./install.sh
```

После установки (любым способом) перезапустите Dolphin: **Ctrl+Shift+R**

## Настройка

### Пресеты запросов

Отредактируйте файл `~/.config/ask-dolphin.cfg`:

```bash
nano ~/.config/ask-dolphin.cfg
```

— один запрос на строку, строки с `#` игнорируются. В диалоге показываются только последние **8 пресетов**.

### Переменные окружения

Установщик автоматически создаёт `~/.ask_ai` с моделью по умолчанию и добавляет `source ~/.ask_ai` в ваш shell config (`.bashrc` / `.zshrc`).

Отредактируйте `~/.ask_ai` чтобы настроить:

```bash
nano ~/.ask_ai
# Поменяйте ASK_MODEL на любую доступную модель
# Раскомментируйте ASK_LOCALE или ASK_THEME
```

| Переменная | По умолчанию | Описание |
|---|---|---|
| `ASK_MODEL` | `opencode/deepseek-v4-flash-free` | Модель AI для opencode. Список: `opencode models` |
| `GLOW_DISABLED` | пусто | Установите `1` для вывода без glow-форматирования (`askr`) |
| `ASK_LOCALE` | авто (системный `$LANG`) | Язык интерфейса: `ru_RU` / `en_EN` |
| `ASK_THEME` | авто (системная палитра) | Тема оформления: `dark` / `light` |

**Примеры:**

```bash
export ASK_MODEL="opencode/deepseek-v4-flash"
export GLOW_DISABLED=1
export ASK_LOCALE="ru_RU"    # принудительно русский
export ASK_THEME="dark"      # принудительно тёмная тема
```

Подробнее о языке в разделе [Локализация](#локализация). Тема определяется автоматически из цветовой схемы KDE и работает как для PyQt5 диалога, так и для заголовка раннера в Konsole.

### Функции `ask` / `askr` (терминал)

Установщик настраивает их автоматически. После перезапуска терминала используйте напрямую:

```bash
ask "Найди баги в этом коде"
askr "Просто покажи ответ"
```

- `ask "..."` — стриминг через `glow` (форматированный Markdown)
- `askr "..."` — raw-вывод (без форматирования)

## Локализация

Проект поддерживает **русский** и **английский** языки. Язык определяется автоматически из системной локали, но его можно принудительно задать.

### Что локализовано

| Компонент | Английский | Русский |
|---|---|---|
| Установщик (`install.sh`) | Все сообщения | Все сообщения |
| Пресеты конфига | `ask-dolphin.cfg.example` | `ask-dolphin.cfg.ru_RU.example` |
| PyQt5 диалог (заголовок, метки, кнопки) | ✅ | ✅ |
| Заголовок раннера (Konsole) | ✅ | ✅ |
| Название в меню Dolphin | 🤖 Ask AI | 🤖 Спросить AI |
| Документация | `README.md` | `README_ru.md` |

### Приоритет определения языка

1. **Установщик:** аргумент CLI → `$LANG` → `en_EN`
2. **Диалог / Раннер:** `ASK_LOCALE` → `$LANG` → `en_EN`

### Как сменить язык

**При установке** — передайте аргумент:

```bash
./install.sh ru_RU          # принудительно русский
# или через curl:
curl ...install.sh | bash -s ru_RU
```

**После установки (диалог и раннер)** — задайте `ASK_LOCALE` в `~/.ask_ai`:

```bash
export ASK_LOCALE="ru_RU"    # принудительно русский интерфейс
# или
export ASK_LOCALE="en_EN"    # принудительно английский интерфейс
```

Без `ASK_LOCALE` используется системная переменная `$LANG` (например, `LANG=ru_RU.UTF-8` → русский). Русский также определяется для `ru_UA*`, `be_BY*` и `uk_UA*`.

### Пресеты по языку

При установке в `~/.config/ask-dolphin.cfg` копируется соответствующий файл пресетов:

- **ru_RU** → русские пресеты (`Опиши эти файлы`, `Найди ошибки…` и т.д.)
- **en_EN / другие** → английские пресеты (`Describe these files`, `Find bugs…` и т.д.)

Существующий конфиг не перезаписывается при повторной установке.

### Как добавить новый язык

Хотите добавить поддержку своего языка? Вот инструкция:

1. **Создайте файл локали** — скопируйте `locales/en_EN` в `locales/xx_XX` (где `xx_XX` — код вашей локали, например `de_DE`, `fr_FR`, `pl_PL`) и переведите все значения:

```bash
cp locales/en_EN locales/de_DE
# Отредактируйте locales/de_DE — переведите всё после =
```

2. **Добавьте определение локали** — найдите в скриптах блоки `ru_RU*|ru_UA*|be_BY*|uk_UA*` и блоки обработки `ASK_LOCALE`, добавьте свою локаль в оба места в каждом скрипте:

   - `install.sh` — строка `ru_RU*|ru_UA*|be_BY*|uk_UA*) DETECTED_LOCALE="ru_RU" ;;` и блок `ASK_LOCALE`
   - `src/ask-dolphin.sh` — два аналогичных места
   - `src/ask-dolphin-run.sh` — два аналогичных места
   - `src/ask-dolphin-dialog.py` — функция `detect_locale()` (проверки `ASK_LOCALE` и `LANG`)

3. **Создайте конфиг с пресетами** (опционально) — создайте `config/ask-dolphin.cfg.xx_XX.example` с переведёнными пресетами

4. **Обновите install.sh** — добавьте логику выбора конфига по локали (см. существующий блок `ru_RU`)

5. **Обновите .desktop файл** — добавьте `Name[xx]=Ваш Перевод` в `servicemenu/ask-dolphin.desktop`

6. **Документируйте локаль** — создайте `README_xx_XX.md` (или обновите таблицу в документации)

7. **Отправьте pull request** со всеми изменениями!

**Префиксы ключей** для справки:
- `install_*` — сообщения установщика (`install.sh`)
- `runner_*` — подписи раннера (`ask-dolphin-run.sh`)
- `dialog_*` — строки интерфейса диалога (`ask-dolphin-dialog.py`)
- `sh_*` — заголовки entry point (`ask-dolphin.sh`)

## Использование

1. Выделите один или несколько файлов/папок в Dolphin
2. Правый клик → **🤖 Спросить AI**
3. Выберите пресет (сразу отправит запрос) или введите свой вопрос и нажмите **Отправить**
4. Откроется Konsole — ответ стримится через `glow`
5. Нажмите **Ctrl+C** или **Enter**, чтобы закрыть окно

## Структура проекта

```
ask-ai-dolphin-context-menu/
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
├── AGENTS.md                   # Описание для AI-агентов
├── README.md                   # Документация на английском
└── README_ru.md                # Этот файл
```

## Лицензия

MIT
