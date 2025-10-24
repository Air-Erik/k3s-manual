# 🚀 Быстрый старт: Установка k3s Agent Node

> **Ситуация:** У тебя есть VM k3s-agent-01, SSH подключение активно, K3S_NODE_TOKEN получен
> **Цель:** Присоединить Agent ноду к кластеру за 5 минут
> **Дата:** 2025-10-24

---

## ✅ **Что у тебя уже есть:**
- ✅ VM k3s-agent-01 создана и запущена
- ✅ SSH подключение: `ssh k8s-admin@10.246.10.51` работает
- ✅ K3S_NODE_TOKEN получен с Server ноды
- ✅ k3s Server работает на 10.246.10.50

---

## 🎯 **План действий (5 минут):**

```
1. Проверить готовность VM                [1 мин]
2. Установить переменные окружения        [1 мин]
3. Запустить скрипт установки k3s        [3 мин]
4. Проверить результат с Server ноды      [1 мин]
```

---

## 🔧 **ШАГ 1: Проверка готовности VM**

**На k3s-agent-01 (где ты сейчас по SSH):**

```bash
# Проверить что ты на правильной VM
hostname
# Должно быть: k3s-agent-01

# Проверить IP адрес
ip addr show ens192 | grep "inet "
# Должно быть: inet 10.246.10.51/24

# Проверить доступность Server ноды
ping -c 3 10.246.10.50
# Должен пинговаться

# Проверить API Server
curl -k -s --connect-timeout 5 https://10.246.10.50:6443/version | head -3
# Должен показать JSON с версией k3s
```

**✅ Если все ОК — переходи к Шагу 2**
**❌ Если проблемы — проверь сеть или VM настройки**

---

## 🔑 **ШАГ 2: Установка переменных окружения**

**На k3s-agent-01, задай переменные:**

```bash
# 1. Установить node-token (ЗАМЕНИ на свой токен!)
export K3S_NODE_TOKEN="K10abcd1234567890::server:1234567890abcdef1234567890abcdef"

# 2. Проверить что token правильный
echo "Token length: ${#K3S_NODE_TOKEN}"
# Должно быть около 55 символов

echo "Token format: ${K3S_NODE_TOKEN:0:25}..."
# Должно начинаться с K10xxx::server:

# 3. Установить параметры ноды (обычно автоопределяются, но лучше явно)
export K3S_SERVER_URL="https://10.246.10.50:6443"
export K3S_NODE_IP="10.246.10.51"
export K3S_NODE_NAME="k3s-agent-01"

# 4. Проверить все переменные
echo "Server URL: $K3S_SERVER_URL"
echo "Node IP: $K3S_NODE_IP"
echo "Node Name: $K3S_NODE_NAME"
echo "Token: ${K3S_NODE_TOKEN:0:20}...${K3S_NODE_TOKEN: -10}"
```

**🔴 ВАЖНО:** Замени `K3S_NODE_TOKEN` на реальный токен который ты получил!

---

## ⚙️ **ШАГ 3: Запуск установки k3s**

### **Вариант А: Быстрая установка (рекомендуется)**

```bash
# Одна команда для установки k3s agent
curl -sfL https://get.k3s.io | \
  K3S_URL=$K3S_SERVER_URL \
  K3S_TOKEN=$K3S_NODE_TOKEN \
  sh -s - agent \
  --node-ip $K3S_NODE_IP \
  --node-name $K3S_NODE_NAME
```

### **Вариант Б: Использование готового скрипта**

```bash
# Если у тебя есть скрипт install-k3s-agent.sh
# (передать его через scp или скачать)

# Скачать скрипт (если нужно)
curl -o install-k3s-agent.sh https://raw.githubusercontent.com/твой-repo/k3s-manual/main/scripts/install-k3s-agent.sh
chmod +x install-k3s-agent.sh

# Запустить скрипт
./install-k3s-agent.sh
```

### **Что происходит во время установки:**

```
[1/5] Скачивание k3s binary (~50MB)        [1-2 мин]
[2/5] Создание systemd service              [30 сек]
[3/5] Подключение к API Server              [30 сек]
[4/5] Запуск kubelet и containerd           [1 мин]
[5/5] Регистрация в кластере                [30 сек]
```

**⏳ Общее время: ~3-5 минут**

---

## 🔍 **ШАГ 4: Проверка установки**

### **На k3s-agent-01 (где ты сейчас):**

```bash
# Проверить статус k3s-agent service
sudo systemctl status k3s-agent --no-pager

# Должно быть:
# Active: active (running)

# Проверить логи (последние 10 строк)
sudo journalctl -u k3s-agent -n 10 --no-pager

# Искать сообщения:
# "Successfully registered node k3s-agent-01"
# "kubelet started"
```

### **На Server ноде (открой новый терминал):**

