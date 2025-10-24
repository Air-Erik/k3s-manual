# Пошаговая установка k3s Agent нод

> **Этап:** 1.2.4 - k3s Agent Installation
> **Дата:** 2025-10-24
> **Статус:** ⚙️ Установка и присоединение

---

## 📋 Обзор

На этом этапе устанавливаем **k3s в режиме agent** на подготовленные VM и присоединяем их к кластеру.

### Что будем делать:
1. **Подготовить credentials** (node-token)
2. **Установить k3s agent** на первой ноде (10.246.10.51)
3. **Установить k3s agent** на второй ноде (10.246.10.52)
4. **Проверить статус** agent service на обеих нодах

### Результат:
- 2 Agent ноды присоединены к кластеру
- `kubectl get nodes` показывает 3 ноды в Ready статусе
- Кластер готов к запуску workload

---

## 🎯 Предварительные требования

### Проверить готовность к установке:

```bash
# 1. Server нода работает
ping 10.246.10.50
curl -k -s https://10.246.10.50:6443/version | grep gitVersion

# 2. Agent ноды доступны
ssh k8s-admin@10.246.10.51 "hostname"  # → k3s-agent-01
ssh k8s-admin@10.246.10.52 "hostname"  # → k3s-agent-02

# 3. Node-token получен (из предыдущего этапа)
cat ~/k3s-credentials/node-token.txt
# Должен показать токен формата: K10xxx::server:xxxxx
```

### Если что-то не готово:

```bash
# Получить node-token заново:
ssh k8s-admin@10.246.10.50 "sudo cat /var/lib/rancher/k3s/server/node-token" > ~/k3s-credentials/node-token.txt

# Проверить доступность Agent нод:
ssh k8s-admin@10.246.10.51 "ping -c 2 10.246.10.50"
ssh k8s-admin@10.246.10.52 "ping -c 2 10.246.10.50"
```

---

## 🔑 Подготовка credentials

### Загрузить node-token в переменную:

```bash
# На локальной машине оператора
export K3S_NODE_TOKEN=$(cat ~/k3s-credentials/node-token.txt)

# Проверить что token загружен правильно
echo "Token length: ${#K3S_NODE_TOKEN} symbols"
# Ожидается: ~55 символов

echo "Token preview: ${K3S_NODE_TOKEN:0:20}..."
# Ожидается: K10xxxxx::server:xxx...

# Если token пустой или неправильный:
if [[ ${#K3S_NODE_TOKEN} -lt 50 ]]; then
    echo "❌ Token неправильный! Получите заново из Server ноды."
    exit 1
else
    echo "✅ Token готов к использованию"
fi
```

### Подготовить параметры для установки:

```bash
# Основные параметры k3s cluster
export K3S_SERVER_URL="https://10.246.10.50:6443"

# Проверить доступность Server API
curl -k -s --connect-timeout 5 ${K3S_SERVER_URL}/version >/dev/null
if [ $? -eq 0 ]; then
    echo "✅ Server API доступен: ${K3S_SERVER_URL}"
else
    echo "❌ Server API недоступен! Проверьте Server ноду."
    exit 1
fi
```

---

## 🚀 Установка k3s Agent Node 1 (k3s-agent-01)

### Шаг 1: Подключение к Agent Node 1

```bash
# SSH к первой Agent ноде
ssh k8s-admin@10.246.10.51

# Проверить готовность системы
hostname
# Ожидается: k3s-agent-01

ip addr show ens192 | grep "inet "
# Ожидается: inet 10.246.10.51/24

# Проверить доступность Server
ping -c 2 10.246.10.50
curl -k -s --connect-timeout 5 https://10.246.10.50:6443/version | head -3
```

### Шаг 2: Установка k3s agent

**Вариант A: Базовая установка (рекомендуется)**

```bash
# На Agent Node 1 (через SSH)
export K3S_NODE_TOKEN="K10abcd1234567890::server:1234567890abcdef1234567890abcdef"
export K3S_NODE_IP="10.246.10.51"
export K3S_NODE_NAME="k3s-agent-01"

# Установка k3s agent одной командой
curl -sfL https://get.k3s.io | \
  K3S_URL=https://10.246.10.50:6443 \
  K3S_TOKEN=${K3S_NODE_TOKEN} \
  sh -s - agent \
  --node-ip ${K3S_NODE_IP} \
  --node-name ${K3S_NODE_NAME}
```

