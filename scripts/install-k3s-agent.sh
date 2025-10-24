#!/bin/bash

# =====================================================
# Универсальный скрипт установки k3s Agent Node
# =====================================================
# Версия: 1.0
# Дата: 2025-10-24
# Автор: AI Agent для k3s на vSphere
# Назначение: Установка и присоединение k3s Agent к кластеру
#
# Использование:
#   ./install-k3s-agent.sh
#   или с параметрами:
#   K3S_NODE_TOKEN=xxx K3S_NODE_IP=10.246.10.51 K3S_NODE_NAME=k3s-agent-01 ./install-k3s-agent.sh
#   или удалённо:
#   ssh user@agent-ip "$(cat install-k3s-agent.sh)"
#
# Поддерживаемые переменные окружения:
#   K3S_SERVER_URL - URL Server ноды (по умолчанию: https://10.246.10.50:6443)
#   K3S_NODE_TOKEN - Node token из Server ноды (обязательно)
#   K3S_NODE_IP    - IP адрес Agent ноды (автоопределение или указать)
#   K3S_NODE_NAME  - Имя ноды в кластере (автоопределение или указать)
#   K3S_VERSION    - Версия k3s (по умолчанию: latest)
#
# =====================================================

set -e -o pipefail

# Цвета для красивого вывода
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Настройки по умолчанию
readonly DEFAULT_SERVER_URL="https://10.246.10.50:6443"
readonly SCRIPT_VERSION="1.0"
readonly MIN_MEMORY_MB=512
readonly MIN_DISK_GB=10

# Получение параметров из переменных окружения или значения по умолчанию
SERVER_URL="${K3S_SERVER_URL:-$DEFAULT_SERVER_URL}"
NODE_TOKEN="${K3S_NODE_TOKEN}"
NODE_IP="${K3S_NODE_IP:-$(hostname -I | awk '{print $1}')}"
NODE_NAME="${K3S_NODE_NAME:-$(hostname)}"
K3S_VERSION="${K3S_VERSION:-}"

