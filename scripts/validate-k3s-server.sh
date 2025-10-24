#!/bin/bash
# Скрипт валидации k3s Server Node
# Версия: 1.0
# Дата: 2025-10-24
# Проект: k3s на VMware vSphere с NSX-T

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Счетчики
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=0

# Функции для вывода
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
    ((PASSED_CHECKS++))
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    ((WARNINGS++))
}

error() {
    echo -e "${RED}❌ $1${NC}"
    ((FAILED_CHECKS++))
}

check() {
    ((TOTAL_CHECKS++))
    echo -e "${BLUE}[CHECK $TOTAL_CHECKS]${NC} $1"
}

# Параметры проверки
NODE_NAME="k3s-server-01"
EXPECTED_IP="10.246.10.50"
TIMEOUT=30

# Заголовок
echo -e "${GREEN}"
echo "═══════════════════════════════════════════════════════════════"
echo "              Валидация k3s Server Node"
echo "═══════════════════════════════════════════════════════════════"
echo -e "${NC}"
echo "Дата: $(date)"
echo "Нода: $NODE_NAME"
echo ""

# ═══════════════════════════════════════════════════════════════════
# Группа 1: Базовые проверки
# ═══════════════════════════════════════════════════════════════════

echo -e "${YELLOW}=== ГРУППА 1: БАЗОВЫЕ ПРОВЕРКИ ===${NC}"
echo ""

# 1.1 systemd сервис
check "Проверка systemd сервиса k3s"
if systemctl is-active --quiet k3s; then
    success "k3s сервис активен"

    # Проверка автозапуска
    if systemctl is-enabled --quiet k3s; then
        success "k3s автозапуск включен"
    else
        warning "k3s автозапуск отключен"
    fi
else
    error "k3s сервис не активен"
    log "Статус: $(systemctl is-active k3s)"
fi

# 1.2 kubectl доступность
check "Проверка kubectl"
if command -v kubectl >/dev/null 2>&1; then
    if kubectl version --client >/dev/null 2>&1; then
        success "kubectl установлен и работает"
    else
        warning "kubectl установлен но не настроен"
    fi
else
    # Проверить k3s kubectl
    if sudo k3s kubectl version --client >/dev/null 2>&1; then
        success "k3s kubectl работает"
    else
        error "kubectl не доступен"
    fi
fi

# 1.3 API Server connectivity
check "Проверка API Server"
if kubectl cluster-info >/dev/null 2>&1; then
    success "API Server доступен"
elif sudo k3s kubectl cluster-info >/dev/null 2>&1; then
    success "API Server доступен через k3s kubectl"
else
    error "API Server не доступен"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════
# Группа 2: Проверки ноды
# ═══════════════════════════════════════════════════════════════════

echo -e "${YELLOW}=== ГРУППА 2: ПРОВЕРКИ НОДЫ ===${NC}"
echo ""

# 2.1 Node статус
check "Проверка статуса ноды"
NODE_STATUS=$(kubectl get nodes --no-headers 2>/dev/null | awk '{print $2}' || echo "Unknown")
if [ "$NODE_STATUS" = "Ready" ]; then
    success "Нода в состоянии Ready"
else
    error "Нода в состоянии: $NODE_STATUS"
fi

# 2.2 Node IP
check "Проверка IP адреса ноды"
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "Unknown")
if [ "$NODE_IP" = "$EXPECTED_IP" ]; then
    success "IP адрес ноды правильный: $NODE_IP"
else
    warning "IP адрес ноды: $NODE_IP (ожидался: $EXPECTED_IP)"
fi

# 2.3 Node название
check "Проверка названия ноды"
ACTUAL_NODE_NAME=$(kubectl get nodes --no-headers 2>/dev/null | awk '{print $1}' || echo "Unknown")
if [ "$ACTUAL_NODE_NAME" = "$NODE_NAME" ]; then
    success "Название ноды правильное: $ACTUAL_NODE_NAME"
else
    warning "Название ноды: $ACTUAL_NODE_NAME (ожидалось: $NODE_NAME)"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════
# Группа 3: Системные pods
# ═══════════════════════════════════════════════════════════════════

echo -e "${YELLOW}=== ГРУППА 3: СИСТЕМНЫЕ PODS ===${NC}"
echo ""

# 3.1 Все pods в Running
check "Проверка статуса всех pods"
NOT_RUNNING=$(kubectl get pods -A --no-headers 2>/dev/null | grep -v Running | wc -l)
if [ "$NOT_RUNNING" -eq 0 ]; then
    success "Все pods в состоянии Running"
else
    error "$NOT_RUNNING pods не в состоянии Running"
    kubectl get pods -A | grep -v Running || true
