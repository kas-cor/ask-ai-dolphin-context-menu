#!/bin/bash
# ask-dolphin-run.sh — универсальный раннер для запуска opencode в Konsole
# Принимает вопрос как $1, файлы как $2+
# Показывает шапку и стримит ответ через glow

# Чистый выход по Ctrl+C (без «Сбой программы» от Konsole)
trap 'echo ""; exit 0' INT

QUERY="$1"
shift

# Фильтруем пустые аргументы
FILES=()
for f in "$@"; do
    [ -n "$f" ] && FILES+=("$f")
done

if [ -z "$QUERY" ]; then
    QUERY="Explain these files"
fi

# Если файлы не переданы — используем текущую директорию
if [ ${#FILES[@]} -eq 0 ]; then
    FILES=("$PWD")
fi

# --- Цвета ---
BOLD='\033[1m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- Шапка ---
echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║      🤖  Ask AI about selected file(s)   ║${NC}"
echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}${YELLOW}Selected files:${NC}"
for f in "${FILES[@]}"; do
    if [ -d "$f" ]; then
        echo -e "  ${CYAN}📁 $f${NC}"
    else
        SIZE=$(du -h "$f" 2>/dev/null | cut -f1)
        echo -e "  ${GREEN}📄 $f${NC}  ${BOLD}(${SIZE})${NC}"
    fi
done
echo ""
echo -e "${BOLD}Your question:${NC}"
echo -e "  ${YELLOW}$QUERY${NC}"
echo ""

# --- Формируем промпт ---
PROMPT="I have these selected files/directories:
$(printf '%s\n' "${FILES[@]}")

My question about them: $QUERY"

# --- Проверяем opencode ---
if ! command -v opencode &> /dev/null; then
    echo -e "${BOLD}Error: opencode not found in PATH${NC}"
    exit 1
fi

# --- Определяем модель (из окружения или по умолчанию) ---
MODEL="${ASK_MODEL:-opencode/deepseek-v4-flash-free}"
echo -e "${BOLD}Model:${NC} ${CYAN}${MODEL}${NC}"
echo ""

# --- Стримим ---
echo -e "${BOLD}⏳ Streaming AI response...${NC}"
echo ""

if command -v glow &> /dev/null; then
    opencode run --model "$MODEL" "$PROMPT" | glow -
else
    echo -e "${YELLOW}glow not found — вывод без форматирования${NC}"
    opencode run --model "$MODEL" "$PROMPT"
fi

echo ""
echo -e "${BOLD}${GREEN}✅ Done. Press Ctrl+C or Enter to close.${NC}"
echo -n ""
read -r 2>/dev/null || true
