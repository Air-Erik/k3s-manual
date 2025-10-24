# Требования к VM Template для k3s

> **Этап:** 0 - VM Template Preparation
> **Статус:** ✅ ГОТОВО
> **Дата:** 2025-10-24
> **Цель:** Минимальная VM Template для развёртывания k3s кластера

---

## 🎯 Обзор

Этот документ определяет **точные требования** к VM Template для k3s кластера на VMware vSphere.

### ⚠️ КРИТИЧЕСКИ ВАЖНО: k3s vs Kubernetes

**k3s — это НЕ обычный Kubernetes!**

❌ **НЕ устанавливать:**
- kubeadm, kubelet, kubectl
- containerd (k3s содержит встроенный!)
- Docker (не нужен)
- CNI плагины (Flannel встроен)
- Ingress контроллеры (Traefik встроен)
- LoadBalancer (ServiceLB встроен)

✅ **Устанавливать:**
- Ubuntu 24.04 LTS (minimal)
- Базовые утилиты (curl, wget, vim, net-tools)
- cloud-init для автоконфигурации
- open-vm-tools для vSphere интеграции

**Почему:** k3s — единый бинарник (~50 МБ), который содержит все необходимые компоненты и устанавливается одной командой!

---

## 🖥️ Требования к VM

### Базовые характеристики

| Параметр | Значение | Обоснование |
|----------|----------|-------------|
| **OS** | Ubuntu 24.04 LTS Server (minimal) | Стабильная LTS версия, минимальная установка |
| **vCPU** | 2 | Достаточно для k3s Server + workloads |
| **RAM** | 4 GB | Минимум для k3s Server (рекомендуется 2+ GB) |
| **Disk** | 40 GB (thin provisioned) | Место для OS + k3s + workloads |
| **Network** | 1 NIC | Подключение к NSX-T segment |

### Архитектура

| Параметр | Значение | Примечания |
|----------|----------|------------|
| **Firmware** | UEFI | Современная загрузка |
| **Secure Boot** | Disabled | Для совместимости с k3s |
| **Virtualization** | Hardware assisted | VT-x/AMD-V включены |
| **Memory Hot Add** | Enabled | Для масштабирования |
| **CPU Hot Add** | Enabled | Для масштабирования |

---

## 📦 Требуемые пакеты

### Обязательные пакеты

```bash
# Системные утилиты
curl                    # Для загрузки k3s
wget                    # Альтернатива curl
vim                     # Редактор
net-tools               # ifconfig, netstat
iputils-ping            # ping
dnsutils                # nslookup, dig
htop                    # Мониторинг процессов
tree                    # Просмотр структуры каталогов

# Cloud-init
cloud-init              # Автоконфигурация
cloud-initramfs-growroot # Расширение диска

# VMware интеграция
open-vm-tools           # VMware Tools
open-vm-tools-desktop   # GUI компоненты (опционально)

# Сетевые утилиты
iproute2                # ip команды
bridge-utils            # bridge команды
```

### Пакеты которые НЕ устанавливать

```bash
# Kubernetes компоненты (НЕ НУЖНЫ!)
kubeadm                 # k3s не использует
kubelet                 # k3s содержит встроенный
kubectl                 # k3s содержит встроенный
kubernetes-cni          # k3s содержит встроенный CNI

# Container runtime (НЕ НУЖНЫ!)
containerd              # k3s содержит встроенный
docker.io               # k3s не использует Docker
docker-ce               # k3s не использует Docker
cri-o                   # k3s не использует

# CNI плагины (НЕ НУЖНЫ!)
flannel                 # k3s содержит встроенный Flannel
calico                  # k3s использует Flannel по умолчанию
cilium                  # k3s использует Flannel по умолчанию

# Ingress контроллеры (НЕ НУЖНЫ!)
nginx-ingress           # k3s содержит встроенный Traefik
traefik                 # k3s содержит встроенный Traefik

# LoadBalancer (НЕ НУЖНЫ!)
metallb                 # k3s содержит встроенный ServiceLB
kube-vip                # k3s содержит встроенный ServiceLB
```

