# Процесс установки k3s Server Node

> **Этап:** 1.1 - Server Node Setup
> **Цель:** Понимание процесса установки k3s Server
> **Дата:** 2025-10-24

---

## 🎯 Что такое k3s Server Node?

**k3s Server Node** - это единый компонент, который включает:

- **Control Plane:** API Server, Controller Manager, Scheduler
- **etcd:** Встроенная база данных кластера
- **kubelet:** Может запускать workload pods
- **Встроенные компоненты:** Traefik, ServiceLB, CoreDNS, Flannel

**Главное отличие от "полного" Kubernetes:** ВСЁ В ОДНОМ БИНАРНИКЕ!

---

## 🚀 Простота установки k3s vs kubeadm

### k3s (1 команда):
```bash
curl -sfL https://get.k3s.io | sh -s - server --node-ip 10.246.10.50
```

### kubeadm (многошаговый процесс):
```bash
# 1. Установка container runtime
apt-get install containerd
# 2. Установка kubeadm, kubelet, kubectl
apt-get install kubeadm kubelet kubectl
# 3. Инициализация control plane
kubeadm init --apiserver-advertise-address=10.246.10.50
# 4. Установка CNI (Flannel/Cilium)
kubectl apply -f flannel.yaml
# 5. Установка Ingress Controller
kubectl apply -f traefik.yaml
# ... и так далее
```

**Вывод:** k3s экономит часы времени! ⚡

---

## 📦 Что происходит при установке k3s?

### 1. Скачивание и установка (30 сек)
```bash
# Скрипт https://get.k3s.io делает:
wget https://github.com/k3s-io/k3s/releases/download/[version]/k3s
chmod +x k3s
mv k3s /usr/local/bin/
ln -s /usr/local/bin/k3s /usr/local/bin/kubectl  # kubectl = k3s!
```

### 2. Создание systemd сервиса (5 сек)
```bash
# Создаётся /etc/systemd/system/k3s.service
systemctl enable k3s
systemctl start k3s
```

### 3. Инициализация кластера (30-60 сек)
- Создаётся встроенный etcd: `/var/lib/rancher/k3s/server/db/`
- Генерируются TLS сертификаты: `/var/lib/rancher/k3s/server/tls/`
- API Server поднимается на порту 6443
- Scheduler и Controller Manager запускаются

### 4. Запуск встроенных компонентов (30-60 сек)
- **Flannel CNI:** Сетевое взаимодействие pods
- **CoreDNS:** DNS для кластера
- **Traefik:** Ingress Controller (HTTP/HTTPS)
- **ServiceLB:** LoadBalancer для Services
- **Local-path:** Storage provisioner

### 5. Создание kubeconfig (1 сек)
```bash
# Автоматически создаётся:
/etc/rancher/k3s/k3s.yaml  # Готовый kubeconfig!
```

**Общее время:** 2-3 минуты vs 30+ минут для kubeadm

---

## 🗂️ Файловая структура после установки

```
/usr/local/bin/
├── k3s                    # Главный бинарник (всё в одном)
└── kubectl -> k3s         # kubectl = symlink к k3s

/etc/rancher/k3s/
└── k3s.yaml              # kubeconfig (готовый к использованию)

/var/lib/rancher/k3s/
├── server/
│   ├── db/               # Встроенный etcd
│   ├── tls/              # TLS сертификаты
│   ├── manifests/        # Встроенные компоненты (Traefik, CoreDNS)
│   └── node-token        # Token для присоединения Agent нод
└── agent/                # Данные kubelet

/etc/systemd/system/
└── k3s.service           # systemd сервис
```

---

## 🔧 Архитектура k3s Server на нашей VM

