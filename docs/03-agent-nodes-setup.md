# k3s Agent Nodes Setup

> **Статус:** ⏳ TODO
> **Ответственный:** AI-исполнитель + Оператор
> **Зависимости:** ✅ Server node установлена

---

## 🎯 Цель

Присоединить Agent ноды к k3s кластеру. Agent ноды — это worker ноды, которые запускают workload pods.

---

## 📋 Процесс

### 1. Клонирование VM для Agent нод

**Agent 1:**
- **Из Template:** `k3s-ubuntu2404-minimal-template`
- **IP:** `10.246.10.51`
- **Hostname:** `k3s-agent-01`
- **RAM:** 2 ГБ
- **vCPU:** 2

**Agent 2:**
- **Из Template:** `k3s-ubuntu2404-minimal-template`
- **IP:** `10.246.10.52`
- **Hostname:** `k3s-agent-02`
- **RAM:** 2 ГБ
- **vCPU:** 2

### 2. Установка k3s в режиме Agent

**На каждой Agent ноде:**
```bash
curl -sfL https://get.k3s.io | K3S_URL=https://10.246.10.50:6443 \
  K3S_TOKEN=[node-token] sh -s - agent \
  --node-ip [agent-ip]
```

**Параметры:**
- `K3S_URL` — URL Server ноды
- `K3S_TOKEN` — node-token с Server ноды
- `--node-ip` — IP конкретной Agent ноды

**Время установки:** ~2-3 минуты на ноду

### 3. Валидация

**С Server ноды:**
```bash
sudo k3s kubectl get nodes

# Должно показать:
# k3s-server-01   Ready    control-plane,master   10m   v1.30.x
# k3s-agent-01    Ready    <none>                 5m    v1.30.x
# k3s-agent-02    Ready    <none>                 5m    v1.30.x
```

**На Agent ноде:**
```bash
sudo systemctl status k3s-agent

# Логи
journalctl -u k3s-agent -f
```

---

## 👉 Детальное задание для AI-агента

**AI-агент создаст:** `research/agent-nodes-setup/AI-AGENT-TASK.md`

**Артефакты от AI-агента:**
1. Инструкции клонирования VM для Agent
2. Скрипт `scripts/install-k3s-agent.sh`
3. Процедуры присоединения к кластеру
4. Валидационные команды
5. Troubleshooting guide

---

## ✅ Критерии завершения

- [ ] 2 VM клонированы для Agent (10.246.10.51-52)
- [ ] k3s-agent установлен на обеих нодах
- [ ] k3s-agent service запущен и работает
- [ ] kubectl get nodes показывает 3 Ready ноды
- [ ] Можно создать тестовый deployment
- [ ] Pods распределяются по всем нодам

---

## 🧪 Тест

**Создать тестовый deployment:**
```bash
kubectl create deployment nginx --image=nginx --replicas=3
kubectl get pods -o wide

# Pods должны быть на разных нодах (если есть ресурсы)
```

---

**Следующий шаг:** [04-storage-setup.md](./04-storage-setup.md)
