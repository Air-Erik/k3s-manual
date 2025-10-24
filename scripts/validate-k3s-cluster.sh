#!/bin/bash

# =====================================================
# Скрипт валидации k3s кластера
# =====================================================
# Версия: 1.0
# Дата: 2025-10-24
# Автор: AI Agent для k3s на vSphere
# Назначение: Полная валидация k3s кластера после установки Agent нод
#
# Использование:
#   ./validate-k3s-cluster.sh
#   или с SSH:
#   ssh k3s-admin@10.246.10.50 "$(cat validate-k3s-cluster.sh)"
#
# Требования:
#   - Запускается с Server ноды (где доступен kubectl)
#   - Кластер должен иметь как минимум 1 Server и 1+ Agent нод
#   - SSH доступ к Agent нодам для дополнительных проверок
#
# Поддерживаемые переменные окружения:
#   EXPECTED_NODES     - Ожидаемое количество нод (по умолчанию: 3)
#   SKIP_AGENT_SSH     - Пропустить SSH проверки Agent нод (по умолчанию: false)
#   VERBOSE           - Подробный вывод (по умолчанию: false)
#   TEST_DEPLOYMENT   - Создавать тестовые deployment (по умолчанию: true)
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
readonly SCRIPT_VERSION="1.0"
readonly EXPECTED_NODES="${EXPECTED_NODES:-3}"
readonly SKIP_AGENT_SSH="${SKIP_AGENT_SSH:-false}"
readonly VERBOSE="${VERBOSE:-false}"
readonly TEST_DEPLOYMENT="${TEST_DEPLOYMENT:-true}"

# Глобальные счетчики для отчета
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Логирование
log() {
    echo -e "${CYAN}[$(date +'%H:%M:%S')]${NC} $*" >&2
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" >&2
    WARNING_CHECKS=$((WARNING_CHECKS + 1))
}

log_error() {
    echo -e "${RED}[FAILED]${NC} $*" >&2
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
}

log_verbose() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${PURPLE}[VERBOSE]${NC} $*" >&2
    fi
}

# Функция для печати заголовков этапов
print_step() {
    local step_num=$1
    local total_steps=$2
    local step_desc=$3
    echo ""
    echo -e "${PURPLE}=== [$step_num/$total_steps] $step_desc ===${NC}"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
}

# Выполнение команды с обработкой ошибок
run_check() {
    local description=$1
    local command=$2
    local expect_success=${3:-true}

    log_verbose "Выполнение: $command"

    if [ "$expect_success" = "true" ]; then
        if eval "$command" >/dev/null 2>&1; then
            log_success "$description"
            return 0
        else
            log_error "$description"
            return 1
        fi
    else
        if ! eval "$command" >/dev/null 2>&1; then
            log_success "$description"
            return 0
        else
            log_error "$description"
            return 1
        fi
    fi
}

# Проверка что скрипт запущен с Server ноды
check_server_node() {
    print_step 1 10 "Проверка Server ноды"

    # Проверка доступности kubectl
    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "kubectl не найден. Скрипт должен запускаться с Server ноды"
        exit 1
    fi
    log_success "kubectl доступен"

    # Проверка что k3s Server запущен
    if ! systemctl is-active --quiet k3s 2>/dev/null; then
        log_error "k3s Server service не запущен"
        log_info "Запустите: sudo systemctl start k3s"
        exit 1
    fi
    log_success "k3s Server service активен"

    # Проверка API Server
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "API Server недоступен"
        log_info "Проверьте: sudo systemctl status k3s"
        exit 1
    fi
    log_success "API Server отвечает"

    # Получение информации о кластере
    local cluster_info=$(kubectl cluster-info 2>/dev/null | head -1)
    log_info "$cluster_info"

    # Проверка что это текущая Server нода
    local current_hostname=$(hostname)
    if kubectl get nodes | grep -q "$current_hostname.*control-plane"; then
        log_success "Скрипт запущен с правильной Server ноды: $current_hostname"
    else
        log_warning "Возможно скрипт запущен не с Server ноды"
    fi
}