```
┌─────────────────────────────────────────┐
│              k3s-server-01              │
│            10.246.10.50                 │
└─────────────────────────────────────────┘
                    │
        ┌───────────┼───────────┐
        │           │           │
   ┌────▼────┐ ┌────▼────┐ ┌────▼────┐
   │ API     │ │ etcd    │ │ kubelet │
   │ Server  │ │ (built- │ │ (local  │
   │ :6443   │ │ in)     │ │ pods)   │
   └─────────┘ └─────────┘ └─────────┘
        │           │           │
   ┌────▼────┐ ┌────▼────┐ ┌────▼────┐
   │Scheduler│ │Controller│ │ Flannel │
   │Manager  │ │ Manager  │ │ CNI     │
   └─────────┘ └─────────┘ └─────────┘
        │           │           │
   ┌────▼─────────────▼───────────▼────┐
   │        Встроенные pods:           │
   │  - traefik (ingress)              │
   │  - coredns (dns)                  │
   │  - servicelb (loadbalancer)       │
   │  - local-path (storage)           │
   └───────────────────────────────────┘
```

**Все компоненты в одном процессе k3s!**

---

## 🎛️ Параметры установки для нашего сервера

Команда установки:
```bash
curl -sfL https://get.k3s.io | sh -s - server \
  --write-kubeconfig-mode 644 \
  --node-ip 10.246.10.50 \
  --flannel-iface ens192 \
  --node-name k3s-server-01
```

**Объяснение параметров:**
- `server` - режим установки (Server vs Agent)
- `--write-kubeconfig-mode 644` - права доступа к kubeconfig (можно читать без sudo)
- `--node-ip 10.246.10.50` - IP адрес ноды для кластера
- `--flannel-iface ens192` - сетевой интерфейс для Flannel CNI
- `--node-name k3s-server-01` - имя ноды в кластере

**Что НЕ отключаем (всё нужно для dev-кластера):**
- ✅ Traefik - встроенный ingress controller
- ✅ ServiceLB - встроенный load balancer
- ✅ Local-path - встроенное локальное хранилище
- ✅ Flannel - встроенный CNI

---

## 🔗 Сравнение с "полным" Kubernetes

| Компонент | k3s | kubeadm |
|-----------|-----|---------|
| **Установка** | 1 команда | 10+ команд |
| **API Server** | ✅ Встроен | Отдельный pod |
| **etcd** | ✅ Встроен | Отдельный pod |
| **Scheduler** | ✅ Встроен | Отдельный pod |
| **Controller** | ✅ Встроен | Отдельный pod |
| **CNI** | ✅ Flannel встроен | Нужно устанавливать |
| **Ingress** | ✅ Traefik встроен | Нужно устанавливать |
| **LoadBalancer** | ✅ ServiceLB встроен | Нужно устанавливать |
| **Storage** | ✅ Local-path встроен | Нужно устанавливать |
| **Размер** | ~50 МБ бинарник | Множество компонентов |

**k3s = "Kubernetes в одной коробке"** 📦

---

## ⏱️ Timeline установки

```
[0:00] curl -sfL https://get.k3s.io | sh -s - server ...
[0:30] ✅ k3s binary скачан и установлен
[0:35] ✅ systemd service создан и запущен
[1:00] ✅ Control plane инициализирован
[1:30] ✅ Встроенные компоненты запущены
[2:00] ✅ kubeconfig готов
[2:30] ✅ kubectl работает

Всего: ~2-3 минуты!
```

---

## 🎉 Результат установки

После успешной установки получаем:
- 🟢 **Работающий Kubernetes API Server** на https://10.246.10.50:6443
- 🟢 **kubeconfig** готовый к использованию
- 🟢 **node-token** для присоединения Agent нод
- 🟢 **kubectl** команды работают
- 🟢 **Встроенные сервисы** готовы к использованию

**Следующий шаг:** Клонирование VM для Server ноды → `02-clone-vm-for-server.md`

---

**Создано:** 2025-10-24
**AI-агент:** Server Node Setup Specialist
**Для:** k3s на vSphere проект 🚀
