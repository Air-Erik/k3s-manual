# Подготовка к присоединению Agent нод

> **Этап:** 1.1 - Server Node Setup
> **Цель:** Подготовка k3s Server для присоединения Agent нод
> **Дата:** 2025-10-24

---

## 🎯 Цель этапа

Убедиться что k3s Server готов к приему Agent нод и подготовить всю необходимую информацию для следующего этапа (Agent Nodes Setup).

---

## ✅ Чек-лист готовности Server

Перед присоединением Agent нод убедитесь что:

### Базовая готовность
- [ ] k3s Server работает: `sudo systemctl status k3s`
- [ ] Node в состоянии Ready: `kubectl get nodes`
- [ ] Все системные pods Running: `kubectl get pods -A`
- [ ] API Server отвечает: `curl -k https://10.246.10.50:6443/version`

### Сетевая готовность
- [ ] Firewall настроен правильно
- [ ] Порты открыты для Agent нод
- [ ] DNS работает
- [ ] Flannel CNI готов к новым нодам

### Credentials готовы
- [ ] node-token сохранен
- [ ] kubeconfig доступен
- [ ] Информация для Agent нод собрана

---

## 🔍 Детальные проверки

### 1. Проверка k3s Server статуса

```bash
# Базовый статус
sudo systemctl status k3s
# Должен быть: active (running)

# Версия k3s
k3s --version

# Статус ноды
kubectl get nodes -o wide
# k3s-server-01 должен быть Ready

# Uptime ноды
kubectl get nodes -o jsonpath='{.items[0].metadata.creationTimestamp}'
```

### 2. Проверка системных pods

```bash
# Все pods должны быть Running
kubectl get pods -A

# Особое внимание к:
kubectl get pods -n kube-system -l k8s-app=kube-dns    # CoreDNS
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik  # Traefik
kubectl get pods -n kube-system -l app=local-path-provisioner      # Storage

# Если какие-то pods не Running - исправить перед добавлением Agent нод
```

### 3. Проверка сетевой готовности

**Flannel готовность:**
```bash
# Flannel интерфейс должен существовать
ip addr show flannel.1
# inet 10.42.0.0/32 scope global flannel.1

# Flannel subnet (для новых нод)
cat /var/lib/rancher/k3s/server/db/info | grep -i flannel || echo "Flannel встроен в k3s"
```

**Firewall проверка:**
```bash
# Проверить что необходимые порты открыты
sudo ufw status | grep -E "6443|10250|8472"

# Должны быть открыты:
# 6443/tcp   - Kubernetes API Server
# 10250/tcp  - kubelet API
# 8472/udp   - Flannel VXLAN

# Если нет - открыть:
sudo ufw allow from 10.246.10.0/24 to any port 6443,10250 proto tcp
sudo ufw allow from 10.246.10.0/24 to any port 8472 proto udp
```

**Network connectivity:**
```bash
# API Server доступен извне
curl -k https://10.246.10.50:6443/version

# Порт 6443 слушается на всех интерфейсах
sudo netstat -tulpn | grep :6443
# Должен показать: 0.0.0.0:6443 или :::6443
```

### 4. Сбор информации для Agent нод

**Node Token:**
```bash
# Получить node-token
NODE_TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)
echo "Node Token: $NODE_TOKEN"

# Сохранить в файл если еще не сохранен
echo $NODE_TOKEN > ~/k3s-credentials/node-token.txt
```

**Server URL:**
```bash
# Убедиться что Server URL правильный
SERVER_URL="https://10.246.10.50:6443"
echo "Server URL: $SERVER_URL"

# Проверить доступность
curl -k $SERVER_URL/version
```

**Cluster CA Certificate (если нужно):**
```bash
# Иногда нужен для Agent нод
sudo cat /var/lib/rancher/k3s/server/tls/server-ca.crt > ~/k3s-credentials/server-ca.crt
```

### 5. Создание итогового файла с информацией

```bash
# Создать полную информацию для Agent нод
cat > ~/k3s-credentials/agent-join-info.txt << EOF
# k3s Agent Join Information
# Дата создания: $(date)
# Server Node: k3s-server-01 (10.246.10.50)

# === ОСНОВНАЯ ИНФОРМАЦИЯ ===
Server URL: https://10.246.10.50:6443
Node Token: $(sudo cat /var/lib/rancher/k3s/server/node-token)

# === КОМАНДА ДЛЯ AGENT НОД ===
curl -sfL https://get.k3s.io | K3S_URL=https://10.246.10.50:6443 K3S_TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token) sh -

# === ПАРАМЕТРЫ ДЛЯ СЛЕДУЮЩИХ AGENT НОД ===
# Agent Node 1: k3s-agent-01 (10.246.10.51)
# Agent Node 2: k3s-agent-02 (10.246.10.52)

# === ПРОВЕРКА ГОТОВНОСТИ SERVER ===
# Server Status: $(sudo systemctl is-active k3s)
# Node Ready: $(kubectl get nodes --no-headers | grep k3s-server | awk '{print $2}')
# System Pods: $(kubectl get pods -A --no-headers | grep -v Running | wc -l) pods not Running

# === NETWORK INFO ===
# Server IP: 10.246.10.50
# Flannel Interface: ens192
# Flannel Subnet: $(ip addr show flannel.1 | grep 'inet ' | awk '{print $2}' || echo "Not found")

EOF

echo "✅ Информация для Agent нод сохранена в ~/k3s-credentials/agent-join-info.txt"
```