# Проверка статуса и количества нод
check_nodes_status() {
    print_step 2 10 "Проверка статуса нод"

    # Получение списка нод
    local nodes_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d '\n ')
    local ready_count=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " 2>/dev/null || echo "0" | tr -d '\n ')
    local notready_count=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " NotReady " 2>/dev/null || echo "0" | tr -d '\n ')

    log_info "Всего нод в кластере: $nodes_count"
    log_info "Ready нод: $ready_count"
    log_info "NotReady нод: $notready_count"

    # Проверка ожидаемого количества нод
    if [ "$nodes_count" -eq "$EXPECTED_NODES" ]; then
        log_success "Количество нод соответствует ожидаемому: $EXPECTED_NODES"
    else
        log_warning "Количество нод ($nodes_count) не соответствует ожидаемому ($EXPECTED_NODES)"
    fi

    # Проверка что все ноды Ready
    if [ "$ready_count" -eq "$nodes_count" ] && [ "$notready_count" -eq 0 ]; then
        log_success "Все ноды в статусе Ready"
    else
        log_error "Не все ноды Ready. Ready: $ready_count, NotReady: $notready_count"

        if [ "$VERBOSE" = "true" ]; then
            log_verbose "Детали нод:"
            kubectl get nodes | sed 's/^/  /'
        fi
    fi

    # Проверка ролей нод
    local server_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "control-plane" 2>/dev/null || echo "0" | tr -d '\n ')
    local agent_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "<none>" 2>/dev/null || echo "0" | tr -d '\n ')

    log_info "Server нод (control-plane): $server_nodes"
    log_info "Agent нод (worker): $agent_nodes"

    if [ "$server_nodes" -ge 1 ]; then
        log_success "Найдены Server ноды: $server_nodes"
    else
        log_error "Server ноды не найдены"
    fi

    # Проверка версий k3s на нодах
    local versions=$(kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.kubeletVersion}' | tr ' ' '\n' | sort -u | wc -l)
    if [ "$versions" -eq 1 ]; then
        local version=$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}')
        log_success "Все ноды имеют одинаковую версию k3s: $version"
    else
        log_warning "Ноды имеют разные версии k3s"
        if [ "$VERBOSE" = "true" ]; then
            kubectl get nodes -o custom-columns="NODE:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion" --no-headers | sed 's/^/  /'
        fi
    fi
}

# Проверка системных pods
check_system_pods() {
    print_step 3 10 "Проверка системных компонентов"

    # Получение всех pods в системных namespaces
    local total_pods=$(kubectl get pods -A --no-headers 2>/dev/null | wc -l | tr -d '\n ')
    local running_pods=$(kubectl get pods -A --no-headers 2>/dev/null | grep -c " Running " 2>/dev/null || echo "0" | tr -d '\n ')
    local pending_pods=$(kubectl get pods -A --no-headers 2>/dev/null | grep -c " Pending " 2>/dev/null || echo "0" | tr -d '\n ')
    local failed_pods=$(kubectl get pods -A --no-headers 2>/dev/null | grep -c -E " (Failed|Error|CrashLoopBackOff|ImagePullBackOff) " 2>/dev/null || echo "0" | tr -d '\n ')

    log_info "Всего системных pods: $total_pods"
    log_info "Running pods: $running_pods"
    log_info "Pending pods: $pending_pods"
    log_info "Failed pods: $failed_pods"

    # Проверка что большинство pods Running
    if [ "$failed_pods" -eq 0 ] && [ "$pending_pods" -lt 3 ]; then
        log_success "Системные pods в хорошем состоянии"
    else
        log_error "Найдены проблемные системные pods"

        if [ "$VERBOSE" = "true" ]; then
            log_verbose "Проблемные pods:"
            kubectl get pods -A --no-headers | grep -v " Running " | grep -v " Completed " | sed 's/^/  /'
        fi
    fi

    # Проверка конкретных системных компонентов
    check_coredns
    check_traefik
    check_metrics_server
    check_local_path_provisioner
}

# Проверка CoreDNS
check_coredns() {
    log_info "Проверка CoreDNS..."

    local coredns_pods=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -c " Running " || echo "0")

    if [ "$coredns_pods" -gt 0 ]; then
        log_success "CoreDNS работает ($coredns_pods pods)"

        # Тест DNS резолюции
        if kubectl run dns-test --image=busybox --rm -i --restart=Never --timeout=30s -- nslookup kubernetes.default >/dev/null 2>&1; then
            log_success "DNS резолюция работает"
        else
            log_warning "DNS резолюция не работает или недоступна"
        fi
    else
        log_error "CoreDNS не работает"
    fi
}

