#!/bin/bash
# ask-dolphin.sh — вызывается из сервис-меню Dolphin
# 1. PyQt5 диалог: кнопки пресетов + поле ввода
# 2. Konsole с glow для стриминга ответа
#
# Модель: задаётся через переменную окружения ASK_MODEL (export ASK_MODEL="opencode/...")
# Заготовки запросов: настраиваются в ~/.config/ask-dolphin.cfg

# --- Определяем директорию установки (поиск рядом со скриптом) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Заготовки запросов (читаются из ~/.config/ask-dolphin.cfg) ---
ASK_PRESETS=()
CONFIG_FILE="$HOME/.config/ask-dolphin.cfg"
if [ -f "$CONFIG_FILE" ]; then
    while IFS= read -r line; do
        # Пропускаем пустые строки и комментарии
        [[ -z "$line" || "$line" == \#* ]] && continue
        ASK_PRESETS+=("$line")
    done < "$CONFIG_FILE"
fi
# Fallback, если конфиг пуст или отсутствует
if [ ${#ASK_PRESETS[@]} -eq 0 ]; then
    ASK_PRESETS=(
        "Опиши эти файлы"
        "Найди баги в этих файлах"
        "Оптимизируй этот код"
        "Проверь качество кода"
        "Сгенерируй документацию"
        "Сделай рефакторинг"
        "Напиши тесты для этих файлов"
    )
fi

# Фильтруем пустые аргументы (на случай если Dolphin передал пустую строку)
FILES=()
for f in "$@"; do
    [ -n "$f" ] && FILES+=("$f")
done

# Если ничего не выделено — используем текущую директорию
HAS_SELECTION=true
if [ ${#FILES[@]} -eq 0 ]; then
    HAS_SELECTION=false
    FILES=("$PWD")
fi

# --- Собираем информацию о выбранных файлах ---
if [ "$HAS_SELECTION" = true ]; then
    FILE_LIST="Выбранные файлы:\\n"
else
    FILE_LIST="Текущая директория:\\n"
fi
for f in "${FILES[@]}"; do
    BASENAME=$(basename "$f")
    if [ -d "$f" ]; then
        FILE_LIST+="📁 $BASENAME\\n"
    else
        SIZE=$(du -h "$f" 2>/dev/null | cut -f1)
        FILE_LIST+="📄 $BASENAME  ($SIZE)\\n"
    fi
done

# --- PyQt5 диалог: кнопки пресетов + поле ввода ---
DIALOG="$SCRIPT_DIR/ask-dolphin-dialog.py"
QUERY=$(echo -e "$FILE_LIST" | "$DIALOG" "${ASK_PRESETS[@]}")

# Если нажали Cancel
if [ $? -ne 0 ]; then
    exit 0
fi

# Если вопрос пустой — выходим
if [ -z "$QUERY" ]; then
    exit 0
fi

# --- Открываем Konsole с раннером (ASK_MODEL прокидывается из окружения) ---
RUNNER="$SCRIPT_DIR/ask-dolphin-run.sh"
exec konsole -e "$RUNNER" "$QUERY" "${FILES[@]}"
