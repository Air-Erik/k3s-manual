# Задание для AI-агента: Установка k3s Agent Nodes

> **Этап:** 1.2 - Agent Nodes Setup
> **Ответственный:** AI-агент + Оператор
> **Статус:** 🚀 В работе
> **Дата создания:** 2025-10-24

---

## 📋 Контекст

Ты AI-агент, работающий над проектом **k3s на VMware vSphere с NSX-T**.

### Что уже готово:
- ✅ **VM Template:** `k3s-ubuntu2404-minimal-template` создан
- ✅ **Cloud-init конфигурации:** Готовы для Agent нод
- ✅ **k3s Server Node:** Установлена и работает (10.246.10.50)
- ✅ **kubeconfig:** Получен и работает
- ✅ **node-token:** Сохранён для присоединения Agent нод

### Что делаем сейчас:
**Присоединяем 2 Agent ноды** к кластеру для запуска workload!

---

## 🎯 Цель задания

Установить **k3s в режиме agent** на 2 нодах и присоединить их к Server:
1. **Agent Node 1:** 10.246.10.51 (k3s-agent-01)
2. **Agent Node 2:** 10.246.10.52 (k3s-agent-02)

**Результат:** Кластер из 3 нод (1 Server + 2 Agent), все в Ready состоянии.

---

## 💡 Что такое k3s Agent Node?

**k3s Agent Node** включает только:
- **kubelet:** Для управления pods на ноде
- **kube-proxy:** Для сетевой маршрутизации
- **containerd:** Встроенный container runtime
- **Flannel:** CNI для pod networking

**НЕ включает Control Plane компоненты** (API Server, etcd, scheduler, controller).

**Установка = ОДНА команда:**
```bash
curl -sfL https://get.k3s.io | K3S_URL=https://SERVER_IP:6443 K3S_TOKEN=xxx sh -s - agent
```

Agent нода автоматически подключается к Server используя **node-token**.

---

## 🔧 Твоя роль как AI-агента

Ты эксперт по установке k3s Agent нод. Твоя задача:

1. **Создать пошаговые инструкции** для оператора
2. **Написать универсальный скрипт** установки k3s Agent
3. **Документировать процесс** присоединения к кластеру
4. **Подготовить валидационные проверки**
5. **Создать troubleshooting guide**

**Важно:** Все артефакты должны быть **готовы к использованию** без изменений!

---

## 📊 Исходные данные

### Server Node (уже работает):
```yaml
Server IP: 10.246.10.50
API Server: https://10.246.10.50:6443
Node Token: [оператор получил из /var/lib/rancher/k3s/server/node-token]
```

### Agent Node 1 Specification:
```yaml
Hostname: k3s-agent-01
IP Address: 10.246.10.51
Gateway: 10.246.10.1
DNS: 172.17.10.3, 8.8.8.8
Network Interface: ens192
vCPU: 2
RAM: 2 GB
Disk: 40 GB

SSH User: k8s-admin
SSH Auth: password (admin) или SSH key
```

### Agent Node 2 Specification:
```yaml
Hostname: k3s-agent-02
IP Address: 10.246.10.52
Gateway: 10.246.10.1
DNS: 172.17.10.3, 8.8.8.8
Network Interface: ens192
vCPU: 2
RAM: 2 GB
Disk: 40 GB

SSH User: k8s-admin
SSH Auth: password (admin) или SSH key
```

### k3s Installation Parameters:
```yaml
Installation Method: curl https://get.k3s.io
k3s Version: latest stable (автоматически та же что на Server)
Server URL: https://10.246.10.50:6443
Node Token: [получен из Server ноды]
```

---

## 📝 Структура задания

Создай следующие артефакты **последовательно**:

---

### Этап 1: Обзор процесса присоединения Agent

**Создай:** `research/agent-nodes-setup/01-agent-overview.md`

**Содержание:**
- Что такое Agent нода в k3s
- Чем отличается от Server ноды
- Процесс join к кластеру
- Что происходит при присоединении
- Роль node-token
- Сетевое взаимодействие Server ↔ Agent

**Сравнение Server vs Agent:**
```yaml
Server Node:
  - API Server, Controller, Scheduler, etcd
  - Kubelet (может запускать workloads)
  - Управляет кластером

Agent Node:
  - ТОЛЬКО kubelet + kube-proxy
  - Запускает workload pods
  - Подчиняется Server ноде
```

---

### Этап 2: Получение node-token с Server