# Проверка Traefik
check_traefik() {
    log_info "Проверка Traefik Ingress Controller..."

    local traefik_pods=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik --no-headers 2>/dev/null | grep -c " Running " || echo "0")

    if [ "$traefik_pods" -gt 0 ]; then
        log_success "Traefik работает ($traefik_pods pods)"

        # Проверка Traefik service
        if kubectl get svc -n kube-system traefik >/dev/null 2>&1; then
            local external_ip=$(kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
            if [ -n "$external_ip" ]; then
                log_success "Traefik LoadBalancer получил External IP: $external_ip"
            else
                log_warning "Traefik LoadBalancer не имеет External IP (возможно еще назначается)"
            fi
        fi
    else
        log_error "Traefik не найден или не работает"
    fi
}

# Проверка Metrics Server
check_metrics_server() {
    log_info "Проверка Metrics Server..."

    local metrics_pods=$(kubectl get pods -n kube-system -l k8s-app=metrics-server --no-headers 2>/dev/null | grep -c " Running " || echo "0")

    if [ "$metrics_pods" -gt 0 ]; then
        log_success "Metrics Server работает ($metrics_pods pods)"

        # Тест получения метрик (может занять время после установки)
        if timeout 10 kubectl top nodes >/dev/null 2>&1; then
            log_success "Метрики нод доступны"
        else
            log_info "Метрики нод еще недоступны (нормально после недавней установки)"
        fi
    else
        log_warning "Metrics Server не найден (опционально для k3s)"
    fi
}

# Проверка Local Path Provisioner
check_local_path_provisioner() {
    log_info "Проверка Local Path Provisioner..."

    local lpp_pods=$(kubectl get pods -n kube-system -l app=local-path-provisioner --no-headers 2>/dev/null | grep -c " Running " || echo "0")

    if [ "$lpp_pods" -gt 0 ]; then
        log_success "Local Path Provisioner работает ($lpp_pods pods)"

        # Проверка StorageClass
        if kubectl get storageclass local-path >/dev/null 2>&1; then
            log_success "StorageClass 'local-path' доступен"
        else
            log_warning "StorageClass 'local-path' не найден"
        fi
    else
        log_error "Local Path Provisioner не найден"
    fi
}

# Тест pod scheduling на Agent нодах
test_pod_scheduling() {
    if [ "$TEST_DEPLOYMENT" != "true" ]; then
        log_info "Тестирование pod scheduling пропущено (TEST_DEPLOYMENT=false)"
        return 0
    fi

    print_step 4 10 "Тест pod scheduling"

    local test_deployment="cluster-validation-test"
    local test_replicas=3

    log_info "Создание тестового deployment: $test_deployment"

    # Очистить предыдущие тесты если есть
    kubectl delete deployment "$test_deployment" 2>/dev/null || true

    # Создать тестовый deployment
    if kubectl create deployment "$test_deployment" --image=nginx --replicas=$test_replicas >/dev/null 2>&1; then
        log_success "Тестовый deployment создан"
    else
        log_error "Не удалось создать тестовый deployment"
        return 1
    fi

    # Ожидание готовности pods
    log_info "Ожидание готовности test pods (до 120 сек)..."
    if kubectl wait --for=condition=ready pod -l app="$test_deployment" --timeout=120s >/dev/null 2>&1; then
        log_success "Test pods готовы"
    else
        log_error "Test pods не готовы в течение таймаута"
        kubectl get pods -l app="$test_deployment" | sed 's/^/  /'
        kubectl delete deployment "$test_deployment" 2>/dev/null || true
        return 1
    fi

    # Проверка распределения pods по нодам
    local unique_nodes=$(kubectl get pods -l app="$test_deployment" -o jsonpath='{.items[*].spec.nodeName}' | tr ' ' '\n' | sort -u | wc -l)
    local total_pods_scheduled=$(kubectl get pods -l app="$test_deployment" --no-headers | grep -c " Running " || echo "0")

    log_info "Test pods запущено: $total_pods_scheduled"
    log_info "Уникальных нод использовано: $unique_nodes"

    if [ "$total_pods_scheduled" -eq "$test_replicas" ]; then
        log_success "Все test pods успешно запущены"
    else
        log_error "Не все test pods запущены ($total_pods_scheduled/$test_replicas)"
    fi

    if [ "$unique_nodes" -gt 1 ]; then
        log_success "Pods распределены по нескольким нодам (хорошо для HA)"
    else
        log_warning "Все pods на одной ноде (проверьте scheduler и ресурсы нод)"
    fi

    # Показать распределение в verbose режиме
    if [ "$VERBOSE" = "true" ]; then
        log_verbose "Распределение test pods по нодам:"
        kubectl get pods -l app="$test_deployment" -o wide | sed 's/^/  /'
    fi

    # Очистка тестового deployment
    log_info "Удаление тестового deployment..."
    if kubectl delete deployment "$test_deployment" >/dev/null 2>&1; then
        log_success "Тестовый deployment удален"
    else
        log_warning "Не удалось удалить тестовый deployment"
    fi
}

