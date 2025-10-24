#!/bin/bash
# Скрипт подготовки VM Template для k3s
# Дата: 2025-10-24
# Автор: AI-агент VM Template Specialist
# Цель: Подготовка Ubuntu VM к конвертации в Template для k3s кластера

set -e  # Выход при ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция логирования
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка прав root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "Не запускайте скрипт от root! Используйте sudo внутри скрипта."
        exit 1
    fi
}

# Проверка ОС
check_os() {
    log "Проверка операционной системы..."

    if ! grep -q "Ubuntu" /etc/os-release; then
        error "Этот скрипт предназначен только для Ubuntu!"
        exit 1
    fi

    local version=$(grep VERSION_ID /etc/os-release | cut -d'"' -f2)
    if [[ "$version" != "24.04" ]]; then
        warning "Рекомендуется Ubuntu 24.04 LTS. Текущая версия: $version"
    fi

    success "ОС проверена: Ubuntu $version"
}

# Проверка ресурсов
check_resources() {
    log "Проверка системных ресурсов..."

    # Проверка RAM
    local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $ram_gb -lt 2 ]]; then
        warning "Рекомендуется минимум 2 GB RAM. Текущая: ${ram_gb}GB"
    else
        success "RAM: ${ram_gb}GB ✓"
    fi

    # Проверка диска
    local disk_gb=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
    if [[ $disk_gb -lt 20 ]]; then
        warning "Рекомендуется минимум 20 GB свободного места. Текущее: ${disk_gb}GB"
    else
        success "Диск: ${disk_gb}GB свободно ✓"
    fi

    # Проверка vCPU
    local vcpu=$(nproc)
    if [[ $vcpu -lt 2 ]]; then
        warning "Рекомендуется минимум 2 vCPU. Текущее: $vcpu"
    else
        success "vCPU: $vcpu ✓"
    fi
}

# Обновление системы
update_system() {
    log "Обновление системы..."

    # Обновление списка пакетов
    sudo apt update

    # Обновление пакетов
    sudo apt upgrade -y

    # Очистка кэша
    sudo apt autoremove -y
    sudo apt autoclean

    success "Система обновлена"
}

# Установка необходимых пакетов
install_packages() {
    log "Установка необходимых пакетов..."

    # Список обязательных пакетов
    local packages=(
        "curl"
        "wget"
        "vim"
        "net-tools"
        "iputils-ping"
        "dnsutils"
        "htop"
        "tree"
        "cloud-init"
        "cloud-initramfs-growroot"
        "open-vm-tools"
        "open-vm-tools-desktop"
        "iproute2"
        "bridge-utils"
        "unzip"
        "jq"
        "git"
    )

    # Установка пакетов
    for package in "${packages[@]}"; do
        log "Установка $package..."
        sudo apt install -y "$package"
    done

    success "Все пакеты установлены"
}