**Создай:** `research/agent-nodes-setup/02-get-node-token.md`

**Содержание:**

#### 2.1. Где находится node-token
```bash
# На Server ноде (10.246.10.50)
/var/lib/rancher/k3s/server/node-token
```

#### 2.2. Как получить
```bash
# SSH к Server ноде
ssh k8s-admin@10.246.10.50

# Прочитать token
sudo cat /var/lib/rancher/k3s/server/node-token

# Пример вывода:
K10abcd1234567890::server:1234567890abcdef1234567890abcdef
```

#### 2.3. Безопасность token
- Token даёт полный доступ к присоединению нод
- Храните token в безопасном месте
- Не коммитьте в git!
- Можно использовать переменную окружения

#### 2.4. Сохранение для использования
```bash
# На локальной машине оператора
mkdir -p ~/k3s-credentials
ssh k8s-admin@10.246.10.50 "sudo cat /var/lib/rancher/k3s/server/node-token" > ~/k3s-credentials/node-token.txt

echo "Token сохранён в ~/k3s-credentials/node-token.txt"
```

---

### Этап 3: Клонирование VM для Agent нод

**Создай:** `research/agent-nodes-setup/03-clone-vms-for-agents.md`

**Содержание:**

#### 3.1. Клонирование Agent Node 1
- Пошаговая инструкция клонирования из Template в vSphere UI
- Применение cloud-init для Agent-01 (10.246.10.51)
- Использование `manifests/cloud-init/agent-node-01-userdata.yaml` и `agent-node-01-metadata.yaml`
- Первый boot и проверка

#### 3.2. Клонирование Agent Node 2
- Аналогичный процесс для Agent-02 (10.246.10.52)
- Использование `manifests/cloud-init/agent-node-02-userdata.yaml` и `agent-node-02-metadata.yaml`

#### 3.3. Проверка после клонирования
Для каждой ноды:
```bash
# SSH подключение
ssh k8s-admin@10.246.10.51  # Agent-01
ssh k8s-admin@10.246.10.52  # Agent-02

# Проверить hostname
hostname
# Должно быть: k3s-agent-01 или k3s-agent-02

# Проверить IP
ip addr show ens192

# Проверить connectivity к Server
ping 10.246.10.50
curl -k https://10.246.10.50:6443/version
```

---

### Этап 4: Скрипт установки k3s Agent

**Создай:** `scripts/install-k3s-agent.sh`

**Содержание:**
- Универсальный скрипт для установки Agent на любой ноде
- Принимает параметры: SERVER_URL, NODE_TOKEN, NODE_IP, NODE_NAME
- Проверка prerequisites
- Установка k3s agent
- Валидация успешности

**Требования:**
- Idempotent (можно запускать несколько раз)
- Обработка ошибок
- Логирование
- Цветной вывод
- Комментарии на русском

**Пример структуры:**
```bash
#!/bin/bash
# Скрипт установки k3s Agent Node
# Версия: 1.0
# Дата: 2025-10-24

set -e -o pipefail

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Параметры (передаются как аргументы или environment variables)
SERVER_URL="${K3S_SERVER_URL:-https://10.246.10.50:6443}"
NODE_TOKEN="${K3S_NODE_TOKEN}"
NODE_IP="${K3S_NODE_IP}"
NODE_NAME="${K3S_NODE_NAME}"

echo -e "${GREEN}=== Установка k3s Agent Node ===${NC}"
echo "Server URL: $SERVER_URL"
echo "Node IP: $NODE_IP"
echo "Node Name: $NODE_NAME"

# Проверка обязательных параметров
if [ -z "$NODE_TOKEN" ]; then
    echo -e "${RED}Ошибка: NODE_TOKEN не задан!${NC}"
    echo "Использование: K3S_NODE_TOKEN=xxx K3S_NODE_IP=10.246.10.51 K3S_NODE_NAME=k3s-agent-01 $0"
    exit 1
fi

# 1. Проверка prerequisites
echo -e "${YELLOW}[1/5] Проверка prerequisites...${NC}"
# Проверка connectivity к Server
if ! curl -k -s --connect-timeout 5 ${SERVER_URL}/version > /dev/null; then
    echo -e "${RED}Ошибка: Server ${SERVER_URL} недоступен!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Server доступен${NC}"

# 2. Установка k3s agent
echo -e "${YELLOW}[2/5] Установка k3s agent...${NC}"
curl -sfL https://get.k3s.io | K3S_URL=${SERVER_URL} K3S_TOKEN=${NODE_TOKEN} sh -s - agent \
  --node-ip ${NODE_IP} \
  --node-name ${NODE_NAME}

# 3. Ожидание запуска
echo -e "${YELLOW}[3/5] Ожидание запуска k3s-agent...${NC}"
sleep 10
sudo systemctl is-active --quiet k3s-agent && echo -e "${GREEN}✓ k3s-agent service активен${NC}"

# 4. Проверка присоединения к кластеру
echo -e "${YELLOW}[4/5] Проверка присоединения к кластеру...${NC}"
# Нужно проверить с Server ноды (через SSH или kubeconfig)

# 5. Итоговый статус
echo -e "${YELLOW}[5/5] Проверка статуса...${NC}"
sudo systemctl status k3s-agent --no-pager

echo -e "${GREEN}✅ k3s Agent успешно установлен!${NC}"
echo ""
echo "Проверьте с Server ноды:"
echo "  kubectl get nodes"
```