# Проверка сети между pods
test_pod_networking() {
    if [ "$TEST_DEPLOYMENT" != "true" ]; then
        log_info "Тестирование pod networking пропущено (TEST_DEPLOYMENT=false)"
        return 0
    fi

    print_step 5 10 "Тест pod networking"

    log_info "Создание test pods для проверки сети..."

    # Создать test pods на разных нодах если возможно
    local server_node=$(kubectl get nodes --no-headers | grep "control-plane" | awk '{print $1}' | head -1)
    local agent_node=$(kubectl get nodes --no-headers | grep "<none>" | awk '{print $1}' | head -1)

    if [ -z "$server_node" ] || [ -z "$agent_node" ]; then
        log_warning "Не удалось найти Server и Agent ноды для network теста"
        return 0
    fi

    log_info "Server нода: $server_node"
    log_info "Agent нода: $agent_node"

    # Создать test pod на Server ноде
    kubectl run net-test-server --image=nginx --restart=Never --overrides="{\"spec\":{\"nodeSelector\":{\"kubernetes.io/hostname\":\"$server_node\"}}}" >/dev/null 2>&1 || true

    # Создать test pod на Agent ноде
    kubectl run net-test-agent --image=nginx --restart=Never --overrides="{\"spec\":{\"nodeSelector\":{\"kubernetes.io/hostname\":\"$agent_node\"}}}" >/dev/null 2>&1 || true

    # Ждать готовности pods
    sleep 10

    if kubectl wait --for=condition=ready pod net-test-server --timeout=60s >/dev/null 2>&1 &&
       kubectl wait --for=condition=ready pod net-test-agent --timeout=60s >/dev/null 2>&1; then
        log_success "Network test pods готовы"
    else
        log_error "Network test pods не готовы"
        kubectl delete pod net-test-server net-test-agent 2>/dev/null || true
        return 1
    fi

    # Получить IP адреса pods
    local server_pod_ip=$(kubectl get pod net-test-server -o jsonpath='{.status.podIP}' 2>/dev/null)
    local agent_pod_ip=$(kubectl get pod net-test-agent -o jsonpath='{.status.podIP}' 2>/dev/null)

    log_info "Server pod IP: $server_pod_ip"
    log_info "Agent pod IP: $agent_pod_ip"

    # Тест connectivity Server → Agent
    if kubectl exec net-test-server -- ping -c 2 -W 5 "$agent_pod_ip" >/dev/null 2>&1; then
        log_success "Connectivity Server → Agent: OK"
    else
        log_error "Connectivity Server → Agent: Failed"
    fi

    # Тест connectivity Agent → Server
    if kubectl exec net-test-agent -- ping -c 2 -W 5 "$server_pod_ip" >/dev/null 2>&1; then
        log_success "Connectivity Agent → Server: OK"
    else
        log_error "Connectivity Agent → Server: Failed"
    fi

    # HTTP тест
    if kubectl exec net-test-server -- curl -s -m 5 "$agent_pod_ip" >/dev/null 2>&1; then
        log_success "HTTP connectivity Server → Agent: OK"
    else
        log_warning "HTTP connectivity Server → Agent: Failed (возможно nginx еще не готов)"
    fi

    # Очистка test pods
    kubectl delete pod net-test-server net-test-agent 2>/dev/null || true
    log_success "Network test pods удалены"
}