fi

# 3.2 CoreDNS
check "Проверка CoreDNS"
COREDNS_PODS=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep Running | wc -l)
if [ "$COREDNS_PODS" -gt 0 ]; then
    success "CoreDNS работает ($COREDNS_PODS pods)"
else
    error "CoreDNS не работает"
fi

# 3.3 Traefik
check "Проверка Traefik"
TRAEFIK_PODS=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik --no-headers 2>/dev/null | grep Running | wc -l)
if [ "$TRAEFIK_PODS" -gt 0 ]; then
    success "Traefik работает ($TRAEFIK_PODS pods)"
else
    warning "Traefik не найден или не работает"
fi

# 3.4 Local-path provisioner
check "Проверка Storage provisioner"
STORAGE_PODS=$(kubectl get pods -n kube-system -l app=local-path-provisioner --no-headers 2>/dev/null | grep Running | wc -l)
if [ "$STORAGE_PODS" -gt 0 ]; then
    success "Local-path provisioner работает ($STORAGE_PODS pods)"
else
    warning "Local-path provisioner не найден"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════
# Группа 4: Сетевые проверки
# ═══════════════════════════════════════════════════════════════════

echo -e "${YELLOW}=== ГРУППА 4: СЕТЕВЫЕ ПРОВЕРКИ ===${NC}"
echo ""

# 4.1 API Server порт
check "Проверка порта API Server (6443)"
if curl -k -s --connect-timeout 5 https://127.0.0.1:6443/version >/dev/null; then
    success "API Server отвечает на порту 6443"
else
    error "API Server не отвечает на порту 6443"
fi

# 4.2 Flannel интерфейс
check "Проверка Flannel CNI"
if ip addr show flannel.1 >/dev/null 2>&1; then
    FLANNEL_IP=$(ip addr show flannel.1 | grep 'inet ' | awk '{print $2}' | head -1)
    success "Flannel интерфейс активен: $FLANNEL_IP"
else
    warning "Flannel интерфейс не найден (может быть встроен в k3s)"
fi

# 4.3 DNS резолюция
check "Проверка DNS внутри кластера"
DNS_TEST=$(kubectl run dns-test-$$ --image=busybox:1.28 --rm -it --restart=Never --command -- nslookup kubernetes.default 2>/dev/null | grep "Name:" | wc -l || echo "0")
if [ "$DNS_TEST" -gt 0 ]; then
    success "DNS работает внутри кластера"
else
    error "DNS не работает внутри кластера"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════
# Группа 5: Storage проверки
# ═══════════════════════════════════════════════════════════════════

echo -e "${YELLOW}=== ГРУППА 5: STORAGE ПРОВЕРКИ ===${NC}"
echo ""

# 5.1 StorageClass
check "Проверка StorageClass"
DEFAULT_SC=$(kubectl get storageclass --no-headers 2>/dev/null | grep "(default)" | wc -l)
if [ "$DEFAULT_SC" -gt 0 ]; then
    SC_NAME=$(kubectl get storageclass --no-headers | grep "(default)" | awk '{print $1}')
    success "Default StorageClass найден: $SC_NAME"
else
    warning "Default StorageClass не найден"
fi

# 5.2 Быстрый тест PVC (опционально)
if [ "$1" = "--full" ]; then
    check "Проверка создания PVC"
    cat << EOF | kubectl apply -f - >/dev/null 2>&1
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc-$$
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 100Mi
  storageClassName: local-path
EOF

    sleep 5
    PVC_STATUS=$(kubectl get pvc test-pvc-$$ --no-headers 2>/dev/null | awk '{print $2}' || echo "Unknown")
    if [ "$PVC_STATUS" = "Bound" ]; then
        success "PVC создание работает"
    else
        error "PVC не создается (статус: $PVC_STATUS)"
    fi

    # Очистка
    kubectl delete pvc test-pvc-$$ >/dev/null 2>&1 || true
fi

echo ""

# ═══════════════════════════════════════════════════════════════════
# Группа 6: Credentials проверки
# ═══════════════════════════════════════════════════════════════════

echo -e "${YELLOW}=== ГРУППА 6: CREDENTIALS ПРОВЕРКИ ===${NC}"
echo ""

# 6.1 kubeconfig
check "Проверка kubeconfig"
if [ -f "/etc/rancher/k3s/k3s.yaml" ]; then
    success "kubeconfig существует"

    # Проверка прав доступа
    KUBECONFIG_PERMS=$(stat -c "%a" /etc/rancher/k3s/k3s.yaml 2>/dev/null || echo "000")
    if [ "$KUBECONFIG_PERMS" = "644" ]; then
        success "kubeconfig права доступа правильные (644)"
    else
        warning "kubeconfig права доступа: $KUBECONFIG_PERMS (рекомендуется 644)"
    fi