**Параметры установки:**
```bash
K3S_URL=https://10.246.10.50:6443   # Server API endpoint
K3S_TOKEN=xxx                        # Node token из Server
--node-ip 10.246.10.51              # IP адрес Agent ноды
--node-name k3s-agent-01            # Имя ноды в кластере
```

---

### Этап 5: Пошаговые инструкции установки

**Создай:** `research/agent-nodes-setup/04-installation-steps.md`

**Содержание:**

#### 5.1. Подготовка
```bash
# 1. Получить node-token с Server ноды (если ещё не получен)
ssh k8s-admin@10.246.10.50
sudo cat /var/lib/rancher/k3s/server/node-token
# Скопировать token

# 2. Сохранить в переменную
export K3S_NODE_TOKEN="K10abcd..."
```

#### 5.2. Установка Agent Node 1
```bash
# 1. SSH к Agent-01
ssh k8s-admin@10.246.10.51

# 2. Загрузить скрипт (если есть на локальной машине)
# scp scripts/install-k3s-agent.sh k8s-admin@10.246.10.51:~/

# 3. Или установить напрямую
export K3S_NODE_TOKEN="K10abcd..."
export K3S_NODE_IP="10.246.10.51"
export K3S_NODE_NAME="k3s-agent-01"

curl -sfL https://get.k3s.io | K3S_URL=https://10.246.10.50:6443 \
  K3S_TOKEN=${K3S_NODE_TOKEN} sh -s - agent \
  --node-ip ${K3S_NODE_IP} \
  --node-name ${K3S_NODE_NAME}

# 4. Проверить статус
sudo systemctl status k3s-agent
```

#### 5.3. Установка Agent Node 2
```bash
# Аналогично Agent-01, но с параметрами Agent-02
ssh k8s-admin@10.246.10.52

export K3S_NODE_TOKEN="K10abcd..."
export K3S_NODE_IP="10.246.10.52"
export K3S_NODE_NAME="k3s-agent-02"

curl -sfL https://get.k3s.io | K3S_URL=https://10.246.10.50:6443 \
  K3S_TOKEN=${K3S_NODE_TOKEN} sh -s - agent \
  --node-ip ${K3S_NODE_IP} \
  --node-name ${K3S_NODE_NAME}

sudo systemctl status k3s-agent
```

#### 5.4. Альтернатива: Использование скрипта
```bash
# На Agent ноде
chmod +x ~/install-k3s-agent.sh

K3S_NODE_TOKEN="xxx" \
K3S_NODE_IP="10.246.10.51" \
K3S_NODE_NAME="k3s-agent-01" \
./install-k3s-agent.sh
```

---

### Этап 6: Валидация кластера

**Создай:** `research/agent-nodes-setup/05-validate-cluster.md`

**Содержание:**

#### 6.1. Проверка с Server ноды
```bash
# SSH к Server
ssh k8s-admin@10.246.10.50

# Список нод (должно быть 3)
kubectl get nodes

# Ожидаемый вывод:
# NAME            STATUS   ROLES                  AGE   VERSION
# k3s-server-01   Ready    control-plane,master   20m   v1.30.x+k3s1
# k3s-agent-01    Ready    <none>                 5m    v1.30.x+k3s1
# k3s-agent-02    Ready    <none>                 3m    v1.30.x+k3s1

# Подробная информация
kubectl get nodes -o wide

# Должны видеть:
# - Все 3 ноды в Ready
# - IP адреса: .50, .51, .52
# - Одинаковые VERSION
```