# Проверка Flannel CNI
check_flannel_cni() {
    print_step 6 10 "Проверка Flannel CNI"

    # Получить список всех нод
    local nodes=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
    local flannel_ok=true

    log_info "Проверка Flannel интерфейсов на всех нодах..."

    for node in $nodes; do
        # Определить IP ноды
        local node_ip=$(kubectl get node "$node" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')

        log_info "Проверка ноды: $node ($node_ip)"

        # Проверка flannel.1 интерфейса
        if [ "$SKIP_AGENT_SSH" != "true" ] && [ "$node" != "$(hostname)" ]; then
            # SSH проверка для Agent нод
            if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "k3s-admin@$node_ip" "ip addr show flannel.1" >/dev/null 2>&1; then
                local flannel_ip=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "k3s-admin@$node_ip" "ip addr show flannel.1 | grep 'inet ' | awk '{print \$2}'" 2>/dev/null)
                log_success "Flannel на $node: $flannel_ip"
            else
                log_warning "Не удалось проверить Flannel на $node (SSH недоступен или интерфейс отсутствует)"
                flannel_ok=false
            fi
        else
            # Локальная проверка для Server ноды
            if ip addr show flannel.1 >/dev/null 2>&1; then
                local flannel_ip=$(ip addr show flannel.1 | grep 'inet ' | awk '{print $2}')
                log_success "Flannel на $node (localhost): $flannel_ip"
            else
                log_error "Flannel интерфейс отсутствует на $node"
                flannel_ok=false
            fi
        fi
    done

    if [ "$flannel_ok" = "true" ]; then
        log_success "Flannel CNI работает на всех проверенных нодах"
    else
        log_warning "Обнаружены проблемы с Flannel CNI"
    fi

    # Проверка pod CIDR ranges
    log_info "Проверка pod CIDR диапазонов..."
    local pod_cidrs=$(kubectl get nodes -o jsonpath='{.items[*].spec.podCIDR}' | tr ' ' '\n' | sort | uniq)
    local cidr_count=$(echo "$pod_cidrs" | grep -v '^$' | wc -l)

    if [ "$cidr_count" -eq "$(echo "$nodes" | wc -w)" ]; then
        log_success "Каждая нода имеет уникальный pod CIDR"
        if [ "$VERBOSE" = "true" ]; then
            log_verbose "Pod CIDR диапазоны:"
            echo "$pod_cidrs" | grep -v '^$' | sed 's/^/  /'
        fi
    else
        log_warning "Не все ноды имеют назначенные pod CIDR диапазоны"
    fi
}

# Проверка storage
test_storage() {
    if [ "$TEST_DEPLOYMENT" != "true" ]; then
        log_info "Тестирование storage пропущено (TEST_DEPLOYMENT=false)"
        return 0
    fi

    print_step 7 10 "Тест persistent storage"

    # Проверка наличия default StorageClass
    local default_sc=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}' 2>/dev/null)

    if [ -n "$default_sc" ]; then
        log_success "Default StorageClass найден: $default_sc"
    else
        log_warning "Default StorageClass не найден"
        return 0
    fi

    # Создать простой PVC для тестирования
    local test_pvc="storage-validation-test"

    log_info "Создание тестового PVC: $test_pvc"

    cat << EOF | kubectl apply -f - >/dev/null 2>&1
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $test_pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

    # Ждать bound статуса
    if kubectl wait --for=condition=Bound pvc "$test_pvc" --timeout=60s >/dev/null 2>&1; then
        log_success "PVC успешно bound к PV"

        # Получить информацию о созданном PV
        local pv_name=$(kubectl get pvc "$test_pvc" -o jsonpath='{.spec.volumeName}')
        if [ -n "$pv_name" ]; then
            log_info "Создан PV: $pv_name"
        fi
    else
        log_error "PVC не перешел в Bound статус"
    fi

    # Очистка тестового PVC
    kubectl delete pvc "$test_pvc" >/dev/null 2>&1 || true
    log_success "Тестовый PVC удален"
}

