#!/bin/bash
# Скрипт для генерации хэшей паролей для cloud-init
# Дата: 2025-10-24
# Автор: AI-агент VM Template Specialist

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Генератор хэшей паролей для cloud-init${NC}"
echo "=========================================="

# Проверка наличия mkpasswd
if ! command -v mkpasswd &> /dev/null; then
    echo -e "${YELLOW}Установка whois для mkpasswd...${NC}"
    sudo apt update
    sudo apt install -y whois
fi

# Генерация хэша для пароля 'admin'
echo -e "${GREEN}Генерирую хэш для пароля 'admin'...${NC}"
HASH=$(mkpasswd --method=SHA-512 --rounds=4096 admin)

echo "=========================================="
echo -e "${GREEN}Хэш пароля 'admin':${NC}"
echo "$HASH"
echo "=========================================="

# Создание файла с хэшем
echo "$HASH" > /tmp/password-hash.txt
echo -e "${BLUE}Хэш сохранён в /tmp/password-hash.txt${NC}"

# Инструкции по использованию
echo ""
echo -e "${YELLOW}Инструкции по использованию:${NC}"
echo "1. Скопируйте хэш выше"
echo "2. Замените '\$6\$rounds=4096\$salt\$hash' в cloud-init файлах"
echo "3. Сохраните изменения"
echo ""
echo -e "${GREEN}Готово!${NC}"