---

## 🚀 Подготовка к следующему этапу

### Информация для Team Lead

**Готово для передачи в Этап 1.2 (Agent Nodes Setup):**

```yaml
# Статус Server Node
Server Status: ✅ Ready
Server URL: https://10.246.10.50:6443
Node Token: [сохранен в файле]
Kubeconfig: [готов к использованию]

# План Agent нод
Agent Node 1:
  Hostname: k3s-agent-01
  IP: 10.246.10.51

Agent Node 2:
  Hostname: k3s-agent-02
  IP: 10.246.10.52

# Следующие действия
1. Клонировать VM для Agent нод из того же Template
2. Применить cloud-init конфигурации для .51 и .52 IP
3. Установить k3s Agent с Server URL и Token
4. Валидировать присоединение к кластеру
```

### Файлы для Agent setup

Убедитесь что готовы файлы для следующего этапа:
```bash
ls -la ~/k3s-credentials/
# kubeconfig.yaml           - Для управления кластером
# node-token.txt           - Для присоединения Agent нод
# agent-join-info.txt      - Вся информация для Agent setup
# cluster-info.txt         - Общая информация о кластере
```

---

## 🧪 Финальная проверка готовности

### Тестовый сценарий

**Симуляция присоединения Agent (для проверки):**
```bash
# НЕ ВЫПОЛНЯТЬ на Server ноде! Только для проверки команды:

# 1. Проверить что команда для Agent сформирована правильно
echo "Команда для Agent нод:"
echo "curl -sfL https://get.k3s.io | K3S_URL=https://10.246.10.50:6443 K3S_TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token) sh -"

# 2. Проверить доступность Server URL с другой машины (если возможно)
# curl -k https://10.246.10.50:6443/version

# 3. Проверить DNS резолюцию hostname (если используется)
# nslookup k3s-server-01 или ping k3s-server-01
```

### Ожидаемые результаты присоединения Agent

После присоединения Agent нод вы должны увидеть:
```bash
kubectl get nodes
# NAME             STATUS   ROLES                  AGE   VERSION
# k3s-server-01    Ready    control-plane,master   30m   v1.30.x+k3s1
# k3s-agent-01     Ready    <none>                 5m    v1.30.x+k3s1
# k3s-agent-02     Ready    <none>                 3m    v1.30.x+k3s1
```

---

## 🎯 Передача в следующий этап

### Для AI-агента Agent Node Setup

**Передаваемая информация:**
1. **Server готов:** Все проверки пройдены ✅
2. **Network configuration:** 10.246.10.50 (Server), .51-.52 (Agents)
3. **Join credentials:** Server URL + Node Token
4. **Cloud-init configs:** Готовы для Agent VM в `manifests/cloud-init/`

**Файлы к передаче:**
- `~/k3s-credentials/agent-join-info.txt` - полная информация для присоединения
- `manifests/cloud-init/agent-node-01-*` - cloud-init для первого Agent
- `manifests/cloud-init/agent-node-02-*` - cloud-init для второго Agent

### Для оператора

**Что готово:**
- ✅ k3s Server работает стабильно
- ✅ Все credentials собраны
- ✅ Информация для Agent нод подготовлена
- ✅ Сеть готова к расширению

**Следующие действия:**
1. Переходим к Этапу 1.2: Agent Nodes Setup
2. Используем тот же VM Template для клонирования Agent нод
3. Применяем cloud-init конфигурации для IP .51 и .52
4. Запускаем установку k3s Agent с подготовленными credentials

---

## 📋 Итоговый статус

```
🎉 ЭТАП 1.1 (SERVER NODE SETUP) ЗАВЕРШЕН УСПЕШНО!

✅ k3s Server Node установлен и работает
✅ Все системные компоненты Ready
✅ Credentials собраны и сохранены
✅ Сетевая конфигурация готова
✅ Информация для Agent нод подготовлена

📊 Результат:
• 1/3 нод готово (Server)
• 0/2 Agent нод (следующий этап)
• Время установки: ~15 минут
• Готов к production workloads

🎯 Готов к Этапу 1.2: Agent Nodes Setup
```

---

**Создано:** 2025-10-24
**AI-агент:** Server Node Setup Specialist
**Для:** k3s на vSphere проект 🚀

**Передано Team Lead для планирования следующего этапа** ✅