# Проверка LoadBalancer и ServiceLB
test_load_balancer() {
    if [ "$TEST_DEPLOYMENT" != "true" ]; then
        log_info "Тестирование LoadBalancer пропущено (TEST_DEPLOYMENT=false)"
        return 0
    fi

    print_step 8 10 "Тест LoadBalancer services"

    local test_service="lb-validation-test"

    log_info "Создание тестового LoadBalancer service..."

    # Создать deployment и service
    kubectl create deployment "$test_service" --image=nginx --replicas=2 >/dev/null 2>&1 || true
    kubectl expose deployment "$test_service" --port=80 --type=LoadBalancer >/dev/null 2>&1 || true

    # Ждать назначения External IP
    log_info "Ожидание назначения External IP (до 60 сек)..."

    local external_ip=""
    local timeout=60
    local counter=0

    while [ $counter -lt $timeout ]; do
        external_ip=$(kubectl get svc "$test_service" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ -n "$external_ip" ]; then
            break
        fi
        sleep 5
        counter=$((counter + 5))
    done

    if [ -n "$external_ip" ]; then
        log_success "LoadBalancer получил External IP: $external_ip"

        # Тест HTTP доступности (опционально)
        if curl -s -m 5 "http://$external_ip" >/dev/null 2>&1; then
            log_success "HTTP доступ к LoadBalancer работает"
        else
            log_info "HTTP тест пропущен (возможно firewall или pods не готовы)"
        fi
    else
        log_warning "LoadBalancer не получил External IP (ServiceLB может быть не настроен)"
    fi

    # Очистка тестового сервиса
    kubectl delete service "$test_service" >/dev/null 2>&1 || true
    kubectl delete deployment "$test_service" >/dev/null 2>&1 || true
    log_success "Тестовый LoadBalancer удален"
}

# Проверка Agent нод через SSH
check_agent_nodes_ssh() {
    if [ "$SKIP_AGENT_SSH" = "true" ]; then
        log_info "SSH проверки Agent нод пропущены (SKIP_AGENT_SSH=true)"
        return 0
    fi

    print_step 9 10 "Проверка Agent нод через SSH"

    local agent_nodes=$(kubectl get nodes --no-headers | grep "<none>" | awk '{print $1}')

    if [ -z "$agent_nodes" ]; then
        log_info "Agent ноды не найдены или все ноды являются Server нодами"
        return 0
    fi

    for node in $agent_nodes; do
        local node_ip=$(kubectl get node "$node" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')

        log_info "Проверка Agent ноды: $node ($node_ip)"

        # SSH доступность
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "k3s-admin@$node_ip" "echo 'SSH OK'" >/dev/null 2>&1; then
            log_success "SSH доступ к $node: OK"
        else
            log_warning "SSH недоступен к $node"
            continue
        fi

        # k3s-agent service статус
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "k3s-admin@$node_ip" "systemctl is-active --quiet k3s-agent" >/dev/null 2>&1; then
            log_success "k3s-agent service на $node: активен"
        else
            log_error "k3s-agent service на $node: неактивен"
        fi

        # Проверка ресурсов
        local memory=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "k3s-admin@$node_ip" "free -m | awk 'NR==2{print \$7}'" 2>/dev/null)
        local disk=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "k3s-admin@$node_ip" "df / | awk 'NR==2{print int(\$4/1024/1024)}'" 2>/dev/null)

        if [ -n "$memory" ] && [ -n "$disk" ]; then
            log_info "Ресурсы $node: ${memory}MB RAM, ${disk}GB диск свободно"

            if [ "$memory" -lt 256 ]; then
                log_warning "Мало свободной памяти на $node: ${memory}MB"
            fi

            if [ "$disk" -lt 5 ]; then
                log_warning "Мало свободного места на $node: ${disk}GB"
            fi
        fi
    done
}