# Логирование
log() {
    echo -e "${CYAN}[$(date +'%H:%M:%S')]${NC} $*" >&2
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Функция для печати заголовков этапов
print_step() {
    local step_num=$1
    local total_steps=$2
    local step_desc=$3
    echo ""
    echo -e "${PURPLE}=== [$step_num/$total_steps] $step_desc ===${NC}"
}

# Функция показа использования
show_usage() {
    cat << EOF
${GREEN}k3s Agent Node Installer${NC} v${SCRIPT_VERSION}

${YELLOW}ИСПОЛЬЗОВАНИЕ:${NC}
    $0

${YELLOW}ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ:${NC}
    ${CYAN}K3S_SERVER_URL${NC}  - URL Server ноды (по умолчанию: ${DEFAULT_SERVER_URL})
    ${CYAN}K3S_NODE_TOKEN${NC}  - Node token из Server ноды (${RED}обязательно!${NC})
    ${CYAN}K3S_NODE_IP${NC}     - IP адрес Agent ноды (по умолчанию: автоопределение)
    ${CYAN}K3S_NODE_NAME${NC}   - Имя ноды в кластере (по умолчанию: hostname)
    ${CYAN}K3S_VERSION${NC}     - Версия k3s (по умолчанию: latest)

${YELLOW}ПРИМЕРЫ:${NC}
    # Базовая установка с node-token
    ${GREEN}K3S_NODE_TOKEN="K10abc123::server:xyz789" $0${NC}

    # Полная настройка
    ${GREEN}K3S_NODE_TOKEN="xxx" K3S_NODE_IP="10.246.10.51" K3S_NODE_NAME="k3s-agent-01" $0${NC}

    # Удалённая установка через SSH
    ${GREEN}ssh user@10.246.10.51 "$(cat $0)"${NC}

${YELLOW}ТРЕБОВАНИЯ:${NC}
    - Ubuntu 20.04+ или аналогичный Linux
    - Минимум ${MIN_MEMORY_MB}MB RAM свободной памяти
    - Минимум ${MIN_DISK_GB}GB свободного места на диске
    - Доступ к интернету для скачивания k3s
    - Сетевое подключение к k3s Server ноде
    - Права sudo для текущего пользователя

${YELLOW}ПОЛУЧЕНИЕ NODE_TOKEN:${NC}
    ${GREEN}ssh k8s-admin@10.246.10.50 "sudo cat /var/lib/rancher/k3s/server/node-token"${NC}

EOF
}

# Проверка обязательных параметров
check_required_params() {
    local error=0

    if [ -z "$NODE_TOKEN" ]; then
        log_error "NODE_TOKEN не установлен!"
        log_info "Получите token: ssh k8s-admin@10.246.10.50 \"sudo cat /var/lib/rancher/k3s/server/node-token\""
        error=1
    fi

    if [ ${#NODE_TOKEN} -lt 50 ]; then
        log_error "NODE_TOKEN имеет неправильный формат (слишком короткий: ${#NODE_TOKEN} символов)"
        log_info "Правильный формат: K10xxx::server:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx (~55 символов)"
        error=1
    fi

    if [ -z "$NODE_IP" ]; then
        log_error "Не удалось определить IP адрес ноды автоматически"
        log_info "Установите: export K3S_NODE_IP=\"10.246.10.51\""
        error=1
    fi

    if [ -z "$NODE_NAME" ]; then
        log_error "Не удалось определить имя ноды автоматически"
        log_info "Установите: export K3S_NODE_NAME=\"k3s-agent-01\""
        error=1
    fi

    if [ $error -eq 1 ]; then
        echo ""
        show_usage
        exit 1
    fi
}

# Проверка системных требований
check_system_requirements() {
    print_step 1 7 "Проверка системных требований"

    # Проверка операционной системы
    if [ ! -f /etc/os-release ]; then
        log_error "Не удалось определить операционную систему"
        exit 1
    fi

    . /etc/os-release
    log_info "Операционная система: $PRETTY_NAME"

    # Проверка прав sudo
    if ! sudo -n true 2>/dev/null; then
        log_error "Нет прав sudo или требуется пароль"
        log_info "Убедитесь что текущий пользователь имеет sudo права без пароля"
        exit 1
    fi
    log_success "Права sudo: OK"

    # Проверка свободной памяти
    local available_memory=$(free -m | awk 'NR==2{print $7}')
    if [ "$available_memory" -lt $MIN_MEMORY_MB ]; then
        log_warning "Мало свободной памяти: ${available_memory}MB (минимум: ${MIN_MEMORY_MB}MB)"
        log_warning "k3s может работать нестабильно"
    else
        log_success "Свободная память: ${available_memory}MB"
    fi

    # Проверка свободного места на диске
    local available_disk=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    if [ "$available_disk" -lt $MIN_DISK_GB ]; then
        log_error "Недостаточно места на диске: ${available_disk}GB (минимум: ${MIN_DISK_GB}GB)"
        exit 1
    fi
    log_success "Свободное место на диске: ${available_disk}GB"

    # Проверка необходимых команд
    for cmd in curl systemctl; do
        if ! command -v $cmd >/dev/null 2>&1; then
            log_error "Команда '$cmd' не найдена"
            exit 1
        fi
    done
    log_success "Необходимые команды установлены"

    # Проверка доступа к интернету
    if ! curl -s --connect-timeout 10 https://get.k3s.io >/dev/null; then
        log_error "Нет доступа к интернету или get.k3s.io недоступен"
        log_info "Проверьте сетевое подключение"
        exit 1
    fi
    log_success "Доступ к интернету: OK"
}

# Проверка сетевого подключения к Server
check_server_connectivity() {
    print_step 2 7 "Проверка подключения к k3s Server"

    local server_ip=$(echo $SERVER_URL | sed -n 's|https://\([^:]*\):.*|\1|p')
    log_info "Server IP: $server_ip"
    log_info "Server URL: $SERVER_URL"

    # Ping к Server
    if ! ping -c 2 -W 5 $server_ip >/dev/null 2>&1; then
        log_error "Server нода ($server_ip) не пингуется"
        log_info "Проверьте сетевое подключение к Server ноде"
        exit 1
    fi
    log_success "Ping к Server: OK"

    # Проверка API Server порта
    if ! curl -k -s --connect-timeout 10 $SERVER_URL/version >/dev/null; then
        log_error "API Server ($SERVER_URL) недоступен"
        log_info "Проверьте что k3s Server запущен: ssh $server_ip 'sudo systemctl status k3s'"
        exit 1
    fi
    log_success "API Server доступен: OK"

    # Получение версии Server
    local server_version=$(curl -k -s $SERVER_URL/version 2>/dev/null | grep -o '"gitVersion":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$server_version" ]; then
        log_info "Версия k3s Server: $server_version"
    fi
}

# Проверка существующей установки k3s
check_existing_installation() {
    print_step 3 7 "Проверка существующей установки k3s"

    # Проверка существующего k3s binary
    if command -v k3s >/dev/null 2>&1; then
        local current_version=$(k3s --version 2>/dev/null | head -1 | awk '{print $3}')
        log_warning "k3s уже установлен: $current_version"

        # Проверка статуса k3s-agent service
        if systemctl is-active --quiet k3s-agent 2>/dev/null; then
            log_warning "k3s-agent service уже запущен"
            log_info "Скрипт остановит и переустановит k3s-agent"

            read -p "Продолжить переустановку? (y/N): " -r
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Установка отменена пользователем"
                exit 0
            fi
        fi
    else
        log_success "Предыдущая установка k3s не найдена"
    fi

    # Проверка что нода еще не в кластере (опционально)
    # Это можно проверить только с Server ноды через kubectl
}

# Остановка и удаление существующей установки
cleanup_existing_installation() {
    print_step 4 7 "Очистка существующей установки"

    # Остановка k3s-agent service если запущен
    if systemctl is-active --quiet k3s-agent 2>/dev/null; then
        log_info "Остановка k3s-agent service..."
        sudo systemctl stop k3s-agent
        sudo systemctl disable k3s-agent 2>/dev/null || true
        log_success "k3s-agent остановлен"
    fi

    # Выполнение uninstall скрипта если существует
    if [ -f /usr/local/bin/k3s-agent-uninstall.sh ]; then
        log_info "Удаление существующей установки k3s..."
        sudo /usr/local/bin/k3s-agent-uninstall.sh 2>/dev/null || true
        log_success "Существующая установка удалена"
    fi

    # Очистка остаточных данных
    sudo rm -rf /var/lib/rancher/k3s/ 2>/dev/null || true
    sudo rm -rf /etc/rancher/k3s/ 2>/dev/null || true

    # Очистка systemd
    sudo systemctl daemon-reload

    log_success "Система подготовлена для новой установки"
}

# Установка k3s agent
install_k3s_agent() {
    print_step 5 7 "Установка k3s Agent"

    log_info "Параметры установки:"
    log_info "  Server URL: $SERVER_URL"
    log_info "  Node IP: $NODE_IP"
    log_info "  Node Name: $NODE_NAME"
    log_info "  Token: ${NODE_TOKEN:0:20}...${NODE_TOKEN: -10}"

    # Подготовка команды установки
    local install_cmd="curl -sfL https://get.k3s.io"

    # Добавление версии если указана
    if [ -n "$K3S_VERSION" ]; then
        install_cmd="$install_cmd | INSTALL_K3S_VERSION=$K3S_VERSION"
        log_info "  Версия: $K3S_VERSION"
    else
        install_cmd="$install_cmd |"
        log_info "  Версия: latest"
    fi

    # Установочная команда с параметрами
    install_cmd="$install_cmd K3S_URL=$SERVER_URL K3S_TOKEN=\"$NODE_TOKEN\" sh -s - agent --node-ip $NODE_IP --node-name $NODE_NAME"

    log_info "Запуск установки k3s..."
    log_info "Это может занять 2-5 минут в зависимости от скорости интернета"

    # Выполнение установки с таймаутом
    if timeout 300 bash -c "$install_cmd"; then
        log_success "k3s Agent установлен успешно"
    else
        log_error "Установка k3s завершилась неудачно или превысила таймаут (5 мин)"
        log_info "Проверьте логи: sudo journalctl -u k3s-agent -n 50"
        exit 1
    fi
}

# Ожидание запуска и проверка статуса
wait_for_service_ready() {
    print_step 6 7 "Ожидание готовности k3s-agent"

    log_info "Ожидание запуска k3s-agent service..."

    # Ожидание до 3 минут для запуска
    local timeout=180
    local counter=0

    while [ $counter -lt $timeout ]; do
        if systemctl is-active --quiet k3s-agent; then
            log_success "k3s-agent service запущен"
            break
        fi

        echo -n "."
        sleep 5
        counter=$((counter + 5))
    done

    if [ $counter -ge $timeout ]; then
        log_error "k3s-agent service не запустился в течение $timeout секунд"
        log_info "Проверьте статус: sudo systemctl status k3s-agent"
        log_info "Проверьте логи: sudo journalctl -u k3s-agent -n 50"
        exit 1
    fi

    echo ""

    # Дополнительное ожидание для полной инициализации
    log_info "Ожидание полной инициализации Agent ноды..."
    sleep 30

    # Проверка что kubelet работает
    if pgrep -f kubelet >/dev/null; then
        log_success "kubelet процесс запущен"
    else
        log_warning "kubelet процесс не найден"
    fi

    # Проверка flannel интерфейса (может появиться с задержкой)
    if ip link show flannel.1 >/dev/null 2>&1; then
        local flannel_ip=$(ip addr show flannel.1 | grep 'inet ' | awk '{print $2}')
        log_success "Flannel интерфейс создан: $flannel_ip"
    else
        log_warning "Flannel интерфейс еще не создан (может появиться позже)"
    fi
}

# Финальная валидация установки
validate_installation() {
    print_step 7 7 "Валидация установки"

    log_info "Проверка статуса k3s-agent service..."

    # Статус systemd service
    if systemctl is-active --quiet k3s-agent; then
        log_success "k3s-agent service: активен"
    else
        log_error "k3s-agent service: неактивен"
        exit 1
    fi

    # Проверка что service enabled для автозапуска
    if systemctl is-enabled --quiet k3s-agent; then
        log_success "k3s-agent автозапуск: включен"
    else
        log_warning "k3s-agent автозапуск: выключен"
    fi

    # Версия установленного k3s
    local installed_version=$(k3s --version 2>/dev/null | head -1 | awk '{print $3}')
    log_info "Установленная версия k3s: $installed_version"

    # Проверка k3s процессов
    local k3s_processes=$(pgrep -f k3s | wc -l)
    log_info "Количество k3s процессов: $k3s_processes"

    # Проверка основных процессов
    for process in kubelet containerd; do
        if pgrep -f $process >/dev/null; then
            log_success "$process: запущен"
        else
            log_warning "$process: не найден"
        fi
    done

    # Последние строки логов для проверки ошибок
    log_info "Последние сообщения в логах:"
    sudo journalctl -u k3s-agent -n 5 --no-pager | sed 's/^/  /'

    # Проверка успешной регистрации (по ключевым словам в логах)
    if sudo journalctl -u k3s-agent --no-pager | grep -q "Successfully registered node"; then
        log_success "Нода успешно зарегистрирована в кластере"
    elif sudo journalctl -u k3s-agent --no-pager | grep -q "Established connection"; then
        log_success "Соединение с API Server установлено"
    else
        log_warning "Не удалось подтвердить успешную регистрацию в кластере"
        log_info "Проверьте с Server ноды: kubectl get nodes"
    fi
}

# Вывод итогового статуса и следующих шагов
print_final_status() {
    echo ""
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}          k3s Agent Node успешно установлен! 🎉               ${NC}"
    echo -e "${GREEN}================================================================${NC}"
    echo ""
    echo -e "${CYAN}ИНФОРМАЦИЯ ОБ УСТАНОВКЕ:${NC}"
    echo -e "  ${YELLOW}Нода:${NC} $NODE_NAME ($NODE_IP)"
    echo -e "  ${YELLOW}Server:${NC} $SERVER_URL"
    echo -e "  ${YELLOW}Версия k3s:${NC} $(k3s --version | head -1 | awk '{print $3}')"
    echo -e "  ${YELLOW}Service:${NC} k3s-agent (активен)"
    echo ""
    echo -e "${CYAN}ПРОВЕРКА КЛАСТЕРА:${NC}"
    echo -e "  ${GREEN}# SSH к Server ноде для проверки кластера${NC}"
    echo -e "  ${GREEN}ssh k8s-admin@10.246.10.50${NC}"
    echo -e "  ${GREEN}kubectl get nodes${NC}"
    echo -e "  ${GREEN}# Должна появиться нода: $NODE_NAME${NC}"
    echo ""
    echo -e "${CYAN}УПРАВЛЕНИЕ SERVICE:${NC}"
    echo -e "  ${GREEN}sudo systemctl status k3s-agent${NC}   # Статус"
    echo -e "  ${GREEN}sudo systemctl restart k3s-agent${NC}  # Перезапуск"
    echo -e "  ${GREEN}sudo journalctl -u k3s-agent -f${NC}   # Логи в реальном времени"
    echo ""
    echo -e "${CYAN}УДАЛЕНИЕ (если нужно):${NC}"
    echo -e "  ${GREEN}sudo /usr/local/bin/k3s-agent-uninstall.sh${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  ВАЖНО:${NC} Проверьте что нода появилась в кластере с Server ноды!"
    echo -e "${YELLOW}⚠️  Статус должен изменится с NotReady на Ready в течение 1-2 минут${NC}"
    echo ""
}

# Функция обработки ошибок
cleanup_on_error() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo ""
        log_error "Установка прервана с кодом ошибки: $exit_code"
        echo ""
        echo -e "${YELLOW}ДИАГНОСТИЧЕСКИЕ КОМАНДЫ:${NC}"
        echo -e "  ${GREEN}sudo systemctl status k3s-agent${NC}"
        echo -e "  ${GREEN}sudo journalctl -u k3s-agent -n 50${NC}"
        echo -e "  ${GREEN}curl -k $SERVER_URL/version${NC}"
        echo -e "  ${GREEN}ping $(echo $SERVER_URL | sed -n 's|https://\([^:]*\):.*|\1|p')${NC}"
        echo ""
        echo -e "${YELLOW}ОЧИСТКА ПОСЛЕ ОШИБКИ:${NC}"
        echo -e "  ${GREEN}sudo /usr/local/bin/k3s-agent-uninstall.sh 2>/dev/null || true${NC}"
        echo -e "  ${GREEN}sudo rm -rf /var/lib/rancher/k3s/${NC}"
        echo ""
    fi
}

# Установка обработчика ошибок
trap cleanup_on_error EXIT

# Главная функция
main() {
    # Проверка если запущен с --help или -h
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        show_usage
        exit 0
    fi

    # Вывод заголовка
    echo -e "${PURPLE}================================================================${NC}"
    echo -e "${PURPLE}    k3s Agent Node Installer v${SCRIPT_VERSION}                       ${NC}"
    echo -e "${PURPLE}    Установка k3s Agent и присоединение к кластеру            ${NC}"
    echo -e "${PURPLE}================================================================${NC}"
    echo ""

    # Проверка обязательных параметров
    check_required_params

    # Выполнение всех этапов установки
    check_system_requirements
    check_server_connectivity
    check_existing_installation
    cleanup_existing_installation
    install_k3s_agent
    wait_for_service_ready
    validate_installation

    # Вывод финального статуса
    print_final_status

    # Отключение обработчика ошибок (установка успешна)
    trap - EXIT
}

# Запуск скрипта если вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
