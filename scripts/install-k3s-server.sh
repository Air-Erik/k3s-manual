#!/bin/bash
# Скрипт установки k3s Server Node
# Версия: 1.0
# Дата: 2025-10-24
# Проект: k3s на VMware vSphere с NSX-T

set -e -o pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Параметры установки
NODE_IP="10.246.10.50"
NODE_NAME="k3s-server-01"
FLANNEL_IFACE="ens33"
KUBECONFIG_MODE="644"

# Функция для вывода сообщений
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# Заголовок
echo -e "${GREEN}"
echo "═══════════════════════════════════════════════════════════════"
echo "                 Установка k3s Server Node"
echo "═══════════════════════════════════════════════════════════════"
echo -e "${NC}"
echo "Нода: $NODE_NAME"
echo "IP: $NODE_IP"
echo "Интерфейс: $FLANNEL_IFACE"
echo "Дата: $(date)"
echo ""

# ═══════════════════════════════════════════════════════════════════
# Этап 1: Проверка prerequisites
# ═══════════════════════════════════════════════════════════════════

echo -e "${YELLOW}[1/6] Проверка prerequisites...${NC}"

# Проверка что скрипт запущен не под root
if [ "$EUID" -eq 0 ]; then
    error "Не запускайте скрипт под root! Используйте: sudo ./install-k3s-server.sh"
fi

# Проверка sudo прав
log "Проверка sudo прав..."
if ! sudo -n true 2>/dev/null; then
    error "Нужны sudo права. Убедитесь что пользователь в группе sudo."
fi

# Проверка сетевого интерфейса
log "Проверка сетевого интерфейса $FLANNEL_IFACE..."
if ! ip link show $FLANNEL_IFACE >/dev/null 2>&1; then
    error "Сетевой интерфейс $FLANNEL_IFACE не найден!"
fi

# Получение IP адреса интерфейса
CURRENT_IP=$(ip addr show $FLANNEL_IFACE | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 | head -1)
if [ "$CURRENT_IP" != "$NODE_IP" ]; then
    warning "IP адрес интерфейса ($CURRENT_IP) не совпадает с ожидаемым ($NODE_IP)"
    log "Продолжаем с текущим IP: $CURRENT_IP"
    NODE_IP=$CURRENT_IP
fi

# Проверка подключения к интернету
log "Проверка подключения к интернету..."
if ! curl -s --connect-timeout 5 https://get.k3s.io >/dev/null; then
    error "Нет доступа к интернету! Проверьте сетевое подключение."
fi

# Проверка DNS
log "Проверка DNS резолюции..."
if ! nslookup github.com >/dev/null 2>&1; then
    warning "DNS резолюция работает медленно или некорректно"
fi

# Проверка свободного места
log "Проверка свободного места на диске..."
AVAILABLE_SPACE=$(df / | awk 'NR==2 {print $4}')
REQUIRED_SPACE=2097152  # 2GB в KB
if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
    error "Недостаточно свободного места! Требуется минимум 2GB."
fi

# Проверка что порт 6443 свободен
log "Проверка что порт 6443 свободен..."
if netstat -tuln 2>/dev/null | grep -q ":6443 "; then
    warning "Порт 6443 уже занят. Возможно k3s уже установлен?"
    if systemctl is-active --quiet k3s; then
        log "k3s уже запущен. Проверяем статус..."
        if sudo k3s kubectl get nodes >/dev/null 2>&1; then
            success "k3s уже установлен и работает!"
            echo ""
            echo "Для получения kubeconfig:"
            echo "  sudo cat /etc/rancher/k3s/k3s.yaml"
            echo ""
            echo "Для получения node-token:"
            echo "  sudo cat /var/lib/rancher/k3s/server/node-token"
            exit 0
        fi
    fi
fi

success "Prerequisites проверены успешно"
echo ""

# ═══════════════════════════════════════════════════════════════════
# Этап 2: Установка k3s
# ═══════════════════════════════════════════════════════════════════

echo -e "${YELLOW}[2/6] Установка k3s server...${NC}"

log "Скачивание и установка k3s..."
log "Команда: curl -sfL https://get.k3s.io | sh -s - server"
log "Параметры установки:"
log "  --write-kubeconfig-mode $KUBECONFIG_MODE"
log "  --node-ip $NODE_IP"
log "  --flannel-iface $FLANNEL_IFACE"
log "  --node-name $NODE_NAME"
echo ""

# Установка k3s
export INSTALL_K3S_EXEC="server"
export K3S_NODE_NAME="$NODE_NAME"

curl -sfL https://get.k3s.io | sh -s - server \
    --write-kubeconfig-mode $KUBECONFIG_MODE \
    --node-ip $NODE_IP \
    --flannel-iface $FLANNEL_IFACE \
    --node-name $NODE_NAME

success "k3s установлен успешно"
echo ""

# ═══════════════════════════════════════════════════════════════════
# Этап 3: Ожидание запуска k3s
# ═══════════════════════════════════════════════════════════════════

echo -e "${YELLOW}[3/6] Ожидание запуска k3s...${NC}"

log "Проверка статуса systemd сервиса..."
sleep 5

# Ожидание запуска сервиса (максимум 120 секунд)
TIMEOUT=120
COUNTER=0

while [ $COUNTER -lt $TIMEOUT ]; do
    if systemctl is-active --quiet k3s; then
        success "k3s сервис запущен"
        break
    fi

    log "Ожидание запуска k3s... ($COUNTER/$TIMEOUT сек)"
    sleep 5
    COUNTER=$((COUNTER + 5))