**Что происходит при установке:**
```bash
1. Скачивание k3s binary (~50MB)
2. Создание systemd service k3s-agent
3. Запуск k3s-agent и подключение к Server
4. Регистрация ноды в кластере
5. Настройка kubelet, kube-proxy, containerd
```

**Вариант B: Установка с дополнительными параметрами**

```bash
# Если нужны специальные настройки
curl -sfL https://get.k3s.io | \
  K3S_URL=https://10.246.10.50:6443 \
  K3S_TOKEN=${K3S_NODE_TOKEN} \
  sh -s - agent \
  --node-ip ${K3S_NODE_IP} \
  --node-name ${K3S_NODE_NAME} \
  --kubelet-arg="max-pods=110" \
  --node-label="role=worker" \
  --node-label="zone=agent-01"
```

### Шаг 3: Ожидание завершения установки

```bash
# Процесс установки занимает ~2-3 минуты
echo "Ожидание завершения установки k3s agent..."

# Проверять статус каждые 10 секунд
for i in {1..18}; do
    sleep 10
    echo "Проверка $i/18..."

    if systemctl is-active --quiet k3s-agent; then
        echo "✅ k3s-agent service запущен!"
        break
    fi

    if [ $i -eq 18 ]; then
        echo "⚠️ Установка занимает больше времени, проверьте логи"
    fi
done
```

### Шаг 4: Проверка установки Agent Node 1

```bash
# Статус systemd service
sudo systemctl status k3s-agent --no-pager

# Ожидается:
# ● k3s-agent.service - Lightweight Kubernetes
#    Loaded: loaded
#    Active: active (running)

# Проверка процессов k3s
ps aux | grep k3s
# Должны видеть k3s agent процессы

# Логи за последние 2 минуты
sudo journalctl -u k3s-agent --since "2 minutes ago" --no-pager

# Ключевые сообщения в логах:
# "Successfully registered node k3s-agent-01"
# "kubelet started"
# "Node controller sync successful"
```

### Шаг 5: Выход из Agent Node 1

```bash
# Выход из SSH сессии
exit

# Вернулись на локальную машину оператора
echo "Agent Node 1 установка завершена!"
```

---

## 🚀 Установка k3s Agent Node 2 (k3s-agent-02)

### Процесс аналогичен Agent Node 1

**Отличия для Agent Node 2:**
```bash
IP: 10.246.10.52  (вместо .51)
Hostname: k3s-agent-02  (вместо k3s-agent-01)
```

### Быстрая установка Agent Node 2:

```bash
# SSH к второй Agent ноде
ssh k8s-admin@10.246.10.52

# Проверка готовности
hostname  # → k3s-agent-02
ping -c 2 10.246.10.50

# Установка k3s agent
export K3S_NODE_TOKEN="K10abcd1234567890::server:1234567890abcdef1234567890abcdef"
export K3S_NODE_IP="10.246.10.52"
export K3S_NODE_NAME="k3s-agent-02"

curl -sfL https://get.k3s.io | \
  K3S_URL=https://10.246.10.50:6443 \
  K3S_TOKEN=${K3S_NODE_TOKEN} \
  sh -s - agent \
  --node-ip ${K3S_NODE_IP} \
  --node-name ${K3S_NODE_NAME}

# Ожидание завершения (~2-3 минуты)
sleep 180

# Проверка статуса
sudo systemctl status k3s-agent --no-pager

# Выход
exit
```

---

## 📊 Проверка обеих Agent нод

### Статус service на обеих нодах:

```bash
# Проверить что k3s-agent активен на обеих нодах
ssh k8s-admin@10.246.10.51 "sudo systemctl is-active k3s-agent"
ssh k8s-admin@10.246.10.52 "sudo systemctl is-active k3s-agent"

# Ожидается вывод: active
# Если inactive - смотрите troubleshooting секцию
```

### Логи установки:

```bash
# Последние 20 строк логов с каждой ноды
echo "=== Agent Node 1 logs ==="
ssh k8s-admin@10.246.10.51 "sudo journalctl -u k3s-agent -n 20 --no-pager"

echo "=== Agent Node 2 logs ==="
ssh k8s-admin@10.246.10.52 "sudo journalctl -u k3s-agent -n 20 --no-pager"
```

### Проверка с Server ноды:

```bash
# SSH к Server ноде для проверки кластера
ssh k8s-admin@10.246.10.50

# Список всех нод (должно быть 3)
kubectl get nodes

# Ожидаемый вывод:
# NAME            STATUS   ROLES                  AGE   VERSION
# k3s-server-01   Ready    control-plane,master   45m   v1.30.x+k3s1
# k3s-agent-01    Ready    <none>                 8m    v1.30.x+k3s1
# k3s-agent-02    Ready    <none>                 5m    v1.30.x+k3s1

# Подробная информация о нодах
kubectl get nodes -o wide

# Должны видеть правильные IP адреса:
# k3s-server-01: 10.246.10.50
# k3s-agent-01:  10.246.10.51
# k3s-agent-02:  10.246.10.52

exit
```

---

## 🔧 Альтернатива: Использование готового скрипта

### Создание универсального скрипта установки

**Создать файл install-k3s-agent.sh на локальной машине:**

```bash
#!/bin/bash
# Универсальный скрипт установки k3s Agent
# Использование: ./install-k3s-agent.sh <agent-ip> <node-name> <token>

set -e -o pipefail

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Параметры
AGENT_IP=${1}
NODE_NAME=${2}
NODE_TOKEN=${3:-$(cat ~/k3s-credentials/node-token.txt)}
SERVER_URL="https://10.246.10.50:6443"

# Проверка параметров
if [ -z "$AGENT_IP" ] || [ -z "$NODE_NAME" ]; then
    echo -e "${RED}Использование: $0 <agent-ip> <node-name> [token]${NC}"
    echo "Пример: $0 10.246.10.51 k3s-agent-01"
    exit 1
fi

echo -e "${GREEN}=== Установка k3s Agent ===${NC}"
echo "Agent IP: $AGENT_IP"
echo "Node Name: $NODE_NAME"
echo "Server: $SERVER_URL"

# Установка через SSH
echo -e "${YELLOW}Подключение к Agent ноде...${NC}"
ssh k8s-admin@${AGENT_IP} "
    export K3S_NODE_TOKEN='${NODE_TOKEN}'
    export K3S_NODE_IP='${AGENT_IP}'
    export K3S_NODE_NAME='${NODE_NAME}'

    echo 'Установка k3s agent...'
    curl -sfL https://get.k3s.io | \
      K3S_URL=${SERVER_URL} \
      K3S_TOKEN=\${K3S_NODE_TOKEN} \
      sh -s - agent \
      --node-ip \${K3S_NODE_IP} \
      --node-name \${K3S_NODE_NAME}

    echo 'Ожидание запуска service...'
    sleep 30

    echo 'Проверка статуса:'
    sudo systemctl status k3s-agent --no-pager
"

echo -e "${GREEN}✅ Установка завершена!${NC}"
echo "Проверьте: ssh k8s-admin@10.246.10.50 'kubectl get nodes'"
```

### Использование скрипта:

```bash
# Сделать скрипт исполняемым
chmod +x install-k3s-agent.sh

# Установить Agent Node 1
./install-k3s-agent.sh 10.246.10.51 k3s-agent-01

# Установить Agent Node 2
./install-k3s-agent.sh 10.246.10.52 k3s-agent-02
```

---

## ⚡ Быстрая установка обеих нод

### Параллельная установка (если нужна скорость):

```bash
# Загрузить token
export K3S_NODE_TOKEN=$(cat ~/k3s-credentials/node-token.txt)

# Запустить установку на обеих нодах параллельно
(
  echo "Установка Agent Node 1..."
  ssh k8s-admin@10.246.10.51 "
    curl -sfL https://get.k3s.io | \
      K3S_URL=https://10.246.10.50:6443 \
      K3S_TOKEN='${K3S_NODE_TOKEN}' \
      sh -s - agent \
      --node-ip 10.246.10.51 \
      --node-name k3s-agent-01
  "
) &

(
  echo "Установка Agent Node 2..."
  ssh k8s-admin@10.246.10.52 "
    curl -sfL https://get.k3s.io | \
      K3S_URL=https://10.246.10.50:6443 \
      K3S_TOKEN='${K3S_NODE_TOKEN}' \
      sh -s - agent \
      --node-ip 10.246.10.52 \
      --node-name k3s-agent-02
  "
) &

# Ожидать завершения обеих установок
wait

echo "✅ Обе Agent ноды установлены!"

# Проверить результат
ssh k8s-admin@10.246.10.50 "kubectl get nodes"
```