else
    error "kubeconfig не найден"
fi

# 6.2 node-token
check "Проверка node-token"
if [ -f "/var/lib/rancher/k3s/server/node-token" ]; then
    TOKEN_LENGTH=$(wc -c < /var/lib/rancher/k3s/server/node-token 2>/dev/null || echo "0")
    if [ "$TOKEN_LENGTH" -gt 50 ]; then
        success "node-token существует (длина: $TOKEN_LENGTH символов)"
    else
        error "node-token слишком короткий или поврежден"
    fi
else
    error "node-token не найден"
fi

# 6.3 Credentials директория пользователя
check "Проверка пользовательских credentials"
if [ -d "$HOME/k3s-credentials" ]; then
    CREDS_FILES=$(ls $HOME/k3s-credentials/*.yaml $HOME/k3s-credentials/*.txt 2>/dev/null | wc -l || echo "0")
    success "Credentials директория найдена ($CREDS_FILES файлов)"
else
    warning "Credentials директория не найдена в $HOME/k3s-credentials"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════
# Итоговый отчет
# ═══════════════════════════════════════════════════════════════════

echo -e "${GREEN}"
echo "═══════════════════════════════════════════════════════════════"
echo "                    ИТОГОВЫЙ ОТЧЕТ"
echo "═══════════════════════════════════════════════════════════════"
echo -e "${NC}"

echo "📊 Статистика проверок:"
echo "  • Всего проверок: $TOTAL_CHECKS"
echo "  • Успешно: $PASSED_CHECKS"
echo "  • Ошибки: $FAILED_CHECKS"
echo "  • Предупреждения: $WARNINGS"
echo ""

# Расчет процента успеха
if [ "$TOTAL_CHECKS" -gt 0 ]; then
    SUCCESS_RATE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
else
    SUCCESS_RATE=0
fi

echo "📈 Процент успеха: $SUCCESS_RATE%"
echo ""

# Финальное заключение
if [ "$FAILED_CHECKS" -eq 0 ]; then
    if [ "$WARNINGS" -eq 0 ]; then
        echo -e "${GREEN}🎉 ОТЛИЧНО! k3s Server полностью готов к production!${NC}"
        FINAL_STATUS="EXCELLENT"
    else
        echo -e "${YELLOW}✅ ХОРОШО! k3s Server готов к работе (есть незначительные замечания)${NC}"
        FINAL_STATUS="GOOD"
    fi
else
    echo -e "${RED}⚠️  ТРЕБУЕТСЯ ВНИМАНИЕ! Найдены критичные проблемы${NC}"
    FINAL_STATUS="NEEDS_ATTENTION"
fi

echo ""

# Рекомендации
echo "🎯 Рекомендации:"

if [ "$FAILED_CHECKS" -gt 0 ]; then
    echo "  • Исправьте критичные ошибки перед добавлением Agent нод"
    echo "  • Смотрите troubleshooting guide: 05-troubleshooting.md"
fi

if [ "$WARNINGS" -gt 0 ]; then
    echo "  • Рассмотрите исправление предупреждений для оптимальной работы"
fi

if [ "$FINAL_STATUS" = "EXCELLENT" ] || [ "$FINAL_STATUS" = "GOOD" ]; then
    echo "  • ✅ Готов к присоединению Agent нод!"
    echo "  • ✅ Можно начинать развертывание приложений"

    # Показать информацию для Agent нод
    if [ -f "$HOME/k3s-credentials/node-token.txt" ]; then
        echo ""
        echo "🔑 Информация для Agent нод:"
        echo "  • Server URL: https://$NODE_IP:6443"
        echo "  • Node Token: $(head -c 20 $HOME/k3s-credentials/node-token.txt)..."
    fi
fi

echo ""

# Полезные команды
echo "📋 Полезные команды:"
echo "  • Статус кластера: kubectl get nodes"
echo "  • Системные pods: kubectl get pods -A"
echo "  • Логи k3s: sudo journalctl -u k3s -f"
echo "  • Credentials: ls -la ~/k3s-credentials/"

# Детальная валидация (если --full)
if [ "$1" = "--full" ]; then
    echo "  • Повторная валидация: $0"
else
    echo "  • Полная валидация: $0 --full"
fi

echo ""
echo "Дата завершения: $(date)"

# Exit код
if [ "$FAILED_CHECKS" -gt 0 ]; then
    exit 1
else
    exit 0
fi