done

if [ $COUNTER -ge $TIMEOUT ]; then
    error "k3s не запустился в течение $TIMEOUT секунд. Проверьте логи: sudo journalctl -u k3s -f"
fi

# Ожидание доступности API Server
log "Ожидание доступности API Server..."
COUNTER=0

while [ $COUNTER -lt $TIMEOUT ]; do
    if sudo k3s kubectl get nodes >/dev/null 2>&1; then
        success "API Server доступен"
        break
    fi

    log "Ожидание API Server... ($COUNTER/$TIMEOUT сек)"
    sleep 5
    COUNTER=$((COUNTER + 5))
done

if [ $COUNTER -ge $TIMEOUT ]; then
    error "API Server не запустился в течение $TIMEOUT секунд"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════
# Этап 4: Получение kubeconfig
# ═══════════════════════════════════════════════════════════════════

echo -e "${YELLOW}[4/6] Настройка kubeconfig...${NC}"

# Создание директории для credentials
CREDS_DIR="$HOME/k3s-credentials"
log "Создание директории $CREDS_DIR..."
mkdir -p $CREDS_DIR

# Копирование kubeconfig
log "Копирование kubeconfig..."
sudo cp /etc/rancher/k3s/k3s.yaml $CREDS_DIR/kubeconfig.yaml
sudo chown $(id -u):$(id -g) $CREDS_DIR/kubeconfig.yaml

# Исправление прав на оригинальный kubeconfig
log "Исправление прав на kubeconfig..."
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
sudo chown $(id -u):$(id -g) /etc/rancher/k3s/k3s.yaml

# Создание kubeconfig для kubectl на текущей машине
log "Настройка kubectl для текущего пользователя..."
mkdir -p $HOME/.kube
cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
chmod 600 $HOME/.kube/config

# Проверка kubectl
if kubectl get nodes >/dev/null 2>&1; then
    success "kubectl настроен успешно"
else
    warning "kubectl не работает. Используйте: sudo k3s kubectl"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════
# Этап 5: Сохранение node-token
# ═══════════════════════════════════════════════════════════════════

echo -e "${YELLOW}[5/6] Сохранение node-token...${NC}"

log "Получение node-token..."
sudo cat /var/lib/rancher/k3s/server/node-token > $CREDS_DIR/node-token.txt

# Создание информационного файла
cat > $CREDS_DIR/cluster-info.txt << EOF
# k3s Cluster Information
# Дата создания: $(date)

# Server Node
Server URL: https://$NODE_IP:6443
Node Name: $NODE_NAME
Node IP: $NODE_IP

# Для Agent нод
Server: https://$NODE_IP:6443
Token: $(cat $CREDS_DIR/node-token.txt)

# Файлы
kubeconfig: $CREDS_DIR/kubeconfig.yaml
node-token: $CREDS_DIR/node-token.txt
EOF

success "Credentials сохранены в $CREDS_DIR/"

echo ""

# ═══════════════════════════════════════════════════════════════════
# Этап 6: Базовая валидация
# ═══════════════════════════════════════════════════════════════════

echo -e "${YELLOW}[6/6] Базовая валидация установки...${NC}"

# Проверка ноды
log "Проверка ноды..."
if kubectl get nodes | grep -q "Ready"; then
    success "Нода в состоянии Ready"
else
    warning "Нода не в состоянии Ready. Проверьте позже."
fi

# Проверка системных pods
log "Проверка системных pods..."
PENDING_PODS=$(kubectl get pods -A --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
if [ "$PENDING_PODS" -eq 0 ]; then
    success "Все системные pods в состоянии Running"
else
    warning "$PENDING_PODS pods еще не в состоянии Running. Это нормально в первые минуты."
fi

# Проверка API Server
log "Проверка API Server..."
if curl -k -s https://$NODE_IP:6443/version >/dev/null; then
    success "API Server отвечает"
else
    warning "API Server не отвечает на внешние запросы"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════
# Финальный отчет
# ═══════════════════════════════════════════════════════════════════

echo -e "${GREEN}"
echo "═══════════════════════════════════════════════════════════════"
echo "           ✅ k3s Server успешно установлен! ✅"
echo "═══════════════════════════════════════════════════════════════"
echo -e "${NC}"

echo "📋 Информация о кластере:"
echo "  • Server URL: https://$NODE_IP:6443"
echo "  • Node Name: $NODE_NAME"
echo "  • Kubeconfig: $CREDS_DIR/kubeconfig.yaml"
echo "  • Node Token: $CREDS_DIR/node-token.txt"
echo ""

echo "🎯 Полезные команды:"
echo "  • Статус k3s:    sudo systemctl status k3s"
echo "  • Логи k3s:      sudo journalctl -u k3s -f"
echo "  • Список нод:    kubectl get nodes"
echo "  • Системные pods: kubectl get pods -A"
echo "  • Версия:        kubectl version"
echo ""

echo "🔑 Для Agent нод используйте:"
echo "  Server: https://$NODE_IP:6443"
echo "  Token:  $(cat $CREDS_DIR/node-token.txt)"
echo ""

echo "📄 Детальная валидация:"
echo "  Запустите: ./validate-k3s-server.sh"
echo ""

echo "🎉 Готов к присоединению Agent нод!"

# Финальная информация
kubectl get nodes -o wide 2>/dev/null || true