---

## 🚨 Troubleshooting установки

### Проблема 1: k3s-agent service не запускается

**Симптомы:**
```bash
sudo systemctl status k3s-agent
# Active: failed (Result: exit-code)
```

**Диагностика:**
```bash
# Проверить логи
sudo journalctl -u k3s-agent -f

# Частые ошибки:
# "failed to contact server" → Проблема сети или неправильный SERVER_URL
# "authentication failed" → Неправильный node-token
# "node already exists" → Нода уже зарегистрирована
```

**Решения:**
```bash
# 1. Проверить сеть
ping 10.246.10.50
curl -k https://10.246.10.50:6443/version

# 2. Проверить token
echo $K3S_NODE_TOKEN
# Получить заново с Server ноды

# 3. Удалить существующую ноду (если нужно)
ssh k8s-admin@10.246.10.50 "kubectl delete node k3s-agent-01"

# 4. Переустановить agent
sudo /usr/local/bin/k3s-agent-uninstall.sh
# Установить заново
```

### Проблема 2: Agent нода в NotReady статусе

**Симптомы:**
```bash
kubectl get nodes
# k3s-agent-01   NotReady   <none>   3m
```

**Решения:**
```bash
# Проверить kubelet на Agent ноде
ssh k8s-admin@10.246.10.51 "sudo journalctl -u k3s-agent -n 50"

# Частые причины:
# - CNI (Flannel) проблемы → перезапустить agent
# - Недостаточно ресурсов → проверить RAM/CPU
# - Сетевые проблемы → проверить MTU

# Перезапуск agent
ssh k8s-admin@10.246.10.51 "sudo systemctl restart k3s-agent"

# Ожидать 30-60 секунд
sleep 60
kubectl get nodes
```

### Проблема 3: Установка зависает

**Симптомы:**
- curl команда не завершается >5 минут
- Нет сетевого трафика

**Решения:**
```bash
# 1. Прервать установку (Ctrl+C)
# 2. Проверить интернет на Agent ноде
ssh k8s-admin@10.246.10.51 "ping -c 3 get.k3s.io"

# 3. Ручная установка
wget https://github.com/k3s-io/k3s/releases/latest/download/k3s
sudo mv k3s /usr/local/bin/
sudo chmod +x /usr/local/bin/k3s

# 4. Запуск вручную
sudo /usr/local/bin/k3s agent \
  --server https://10.246.10.50:6443 \
  --token ${K3S_NODE_TOKEN}
```

---

## ✅ Критерии успешной установки

После установки обеих Agent нод должно быть:

### На Agent нодах:
- [ ] **k3s-agent service** активен: `systemctl is-active k3s-agent` = active
- [ ] **Процессы k3s** запущены: `ps aux | grep k3s`
- [ ] **Логи без ошибок**: последние 20 строк в `journalctl -u k3s-agent`

### В кластере:
- [ ] **3 ноды в Ready**: `kubectl get nodes` показывает все Ready
- [ ] **Правильные IP адреса**: `kubectl get nodes -o wide`
- [ ] **Одинаковая версия k3s**: VERSION колонка одинакова

### Системные pods:
- [ ] **Flannel pods**: запущены на всех нодах
- [ ] **Kube-proxy pods**: запущены на всех нодах
- [ ] **Все system pods Running**: `kubectl get pods -A`

---

## 📊 Время установки

| Этап | Agent Node 1 | Agent Node 2 | Итого |
|------|--------------|--------------|-------|
| SSH подключение | 30 сек | 30 сек | 1 мин |
| Скачивание k3s | 2 мин | 2 мин | 4 мин |
| Установка и запуск | 2 мин | 2 мин | 4 мин |
| Проверка и валидация | 1 мин | 1 мин | 2 мин |
| **ИТОГО** | **5.5 мин** | **5.5 мин** | **~11 мин** |

**Параллельная установка:** ~6 минут (если запускать одновременно)

---

## ➡️ Следующий шаг

**✅ k3s Agent ноды установлены и присоединены!**

**Имеем:**
- **3-node кластер** готов к работе
- **k3s-server-01**: control plane + workloads
- **k3s-agent-01**: только workloads
- **k3s-agent-02**: только workloads

**Далее:** [05-validate-cluster.md](./05-validate-cluster.md) — полная валидация кластера и тестирование

---

**k3s кластер из 3 нод готов! Время тестировать! 🎉**