```bash
# SSH к Server ноде
ssh k8s-admin@10.246.10.50

# Проверить что Agent нода появилась в кластере
kubectl get nodes

# Ожидаемый результат:
# NAME            STATUS   ROLES                  AGE   VERSION
# k3s-server-01   Ready    control-plane,master   45m   v1.30.x+k3s1
# k3s-agent-01    Ready    <none>                 2m    v1.30.x+k3s1  ← НОВАЯ НОДА!

# Подробная информация
kubectl get nodes -o wide

# Проверить что IP правильный (.51)
```

---

## 🎉 **Если все работает:**

### **Ты увидишь:**
- ✅ `systemctl status k3s-agent` = **active (running)**
- ✅ `kubectl get nodes` показывает **k3s-agent-01 Ready**
- ✅ IP адрес = **10.246.10.51**
- ✅ Версия k3s совпадает с Server

### **Поздравляю! k3s Agent успешно присоединен! 🎊**

---

## 🚨 **Если что-то не работает:**

### **Проблема 1: k3s-agent service failed**

```bash
# Смотрим логи
sudo journalctl -u k3s-agent -n 50

# Частые ошибки:
# "failed to contact server" → проверь сеть к 10.246.10.50:6443
# "authentication failed" → неправильный K3S_NODE_TOKEN
# "connection refused" → Server нода не работает
```

### **Проблема 2: Нода не появляется в kubectl get nodes**

```bash
# На Agent ноде проверить подключение
curl -k https://10.246.10.50:6443/version

# На Server ноде проверить что Server работает
sudo systemctl status k3s
kubectl cluster-info
```

### **Проблема 3: Нода в NotReady статусе**

```bash
# Подождать 1-2 минуты - это нормально
sleep 120
kubectl get nodes

# Если все еще NotReady:
kubectl describe node k3s-agent-01
```

### **Экстренное решение: переустановка**

```bash
# На Agent ноде удалить и переустановить
sudo /usr/local/bin/k3s-agent-uninstall.sh 2>/dev/null || true

# Установить заново (повторить Шаг 3)
curl -sfL https://get.k3s.io | K3S_URL=$K3S_SERVER_URL K3S_TOKEN=$K3S_NODE_TOKEN sh -s - agent --node-ip $K3S_NODE_IP --node-name $K3S_NODE_NAME
```

---

## 🔄 **Установка второй Agent ноды (k3s-agent-02)**

**После успешной установки первой Agent ноды, повтори процесс для второй:**

```bash
# SSH к второй ноде
ssh k8s-admin@10.246.10.52

# Установить переменные (ИЗМЕНИ IP и NAME!)
export K3S_NODE_TOKEN="твой_токен"  # ТОТ ЖЕ ТОКЕН!
export K3S_SERVER_URL="https://10.246.10.50:6443"
export K3S_NODE_IP="10.246.10.52"    # ← ДРУГОЙ IP!
export K3S_NODE_NAME="k3s-agent-02"  # ← ДРУГОЕ ИМЯ!

# Установить k3s agent
curl -sfL https://get.k3s.io | \
  K3S_URL=$K3S_SERVER_URL \
  K3S_TOKEN=$K3S_NODE_TOKEN \
  sh -s - agent \
  --node-ip $K3S_NODE_IP \
  --node-name $K3S_NODE_NAME

# Проверить результат
sudo systemctl status k3s-agent
```

**Финальная проверка 3-node кластера:**
```bash
ssh k8s-admin@10.246.10.50 "kubectl get nodes"

# Должно быть 3 ноды:
# k3s-server-01   Ready    control-plane,master
# k3s-agent-01    Ready    <none>
# k3s-agent-02    Ready    <none>
```

---

## 📱 **Полная валидация кластера**

**После установки всех Agent нод запусти автоматическую валидацию:**

```bash
# На Server ноде
ssh k8s-admin@10.246.10.50

# Скачать и запустить скрипт валидации
curl -o validate-k3s-cluster.sh https://raw.githubusercontent.com/твой-repo/k3s-manual/main/scripts/validate-k3s-cluster.sh
chmod +x validate-k3s-cluster.sh
./validate-k3s-cluster.sh

# Или ручная проверка
kubectl get nodes -o wide
kubectl get pods -A
kubectl create deployment test --image=nginx --replicas=3
kubectl get pods -o wide
kubectl delete deployment test
```

---

## 🎯 **Чек-лист готовности:**

- [ ] k3s-agent-01 в статусе Ready
- [ ] k3s-agent-01 имеет IP 10.246.10.51
- [ ] k3s-agent-02 в статусе Ready (если делаешь)
- [ ] k3s-agent-02 имеет IP 10.246.10.52 (если делаешь)
- [ ] Все ноды имеют одинаковую версию k3s
- [ ] Системные pods Running во всех namespaces
- [ ] Test deployment успешно создается на Agent нодах

---

## 🎊 **Готово! У тебя теперь рабочий k3s кластер!**

**Следующие шаги:**
1. ✅ **Agent ноды присоединены** — этот этап завершен!
2. 🔄 **Этап 2:** vSphere CSI Driver для persistent storage
3. 🔄 **Этап 3:** Развертывание первых приложений

**k3s гораздо проще чем "полный" Kubernetes! 🚀**

---

**Удачи! Пиши если нужна помощь! 💪**