#### 6.2. Проверка на Agent нодах
```bash
# На каждой Agent ноде
ssh k8s-admin@10.246.10.51  # или .52

# Статус service
sudo systemctl status k3s-agent

# Логи (последние 50 строк)
sudo journalctl -u k3s-agent -n 50

# Проверка kubelet
sudo k3s kubectl get nodes
# Должен вернуть ошибку: на Agent ноде нет прямого доступа к API
# Это нормально! API только на Server
```

#### 6.3. Проверка pod scheduling
```bash
# На Server ноде
kubectl get pods -A -o wide

# Проверить что pods распределены по нодам
# Должны видеть pods на всех 3 нодах

# Создать тестовый deployment
kubectl create deployment nginx-test --image=nginx --replicas=3

# Подождать запуска
kubectl wait --for=condition=ready pod -l app=nginx-test --timeout=60s

# Проверить распределение
kubectl get pods -o wide | grep nginx-test

# Должны видеть pods на разных нодах

# Удалить тест
kubectl delete deployment nginx-test
```

#### 6.4. Проверка сети между pods
```bash
# Создать test pod на Server
kubectl run test-server --image=nginx --labels="test=server"

# Создать test pod на Agent
kubectl run test-agent --image=nginx --labels="test=agent"

# Получить IPs
kubectl get pods -o wide

# Проверить connectivity
kubectl exec test-server -- curl -s test-agent
kubectl exec test-agent -- curl -s test-server

# Очистить
kubectl delete pod test-server test-agent
```

#### 6.5. Проверка Flannel
```bash
# На каждой ноде должен быть flannel интерфейс
# SSH к каждой ноде
ip addr show flannel.1

# Должен видеть IP из диапазона 10.42.x.x
```

#### 6.6. Итоговая валидация
```bash
# На Server ноде
kubectl get nodes
# Все 3 ноды Ready

kubectl get pods -A
# Все pods Running

kubectl cluster-info
# Kubernetes control plane is running at https://10.246.10.50:6443
```

---

### Этап 7: Troubleshooting Guide

**Создай:** `research/agent-nodes-setup/06-troubleshooting.md`

**Содержание:**

#### Проблема 1: Agent нода не присоединяется

**Симптомы:**
```bash
sudo journalctl -u k3s-agent -f
# Error: failed to contact server
```

**Решения:**
1. Проверить connectivity к Server:
```bash
curl -k https://10.246.10.50:6443/version
```

2. Проверить node-token:
```bash
# Token правильный?
# Получить заново с Server
```

3. Проверить firewall:
```bash
# Порт 6443 открыт?
sudo ufw status
```

#### Проблема 2: Node в состоянии NotReady

**Симптомы:**
```bash
kubectl get nodes
# k3s-agent-01   NotReady   <none>   5m
```

**Диагностика:**
```bash
kubectl describe node k3s-agent-01
# Смотреть Conditions и Events
```

**Решения:**
1. Проверить k3s-agent service на Agent ноде:
```bash
ssh k8s-admin@10.246.10.51
sudo systemctl status k3s-agent
sudo journalctl -u k3s-agent -n 100
```

2. Проверить Flannel:
```bash
ip addr show flannel.1
```

3. Перезапустить agent:
```bash
sudo systemctl restart k3s-agent
```

#### Проблема 3: Pods не запускаются на Agent

**Симптомы:**
```bash
kubectl get pods -o wide
# Все pods на Server ноде, Agent пустые
```

**Решения:**
1. Проверить taints:
```bash
kubectl describe node k3s-agent-01 | grep Taints
# Должно быть: Taints: <none>
```

2. Проверить resources:
```bash
kubectl describe node k3s-agent-01
# Смотреть Allocated resources
```

#### Проблема 4: Неправильный token

**Симптомы:**
```bash
# Agent не может подключиться
# Логи: authentication failed
```

**Решение:**
```bash
# Получить правильный token с Server
ssh k8s-admin@10.246.10.50
sudo cat /var/lib/rancher/k3s/server/node-token

# Переустановить Agent с правильным token
ssh k8s-admin@10.246.10.51
/usr/local/bin/k3s-agent-uninstall.sh
# Установить заново с правильным token
```

#### Проблема 5: Agent и Server разные версии k3s

**Симптомы:**
```bash
kubectl get nodes
# VERSION разные у Server и Agent
```