# Финальная сводка и генерация отчета
generate_final_report() {
    print_step 10 10 "Генерация итогового отчета"

    echo ""
    echo -e "${PURPLE}================================================================${NC}"
    echo -e "${PURPLE}              ОТЧЕТ ВАЛИДАЦИИ k3s КЛАСТЕРА                     ${NC}"
    echo -e "${PURPLE}================================================================${NC}"
    echo ""

    # Сводная статистика
    echo -e "${CYAN}СТАТИСТИКА ПРОВЕРОК:${NC}"
    echo -e "  ${GREEN}Успешно:${NC} $PASSED_CHECKS"
    echo -e "  ${RED}Ошибки:${NC} $FAILED_CHECKS"
    echo -e "  ${YELLOW}Предупреждения:${NC} $WARNING_CHECKS"
    echo -e "  ${BLUE}Всего проверок:${NC} $TOTAL_CHECKS"
    echo ""

    # Статус кластера
    local cluster_health="ЗДОРОВЫЙ"
    local health_color=$GREEN

    if [ "$FAILED_CHECKS" -gt 0 ]; then
        cluster_health="ПРОБЛЕМЫ"
        health_color=$RED
    elif [ "$WARNING_CHECKS" -gt 3 ]; then
        cluster_health="ПРЕДУПРЕЖДЕНИЯ"
        health_color=$YELLOW
    fi

    echo -e "${CYAN}ОБЩИЙ СТАТУС КЛАСТЕРА:${NC} ${health_color}$cluster_health${NC}"
    echo ""

    # Информация о кластере
    echo -e "${CYAN}ИНФОРМАЦИЯ О КЛАСТЕРЕ:${NC}"

    local nodes_info=$(kubectl get nodes --no-headers 2>/dev/null)
    local total_nodes=$(echo "$nodes_info" | wc -l)
    local ready_nodes=$(echo "$nodes_info" | grep -c " Ready ")
    local server_nodes=$(echo "$nodes_info" | grep -c "control-plane")
    local agent_nodes=$(echo "$nodes_info" | grep -c "<none>")

    echo -e "  ${YELLOW}Всего нод:${NC} $total_nodes"
    echo -e "  ${YELLOW}Ready нод:${NC} $ready_nodes"
    echo -e "  ${YELLOW}Server нод:${NC} $server_nodes"
    echo -e "  ${YELLOW}Agent нод:${NC} $agent_nodes"

    local k3s_version=$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}' 2>/dev/null)
    echo -e "  ${YELLOW}Версия k3s:${NC} $k3s_version"

    local cluster_info=$(kubectl cluster-info 2>/dev/null | head -1)
    echo -e "  ${YELLOW}API Server:${NC} $cluster_info"
    echo ""

    # Системные компоненты
    echo -e "${CYAN}СИСТЕМНЫЕ КОМПОНЕНТЫ:${NC}"

    local coredns=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -c " Running " || echo "0")
    local traefik=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik --no-headers 2>/dev/null | grep -c " Running " || echo "0")
    local metrics=$(kubectl get pods -n kube-system -l k8s-app=metrics-server --no-headers 2>/dev/null | grep -c " Running " || echo "0")
    local storage=$(kubectl get pods -n kube-system -l app=local-path-provisioner --no-headers 2>/dev/null | grep -c " Running " || echo "0")

    echo -e "  ${YELLOW}CoreDNS:${NC} $coredns pods"
    echo -e "  ${YELLOW}Traefik:${NC} $traefik pods"
    echo -e "  ${YELLOW}Metrics Server:${NC} $metrics pods"
    echo -e "  ${YELLOW}Storage Provisioner:${NC} $storage pods"
    echo ""

    # Рекомендации
    echo -e "${CYAN}РЕКОМЕНДАЦИИ:${NC}"

    if [ "$FAILED_CHECKS" -gt 0 ]; then
        echo -e "  ${RED}• Исправьте обнаруженные ошибки перед использованием в production${NC}"
        echo -e "  ${RED}• Проверьте логи проблемных компонентов${NC}"
    fi

    if [ "$WARNING_CHECKS" -gt 0 ]; then
        echo -e "  ${YELLOW}• Обратите внимание на предупреждения${NC}"
        echo -e "  ${YELLOW}• Рассмотрите улучшение конфигурации${NC}"
    fi

    if [ "$ready_nodes" -lt "$total_nodes" ]; then
        echo -e "  ${RED}• Приведите все ноды в Ready статус${NC}"
    fi

    if [ "$agent_nodes" -lt 2 ]; then
        echo -e "  ${YELLOW}• Рекомендуется минимум 2 Agent ноды для HA${NC}"
    fi

    if [ "$FAILED_CHECKS" -eq 0 ] && [ "$WARNING_CHECKS" -lt 3 ]; then
        echo -e "  ${GREEN}• Кластер готов к развертыванию приложений!${NC}"
        echo -e "  ${GREEN}• Все основные компоненты работают корректно${NC}"
    fi

    echo ""

    # Полезные команды
    echo -e "${CYAN}ПОЛЕЗНЫЕ КОМАНДЫ ДЛЯ МОНИТОРИНГА:${NC}"
    echo -e "  ${GREEN}kubectl get nodes -o wide${NC}                 # Статус нод"
    echo -e "  ${GREEN}kubectl get pods -A${NC}                       # Все pods"
    echo -e "  ${GREEN}kubectl top nodes${NC}                         # Метрики нод"
    echo -e "  ${GREEN}kubectl get events --sort-by=.metadata.creationTimestamp${NC} # События"
    echo ""

    # Логи для troubleshooting
    if [ "$FAILED_CHECKS" -gt 0 ] || [ "$WARNING_CHECKS" -gt 2 ]; then
        echo -e "${CYAN}КОМАНДЫ ДЛЯ TROUBLESHOOTING:${NC}"
        echo -e "  ${GREEN}sudo systemctl status k3s${NC}                # Статус Server"
        echo -e "  ${GREEN}sudo journalctl -u k3s -n 50${NC}             # Логи Server"
        echo -e "  ${GREEN}kubectl describe nodes${NC}                   # Детали нод"
        echo -e "  ${GREEN}kubectl get events --field-selector type=Warning${NC} # Предупреждения"
        echo ""
    fi

    echo -e "${PURPLE}================================================================${NC}"
    echo -e "${PURPLE}                     Валидация завершена                       ${NC}"
    echo -e "${PURPLE}================================================================${NC}"
}