---

## ⚙️ Системные настройки

### Настройки ядра (НЕ нужны для k3s!)

**В отличие от "полного" Kubernetes, k3s НЕ требует:**

```bash
# НЕ настраивать эти параметры!
# net.bridge.bridge-nf-call-iptables = 1
# net.ipv4.ip_forward = 1
# net.ipv4.conf.all.forwarding = 1
# vm.swappiness = 0
# kernel.panic = 10
# kernel.panic_on_oops = 1
```

**Почему:** k3s автоматически настраивает все необходимые параметры ядра при установке!

### Настройки сети

```bash
# Настройка cloud-init для VMware vSphere
sudo tee /etc/cloud/cloud.cfg.d/98-datasource.cfg >/dev/null <<'YAML'
datasource_list: [ VMware, OVF, NoCloud, None ]
YAML

# Включение cloud-init сервисов
sudo systemctl unmask cloud-init cloud-init-local cloud-config cloud-final
sudo systemctl enable cloud-init cloud-init-local cloud-config cloud-final

# Удаление кастомных netplan-файлов для генерации 50-cloud-init.yaml
sudo rm -f /etc/netplan/*.yaml

# Очистка состояния cloud-init для Template
sudo cloud-init clean --logs --machine
sudo rm -rf /var/lib/cloud
```

### Настройки безопасности

```bash
# SSH доступ
Port 22
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes

# Firewall (базовый)
ufw allow ssh
ufw allow 6443/tcp    # k3s API Server
ufw allow 10250/tcp   # kubelet
ufw allow 8472/udp    # Flannel VXLAN
```

---

## 🔧 Cloud-init конфигурация

### Базовые требования

```yaml
# Обязательные секции cloud-init
hostname: [уникальное имя ноды]
fqdn: [hostname]

# Пользователь
users:
  - name: k8s-admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: [хэшированный пароль]

# Статический IP
write_files:
  - path: /etc/netplan/01-static-ip.yaml
    content: |
      network:
        version: 2
        ethernets:
          ens192:
            addresses: [IP/24]
            routes:
              - to: default
                via: 10.246.10.1
            nameservers:
              addresses: [172.17.10.3, 8.8.8.8]

# Команды после boot
runcmd:
  - netplan apply
  - systemctl restart systemd-networkd
```

---

## 🌐 Сетевые требования

### NSX-T Segment

| Параметр | Значение |
|----------|----------|
| **Segment** | k8s-zeon-dev-segment |
| **CIDR** | 10.246.10.0/24 |
| **Gateway** | 10.246.10.1 |
| **DNS** | 172.17.10.3, 8.8.8.8 |

### IP Allocation для k3s

| Нода | IP | Hostname | Назначение |
|------|----|---------|-----------|
| Server | 10.246.10.50 | k3s-server-01 | API Server + etcd + workloads |
| Agent 1 | 10.246.10.51 | k3s-agent-01 | Worker node |
| Agent 2 | 10.246.10.52 | k3s-agent-02 | Worker node |

### Порты k3s

| Порт | Протокол | Назначение |
|------|----------|------------|
| 6443 | TCP | k3s API Server |
| 10250 | TCP | kubelet |
| 8472 | UDP | Flannel VXLAN |
| 2379-2380 | TCP | etcd (если используется) |

---

## 🔐 Безопасность

### SSH конфигурация

```bash
# Пользователь
User: k8s-admin
Password: admin (для первоначальной настройки)
SSH Key: Опционально (можно добавить позже)

# SSH настройки
Port 22
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
```

### Firewall (минимальный)

```bash
# Разрешить только необходимые порты
ufw allow ssh
ufw allow 6443/tcp    # k3s API
ufw allow 10250/tcp   # kubelet
ufw allow 8472/udp    # Flannel
ufw --force enable
```