**Решение:**
```bash
# k3s автоматически использует ту же версию что Server
# Если версии разные — возможно установлена старая версия k3s

# Обновить k3s на Agent
ssh k8s-admin@10.246.10.51
curl -sfL https://get.k3s.io | K3S_URL=https://10.246.10.50:6443 \
  K3S_TOKEN=xxx sh -s - agent [параметры]
```

#### Проблема 6: Полное удаление Agent для переустановки

```bash
# На Agent ноде
sudo /usr/local/bin/k3s-agent-uninstall.sh

# Очистить данные
sudo rm -rf /var/lib/rancher/k3s/

# Установить заново
```

---

### Этап 8: Скрипт массовой валидации

**Создай:** `scripts/validate-k3s-cluster.sh`

**Содержание:**
- Автоматическая проверка всех нод
- Проверка connectivity между нодами
- Проверка pod scheduling
- Проверка системных компонентов
- Генерация отчёта

**Пример структуры:**
```bash
#!/bin/bash
# Скрипт валидации k3s кластера
# Запускается с Server ноды

set -e -o pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Валидация k3s кластера ===${NC}"
echo ""

# 1. Проверка нод
echo -e "${YELLOW}[1/5] Проверка нод...${NC}"
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
READY_COUNT=$(kubectl get nodes --no-headers | grep " Ready " | wc -l)

echo "Всего нод: $NODE_COUNT"
echo "Ready нод: $READY_COUNT"

if [ $NODE_COUNT -eq 3 ] && [ $READY_COUNT -eq 3 ]; then
    echo -e "${GREEN}✓ Все 3 ноды Ready${NC}"
else
    echo -e "${RED}✗ Не все ноды Ready!${NC}"
    kubectl get nodes
fi

# 2. Проверка системных pods
echo -e "${YELLOW}[2/5] Проверка системных pods...${NC}"
PODS_NOT_RUNNING=$(kubectl get pods -A --no-headers | grep -v "Running\|Completed" | wc -l)

if [ $PODS_NOT_RUNNING -eq 0 ]; then
    echo -e "${GREEN}✓ Все системные pods Running${NC}"
else
    echo -e "${RED}✗ Есть pods не в Running!${NC}"
    kubectl get pods -A | grep -v "Running\|Completed"
fi

# 3. Тест deployment
echo -e "${YELLOW}[3/5] Тест deployment...${NC}"
kubectl create deployment test-deploy --image=nginx --replicas=3 > /dev/null 2>&1
sleep 10
TEST_READY=$(kubectl get deployment test-deploy -o jsonpath='{.status.readyReplicas}')

if [ "$TEST_READY" -eq 3 ]; then
    echo -e "${GREEN}✓ Deployment успешен (3/3 replicas)${NC}"
else
    echo -e "${RED}✗ Deployment проблемы: $TEST_READY/3${NC}"
fi

kubectl delete deployment test-deploy > /dev/null 2>&1

# 4. Проверка Traefik
echo -e "${YELLOW}[4/5] Проверка Traefik...${NC}"
TRAEFIK=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik --no-headers | grep Running | wc -l)

if [ $TRAEFIK -gt 0 ]; then
    echo -e "${GREEN}✓ Traefik работает${NC}"
else
    echo -e "${RED}✗ Traefik не найден${NC}"
fi

# 5. Проверка CoreDNS
echo -e "${YELLOW}[5/5] Проверка CoreDNS...${NC}"
COREDNS=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers | grep Running | wc -l)

if [ $COREDNS -gt 0 ]; then
    echo -e "${GREEN}✓ CoreDNS работает${NC}"
else
    echo -e "${RED}✗ CoreDNS не найден${NC}"
fi

# Итог
echo ""
echo -e "${GREEN}=== Валидация завершена ===${NC}"
echo "Подробности:"
kubectl get nodes
echo ""
kubectl get pods -A
```

---

## 📦 Артефакты на выходе

После выполнения всех этапов должны быть созданы:

### Документация:
- [ ] `research/agent-nodes-setup/01-agent-overview.md`
- [ ] `research/agent-nodes-setup/02-get-node-token.md`
- [ ] `research/agent-nodes-setup/03-clone-vms-for-agents.md`
- [ ] `research/agent-nodes-setup/04-installation-steps.md`
- [ ] `research/agent-nodes-setup/05-validate-cluster.md`
- [ ] `research/agent-nodes-setup/06-troubleshooting.md`

### Скрипты:
- [ ] `scripts/install-k3s-agent.sh` — универсальная установка Agent
- [ ] `scripts/validate-k3s-cluster.sh` — валидация всего кластера

