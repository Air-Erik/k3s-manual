# k3s Server Node Setup

> **Статус:** ⏳ TODO
> **Ответственный:** AI-исполнитель + Оператор
> **Зависимости:** ✅ VM Template готов

---

## 🎯 Цель

Установить k3s в режиме **server** на первой ноде. Server нода включает Control Plane + etcd + возможность запускать workloads.

---

## 📋 Процесс

### 1. Клонирование VM
- **Из Template:** `k3s-ubuntu2404-minimal-template`
- **IP:** `10.246.10.50`
- **Hostname:** `k3s-server-01`
- **RAM:** 4 ГБ
- **vCPU:** 2

### 2. Установка k3s

**Базовая установка:**
```bash
curl -sfL https://get.k3s.io | sh -
```

**С параметрами:**
```bash
curl -sfL https://get.k3s.io | sh -s - server \
  --write-kubeconfig-mode 644 \
  --node-ip 10.246.10.50 \
  --flannel-iface ens192
```

**Время установки:** ~2-5 минут

### 3. Получение credentials

**kubeconfig:**
```bash
sudo cat /etc/rancher/k3s/k3s.yaml
```

**node-token (для Agent join):**
```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

### 4. Валидация

```bash
# Проверить service
sudo systemctl status k3s

# Проверить nodes
sudo k3s kubectl get nodes

# Проверить pods
sudo k3s kubectl get pods -A
```

**Ожидаемый результат:**
- k3s service запущен
- 1 нода в состоянии Ready
- Системные поды работают (traefik, coredns, etc.)

---

## 👉 Детальное задание для AI-агента

**AI-агент создаст:** `research/server-node-setup/AI-AGENT-TASK.md`

**Артефакты от AI-агента:**
1. Инструкции клонирования VM
2. Скрипт `scripts/install-k3s-server.sh`
3. Процедуры получения credentials
4. Валидационные команды
5. Troubleshooting guide

---

## ✅ Критерии завершения

- [ ] VM клонирована для Server (10.246.10.50)
- [ ] k3s установлен на Server ноде
- [ ] k3s service запущен и работает
- [ ] kubeconfig получен
- [ ] node-token сохранён
- [ ] API Server доступен (curl https://10.246.10.50:6443/version)
- [ ] kubectl get nodes показывает 1 Ready node
- [ ] Системные поды работают

---

**Следующий шаг:** [03-agent-nodes-setup.md](./03-agent-nodes-setup.md)