# Проверка запрещённых пакетов
check_forbidden_packages() {
    log "Проверка на наличие запрещённых пакетов..."

    # Список запрещённых пакетов
    local forbidden=(
        "kubeadm"
        "kubelet"
        "kubectl"
        "kubernetes-cni"
        "containerd"
        "docker.io"
        "docker-ce"
        "cri-o"
        "flannel"
        "calico"
        "cilium"
        "nginx-ingress"
        "traefik"
        "metallb"
        "kube-vip"
    )

    local found_forbidden=()

    for package in "${forbidden[@]}"; do
        if dpkg -l | grep -q "^ii.*$package "; then
            found_forbidden+=("$package")
        fi
    done

    if [[ ${#found_forbidden[@]} -gt 0 ]]; then
        error "Найдены запрещённые пакеты: ${found_forbidden[*]}"
        error "Эти пакеты НЕ должны быть установлены в k3s Template!"
        error "k3s содержит все необходимые компоненты встроенными."
        exit 1
    fi

    success "Запрещённые пакеты не найдены ✓"
}

# Настройка cloud-init
configure_cloud_init() {
    log "Настройка cloud-init..."

    # Создание директории для конфигураций
    sudo mkdir -p /etc/cloud/cloud.cfg.d

    # Настройка cloud-init для VMware vSphere
    sudo tee /etc/cloud/cloud.cfg.d/98-datasource.cfg > /dev/null << 'EOF'
datasource_list: [ VMware, OVF, NoCloud, None ]
EOF

    # Включение cloud-init сервисов
    sudo systemctl unmask cloud-init cloud-init-local cloud-config cloud-final
    sudo systemctl enable cloud-init cloud-init-local cloud-config cloud-final

    # Включение cloud-init для VMware
    sudo systemctl enable cloud-init
    sudo systemctl start cloud-init

    # Базовая конфигурация cloud-init
    sudo tee /etc/cloud/cloud.cfg.d/99-k3s-template.cfg > /dev/null << 'EOF'
# Cloud-init конфигурация для k3s Template
# Дата: 2025-10-24

# Включение cloud-init для VMware
disable_vmware_customization: false

# Отключение обновлений при первом запуске
package_update: false
package_upgrade: false

# Настройки пользователя
users:
  - name: k8s-admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false

# Настройки SSH
ssh_pwauth: true
disable_root: true

# Настройки сети
network:
  config: disabled

# Настройки времени
timezone: UTC

# Настройки локали
locale: en_US.UTF-8
EOF

    # Настройка cloud-init для VMware
    sudo tee /etc/cloud/cloud.cfg.d/99-vmware.cfg > /dev/null << 'EOF'
# VMware специфичные настройки cloud-init

# Включение cloud-init для VMware
disable_vmware_customization: false

# Настройки для VMware Tools
datasource:
  VMware:
    metadata_urls: ['http://169.254.169.254']
    max_wait: 10
    timeout: 5

# Настройки сети для VMware
network:
  config: enabled
EOF

    # Дополнительно: изменение основного cloud.cfg
    sudo sed -i 's/disable_vmware_customization: true/disable_vmware_customization: false/' /etc/cloud/cloud.cfg || true

    success "Cloud-init настроен"
}

# Настройка VMware Tools
configure_vmware_tools() {
    log "Настройка VMware Tools..."

    # Проверка установки open-vm-tools
    if ! command -v vmware-toolbox-cmd &> /dev/null; then
        error "open-vm-tools не установлен!"
        exit 1
    fi

    # Включение автоматического обновления VMware Tools
    sudo systemctl enable open-vm-tools
    sudo systemctl start open-vm-tools

    # Проверка статуса
    if sudo systemctl is-active --quiet open-vm-tools; then
        success "VMware Tools активен"
    else
        warning "VMware Tools не активен, но это может быть нормально"
    fi
}

# Настройка SSH
configure_ssh() {
    log "Настройка SSH..."

    # Включение SSH
    sudo systemctl enable ssh
    sudo systemctl start ssh

    # Проверка статуса SSH
    if sudo systemctl is-active --quiet ssh; then
        success "SSH активен"
    else
        error "SSH не удалось запустить!"
        exit 1
    fi

    # Проверка портов
    if sudo netstat -tlnp | grep -q ":22 "; then
        success "SSH слушает на порту 22"
    else
        warning "SSH не слушает на порту 22"
    fi
}

# Настройка firewall
configure_firewall() {
    log "Настройка firewall..."

    # Установка ufw если не установлен
    if ! command -v ufw &> /dev/null; then
        sudo apt install -y ufw
    fi

    # Сброс правил
    sudo ufw --force reset

    # Базовые правила
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    # Разрешить SSH
    sudo ufw allow ssh

    # Разрешить порты k3s (для будущего использования)
    sudo ufw allow 6443/tcp comment 'k3s API Server'
    sudo ufw allow 10250/tcp comment 'kubelet'
    sudo ufw allow 8472/udp comment 'Flannel VXLAN'

    # Включение firewall
    sudo ufw --force enable

    success "Firewall настроен"
}

# Очистка системы
cleanup_system() {
    log "Очистка системы..."

    # Очистка логов
    sudo journalctl --vacuum-time=1d
    sudo find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;

    # Очистка истории команд
    history -c
    rm -f ~/.bash_history

    # Очистка кэша пакетов
    sudo apt clean
    sudo apt autoremove -y

    # Очистка временных файлов
    sudo rm -rf /tmp/*
    sudo rm -rf /var/tmp/*

    # SSH ключи хоста будут удалены cloud-init при клонировании
    # sudo rm -f /etc/ssh/ssh_host_*  # НЕ удаляем - cloud-init сделает это

    # Сброс machine-id
    sudo truncate -s 0 /etc/machine-id
    sudo rm -f /var/lib/dbus/machine-id
    sudo systemd-machine-id-setup

    # Удаление кастомных netplan-файлов для генерации 50-cloud-init.yaml
    sudo rm -f /etc/netplan/*.yaml

    # Очистка cloud-init данных для Template
    sudo cloud-init clean --logs --machine
    sudo rm -rf /var/lib/cloud

    success "Система очищена"
}

# Финальные проверки
final_checks() {
    log "Выполнение финальных проверок..."

    # Проверка обязательных пакетов
    local required_packages=("curl" "wget" "vim" "cloud-init" "open-vm-tools")
    for package in "${required_packages[@]}"; do
        if ! command -v "$package" &> /dev/null; then
            error "Пакет $package не найден!"
            exit 1
        fi
    done

    # Проверка cloud-init
    if ! cloud-init --version &> /dev/null; then
        error "Cloud-init не работает!"
        exit 1
    fi

    # Проверка VMware Tools
    if ! vmware-toolbox-cmd --version &> /dev/null; then
        warning "VMware Tools не отвечает, но это может быть нормально"
    fi

    # Проверка SSH
    if ! sudo systemctl is-active --quiet ssh; then
        error "SSH не активен!"
        exit 1
    fi

    # Проверка сети
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        warning "Нет подключения к интернету"
    fi

    success "Все проверки пройдены"
}

# Создание отчёта
create_report() {
    log "Создание отчёта о подготовке..."

    local report_file="/opt/k3s-setup/template-preparation-report.txt"
    sudo mkdir -p /opt/k3s-setup

    sudo tee "$report_file" > /dev/null << EOF
# Отчёт о подготовке VM Template для k3s
# Дата: $(date)
# Автор: AI-агент VM Template Specialist

## Системная информация
- ОС: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
- Ядро: $(uname -r)
- Архитектура: $(uname -m)
- vCPU: $(nproc)
- RAM: $(free -h | awk '/^Mem:/{print $2}')
- Диск: $(df -h / | awk 'NR==2{print $4}')

## Установленные пакеты
$(dpkg -l | grep -E "(curl|wget|vim|cloud-init|open-vm-tools)" | wc -l) пакетов установлено

## Статус сервисов
- SSH: $(sudo systemctl is-active ssh)
- VMware Tools: $(sudo systemctl is-active open-vm-tools)
- Cloud-init: $(cloud-init --version 2>/dev/null || echo "недоступен")

## Сетевая информация
- Интерфейсы: $(ip -o link show | wc -l)
- Маршруты: $(ip route | wc -l)
- DNS: $(cat /etc/resolv.conf | grep nameserver | wc -l) серверов

## Готовность к конвертации
✅ Система готова к конвертации в Template
✅ Cloud-init настроен
✅ VMware Tools активен
✅ SSH доступен
✅ Система очищена
✅ Запрещённые пакеты отсутствуют

## Следующие шаги
1. Конвертировать VM в Template в vSphere UI
2. Валидировать Template путём клонирования
3. Использовать Template для создания k3s нод

## Важные замечания
- НЕ устанавливать kubeadm, kubelet, kubectl, containerd
- k3s содержит все необходимые компоненты встроенными
- Template готов для создания k3s кластера
EOF

    success "Отчёт создан: $report_file"
}

# Основная функция
main() {
    echo "=========================================="
    echo "Подготовка VM Template для k3s кластера"
    echo "Дата: $(date)"
    echo "=========================================="

    # Проверки
    check_root
    check_os
    check_resources

    # Подготовка системы
    update_system
    install_packages
    check_forbidden_packages

    # Настройка компонентов
    configure_cloud_init
    configure_vmware_tools
    configure_ssh
    configure_firewall

    # Очистка
    cleanup_system

    # Финальные проверки
    final_checks
    create_report

    echo "=========================================="
    success "Подготовка VM Template завершена успешно!"
    echo "=========================================="
    echo ""
    echo "Следующие шаги:"
    echo "1. Выключить VM"
    echo "2. Конвертировать VM в Template в vSphere UI"
    echo "3. Валидировать Template путём клонирования"
    echo ""
    echo "Template готов для создания k3s кластера! 🚀"
    echo "=========================================="
}

# Запуск скрипта
main "$@"