# Функция показа справки
show_usage() {
    cat << EOF
${GREEN}k3s Cluster Validator${NC} v${SCRIPT_VERSION}

${YELLOW}ОПИСАНИЕ:${NC}
    Комплексная валидация k3s кластера после установки Agent нод

${YELLOW}ИСПОЛЬЗОВАНИЕ:${NC}
    $0 [опции]

${YELLOW}ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ:${NC}
    ${CYAN}EXPECTED_NODES${NC}     - Ожидаемое количество нод (по умолчанию: 3)
    ${CYAN}SKIP_AGENT_SSH${NC}     - Пропустить SSH проверки Agent (по умолчанию: false)
    ${CYAN}VERBOSE${NC}            - Подробный вывод (по умолчанию: false)
    ${CYAN}TEST_DEPLOYMENT${NC}    - Создавать тестовые deployment (по умолчанию: true)

${YELLOW}ПРИМЕРЫ:${NC}
    # Базовая валидация
    ${GREEN}$0${NC}

    # Подробная валидация с тестированием
    ${GREEN}VERBOSE=true $0${NC}

    # Валидация без SSH к Agent нодам
    ${GREEN}SKIP_AGENT_SSH=true $0${NC}

    # Валидация для 5-node кластера
    ${GREEN}EXPECTED_NODES=5 $0${NC}

    # Удаленная валидация через SSH
    ${GREEN}ssh k3s-admin@10.246.10.50 "$(cat $0)"${NC}

${YELLOW}ТРЕБОВАНИЯ:${NC}
    - Запуск с Server ноды (где доступен kubectl)
    - kubectl настроен для доступа к кластеру
    - SSH доступ к Agent нодам (для полной валидации)
    - k3s кластер запущен и базово функционален

${YELLOW}ПРОВЕРЯЕМЫЕ КОМПОНЕНТЫ:${NC}
    • Статус нод и их готовность
    • Системные pods (CoreDNS, Traefik, Storage)
    • Pod scheduling на Agent нодах
    • Сетевое взаимодействие между pods
    • Flannel CNI работоспособность
    • Persistent Storage
    • LoadBalancer services
    • SSH доступ к Agent нодам

EOF
}

# Главная функция
main() {
    # Проверка аргументов
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        show_usage
        exit 0
    fi

    # Вывод заголовка
    echo -e "${PURPLE}================================================================${NC}"
    echo -e "${PURPLE}    k3s Cluster Validator v${SCRIPT_VERSION}                          ${NC}"
    echo -e "${PURPLE}    Комплексная валидация k3s кластера                          ${NC}"
    echo -e "${PURPLE}================================================================${NC}"
    echo ""

    log_info "Начало валидации k3s кластера..."
    log_info "Ожидаемое количество нод: $EXPECTED_NODES"
    log_info "SSH проверки Agent нод: $([ "$SKIP_AGENT_SSH" = "true" ] && echo "выключены" || echo "включены")"
    log_info "Тестовые deployment: $([ "$TEST_DEPLOYMENT" = "true" ] && echo "включены" || echo "выключены")"
    log_info "Подробный вывод: $([ "$VERBOSE" = "true" ] && echo "включен" || echo "выключен")"

    # Выполнение всех проверок
    check_server_node
    check_nodes_status
    check_system_pods
    test_pod_scheduling
    test_pod_networking
    check_flannel_cni
    test_storage
    test_load_balancer
    check_agent_nodes_ssh
    generate_final_report

    # Определение exit кода
    if [ "$FAILED_CHECKS" -gt 0 ]; then
        exit 1
    elif [ "$WARNING_CHECKS" -gt 5 ]; then
        exit 2
    else
        exit 0
    fi
}

# Запуск скрипта если вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