---

## ✅ Критерии успеха

Задание считается выполненным когда:

1. **Все артефакты созданы** и сохранены
2. **Скрипты готовы к использованию** без изменений
3. **Инструкции понятны** оператору

**Валидация успеха (выполнит оператор):**
- [ ] 2 VM для Agent нод клонированы
- [ ] k3s agent установлен на обеих нодах
- [ ] `systemctl status k3s-agent` = active на Agent нодах
- [ ] `kubectl get nodes` показывает 3 ноды в Ready
- [ ] Все системные pods Running
- [ ] Тестовый deployment успешно создаётся на Agent нодах
- [ ] Кластер полностью функционален

---

## 🎯 Порядок работы с оператором

### Для оператора:

**Шаг 1:** Прикрепи к AI-агенту файлы:
- `README.md`
- `nsx-configs/segments.md`
- `research/agent-nodes-setup/AI-AGENT-TASK.md` (это задание)

**Шаг 2:** Используй промпт:
```
Привет! Ты AI-агент, работающий над проектом k3s на vSphere.

Я прикрепил:
1. README.md — обзор проекта
2. nsx-configs/segments.md — параметры сети
3. AI-AGENT-TASK.md — твоя задача

Твоя задача: Установить k3s Agent Nodes и присоединить к кластеру.

Контекст:
- Этап 0 (VM Template) завершён ✅
- Этап 1.1 (k3s Server) завершён ✅
- Server нода работает на 10.246.10.50
- kubectl работает
- node-token получен
- Сейчас присоединяем 2 Agent ноды

Инфраструктура:
- Server IP: 10.246.10.50 (работает)
- Agent-01 IP: 10.246.10.51
- Agent-02 IP: 10.246.10.52
- DNS: 172.17.10.3, 8.8.8.8
- Gateway: 10.246.10.1

k3s Agent = ПРОСТОЕ присоединение одной командой!
curl -sfL https://get.k3s.io | K3S_URL=... K3S_TOKEN=... sh -s - agent

Пожалуйста:
1. Прочитай AI-AGENT-TASK.md полностью
2. Создавай артефакты последовательно (Этапы 1-8)
3. Пиши готовые скрипты
4. Фокус на простоте k3s!

Начнём с Этапа 1: Обзор процесса присоединения Agent.
Готов?
```

**Шаг 3:** Работай с AI итеративно

**Шаг 4:** После получения артефактов:
1. Получи node-token с Server ноды
2. Клонируй 2 VM для Agent нод
3. Применить cloud-init для IP .51 и .52
4. SSH к каждой Agent ноде
5. Установить k3s agent
6. Валидировать кластер

**Шаг 5:** Сообщи Team Lead о результатах

---

## ⏱️ Оценка времени

| Этап | AI создание | Оператор применение | Итого |
|------|-------------|---------------------|-------|
| Этапы 1-8 (документы + скрипты) | 12 мин | - | 12 мин |
| Получение node-token | - | 2 мин | 2 мин |
| Клонирование 2 VM | - | 6 мин | 6 мин |
| Установка Agent-01 | - | 5 мин | 5 мин |
| Установка Agent-02 | - | 5 мин | 5 мин |
| Валидация кластера | - | 5 мин | 5 мин |
| **ИТОГО** | **12 мин** | **23 мин** | **~35 мин** |

---

## 📚 Полезные ссылки для AI-агента

**Официальная документация:**
- [k3s Agent Node Configuration](https://docs.k3s.io/reference/agent-config)
- [k3s Cluster Setup](https://docs.k3s.io/cluster-access)
- [k3s High Availability](https://docs.k3s.io/datastore/ha)

**Важные замечания:**
- Agent нода НЕ имеет Control Plane компонентов
- node-token обязателен для присоединения
- Версия k3s на Agent должна совпадать с Server
- Agent автоматически получает версию с Server

---

## 🎉 Финальная проверка

Перед передачей результатов Team Lead, убедись что:

- ✅ Все 6 документов + 2 скрипта созданы
- ✅ Инструкции понятны и детальны
- ✅ Скрипт install-k3s-agent.sh универсален
- ✅ Скрипт validate-k3s-cluster.sh работает
- ✅ Troubleshooting guide полный

---

**Удачи, AI-агент! Создай отличную документацию для Agent нод! 🚀**

**После этого этапа у нас будет полноценный 3-node кластер!**

**Team Lead ждёт результатов для перехода к Этапу 2 (vSphere CSI).**