---

## 📊 Ресурсы по нодам

### Server Node (k3s-server-01)

| Ресурс | Минимум | Рекомендуется | Обоснование |
|--------|---------|---------------|-------------|
| vCPU | 2 | 4 | API Server + etcd + scheduler |
| RAM | 2 GB | 4 GB | etcd + API Server + workloads |
| Disk | 20 GB | 40 GB | OS + etcd + logs |

### Agent Nodes (k3s-agent-01, k3s-agent-02)

| Ресурс | Минимум | Рекомендуется | Обоснование |
|--------|---------|---------------|-------------|
| vCPU | 2 | 4 | Workloads + kubelet |
| RAM | 1 GB | 2 GB | Workloads + kubelet |
| Disk | 20 GB | 40 GB | OS + workloads + logs |

---

## ✅ Критерии готовности Template

Template считается готовым когда:

1. **OS установлена:** Ubuntu 24.04 LTS (minimal)
2. **Пакеты установлены:** Все обязательные пакеты
3. **Cloud-init настроен:** Готов к автоконфигурации
4. **VMware Tools:** open-vm-tools установлен
5. **Система очищена:** Логи, history, SSH keys, machine-id
6. **Без K8s компонентов:** Никаких kubeadm, kubelet, kubectl, containerd
7. **Готов к клонированию:** Можно создавать VM из Template

---

## 🚫 Что НЕ должно быть в Template

### Запрещённые компоненты

```bash
# Kubernetes компоненты
kubeadm kubelet kubectl kubernetes-cni

# Container runtime
containerd docker.io docker-ce cri-o

# CNI плагины
flannel calico cilium

# Ingress контроллеры
nginx-ingress traefik

# LoadBalancer
metallb kube-vip

# Специфичные настройки K8s
sysctl настройки для K8s
отключение swap
загрузка модулей ядра
```

### Запрещённые настройки

```bash
# НЕ настраивать swap
# НЕ отключать swap
# НЕ настраивать sysctl для K8s
# НЕ загружать модули ядра
# НЕ настраивать CNI
# НЕ настраивать CRI
```

---

## 📋 Чек-лист готовности

### Перед конвертацией в Template

- [ ] Ubuntu 24.04 LTS установлен (minimal)
- [ ] Все обязательные пакеты установлены
- [ ] Cloud-init настроен и протестирован
- [ ] open-vm-tools установлен и работает
- [ ] SSH доступ работает (k8s-admin:admin)
- [ ] Система обновлена (apt update && apt upgrade)
- [ ] Логи очищены
- [ ] History очищен
- [ ] SSH keys удалены
- [ ] Machine-id сброшен
- [ ] НЕТ kubeadm, kubelet, kubectl, containerd
- [ ] НЕТ Docker
- [ ] НЕТ CNI плагинов
- [ ] НЕТ Ingress контроллеров
- [ ] НЕТ LoadBalancer компонентов

### После конвертации в Template

- [ ] Template создан: `k3s-ubuntu2404-minimal-template`
- [ ] Тестовое клонирование успешно
- [ ] Cloud-init отработал корректно
- [ ] Статический IP настроен
- [ ] DNS работает
- [ ] Интернет доступен
- [ ] SSH доступ работает
- [ ] Hostname установлен правильно

---

## 🎯 Следующие шаги

1. **Создать VM в vSphere** по этим требованиям
2. **Установить Ubuntu 24.04 LTS** (minimal)
3. **Выполнить скрипт подготовки** (будет создан в Этапе 3)
4. **Конвертировать в Template** (будет создан в Этапе 5)
5. **Валидировать Template** (будет создан в Этапе 6)

---

**Создано:** 2025-10-24
**AI-агент:** VM Template Specialist
**Цель:** Минимальная VM Template для k3s без K8s компонентов
