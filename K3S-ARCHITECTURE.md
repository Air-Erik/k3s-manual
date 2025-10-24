# k3s Architecture Overview

> **Аудитория:** Team Lead, Операторы, AI-агенты
> **Цель:** Понять как устроен k3s и чем он отличается от "полного" Kubernetes

---

## 🎯 Что такое k3s?

**k3s** — это упрощённый дистрибутив Kubernetes от Rancher Labs (теперь SUSE).

### Ключевые особенности:

- **Единый бинарник:** Всё в одном файле ~50 МБ
- **Низкие требования:** 512 МБ RAM минимум (vs 2 ГБ у k8s)
- **Простая установка:** Одна команда вместо многошаговой процедуры
- **Встроенные компоненты:** Ingress, LoadBalancer, Storage из коробки
- **100% Kubernetes API:** Полная совместимость с k8s
- **CNCF Certified:** Официальный дистрибутив Kubernetes

**k3s = Kubernetes - "лишние" компоненты + удобство**

---

## 🏗️ Архитектура k3s

### Упрощённая схема

```
┌──────────────────────────────────────────────────────┐
│                    k3s Binary                        │
│  ┌────────────────────────────────────────────────┐  │
│  │  API Server + Controller + Scheduler + etcd   │  │  Server Node
│  │  + containerd + kubectl + crictl              │  │
│  └────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────┐  │
│  │  Flannel CNI + CoreDNS + Traefik + ServiceLB  │  │  Built-in
│  │  + Local-Path Storage + Metrics (optional)    │  │  Components
│  └────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────┘
              │
              │ Join with token
              ↓
┌──────────────────────────────────────────────────────┐
│                  k3s Agent Binary                    │
│  ┌────────────────────────────────────────────────┐  │
│  │  kubelet + kube-proxy + containerd             │  │  Agent Node
│  └────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────┘
```

### Server vs Agent

**Server Node:**
- Control Plane компоненты (API, Controller, Scheduler)
- etcd (embedded или external)
- **Может** запускать workload pods (по умолчанию)

**Agent Node:**
- Только kubelet и kube-proxy
- Запускает workload pods
- Подключается к Server через node-token

**Важно:** Server нода в k3s по умолчанию также запускает workloads! (vs k8s где Control Plane обычно tainted)

---

## 📦 Компоненты k3s

### Control Plane

| Компонент | Описание | Отличие от k8s |
|-----------|----------|----------------|
| **API Server** | REST API для k8s | То же самое |
| **Controller Manager** | Управление реплик, endpoints, etc. | То же самое |
| **Scheduler** | Распределение pods по нодам | То же самое |
| **etcd** | Key-value БД для состояния | Embedded в k3s бинарник или SQLite |

**Отличие:** В k3s можно использовать **SQLite** или **external DB** (MySQL, PostgreSQL) вместо etcd для упрощения.

### Data Plane

| Компонент | Описание | Отличие от k8s |
|-----------|----------|----------------|
| **kubelet** | Agent на каждой ноде | То же самое |
| **kube-proxy** | Сетевой прокси | То же самое |
| **containerd** | Container runtime | Встроен в k3s (не требует отдельной установки) |

### Встроенные сервисы

| Сервис | k3s | "Полный" k8s | Примечания |
|--------|-----|--------------|------------|
| **CNI** | Flannel | Требует установки (Cilium, Calico, etc.) | Flannel простой и работает "из коробки" |
| **Ingress** | Traefik v2 | Требует установки (NGINX, etc.) | Traefik удобен для k3s, автоконфигурация |
| **LoadBalancer** | ServiceLB (Klipper) | Требует установки (MetalLB, etc.) | ServiceLB простой, использует HostPort |
| **Storage** | Local-Path | Требует установки | Локальное хранилище на каждой ноде |
| **DNS** | CoreDNS | CoreDNS | То же самое |
| **Metrics** | Metrics Server (optional) | Требует установки | Можно включить флагом |

**Преимущество:** Всё работает сразу после установки!

---

## 🔄 k3s vs "полный" Kubernetes

### Сравнение установки

**"Полный" Kubernetes (kubeadm):**
```bash
1. Установить container runtime (containerd)
2. Установить kubeadm, kubelet, kubectl
3. Настроить sysctl, загрузить модули ядра
4. kubeadm init --config kubeadm-config.yaml
5. Настроить kubeconfig
6. Установить CNI (Cilium)
7. Join worker ноды
8. Установить Ingress Controller (NGINX)
9. Установить LoadBalancer (MetalLB)
10. Установить Storage Provisioner
```
**Время:** 2-4 часа, много шагов

**k3s:**
```bash
# Server node
curl -sfL https://get.k3s.io | sh -

# Agent node
curl -sfL https://get.k3s.io | K3S_URL=... K3S_TOKEN=... sh -
```
**Время:** 5-10 минут, 2 команды

### Сравнение архитектуры

```
┌─────────────────────┐         ┌─────────────────────┐
│   Full Kubernetes   │         │        k3s          │
├─────────────────────┤         ├─────────────────────┤
│ API Server          │         │ k3s binary          │
│ Controller Manager  │    vs   │   (all-in-one)      │
│ Scheduler           │         │                     │
│ etcd (separate)     │         │ + embedded etcd     │
├─────────────────────┤         ├─────────────────────┤
│ kubelet (separate)  │         │ + kubelet           │
│ kube-proxy (sep.)   │         │ + kube-proxy        │
│ containerd (sep.)   │         │ + containerd        │
├─────────────────────┤         ├─────────────────────┤
│ CNI (install)       │         │ + Flannel (built-in)│
│ Ingress (install)   │         │ + Traefik (built-in)│
│ LB (install)        │         │ + ServiceLB (built) │
│ Storage (install)   │         │ + Local-Path (built)│
└─────────────────────┘         └─────────────────────┘

Multiple binaries                Single binary
Manual configuration             Auto-configuration
```

### Сравнение ресурсов

| Компонент | k8s (kubeadm) | k3s | Экономия |
|-----------|---------------|-----|----------|
| **Control Plane** | 2-4 ГБ RAM | 512 МБ - 1 ГБ | ~75% |
| **Worker Node** | 1-2 ГБ RAM | 256-512 МБ | ~75% |
| **Disk** | 20+ ГБ | 10-15 ГБ | ~50% |
| **Бинарники** | ~500 МБ | ~50 МБ | ~90% |

---

## 🔌 Сетевая архитектура k3s

### На нашей инфраструктуре (VMware + NSX-T)

```
┌─────────────────────────────────────────────────────────┐
│                    NSX-T Underlay                       │
│              k8s-zeon-dev-segment                       │
│                 10.246.10.0/24                         │
└─────────────────────────────────────────────────────────┘
                       │
         ┌─────────────┼─────────────┐
         │             │             │
    ┌────▼────┐   ┌────▼────┐   ┌────▼────┐
    │ Server  │   │ Agent 1 │   │ Agent 2 │
    │ .10.50  │   │ .10.51  │   │ .10.52  │
    └─────────┘   └─────────┘   └─────────┘
         │             │             │
    ┌────▼─────────────▼─────────────▼────┐
    │         Flannel Overlay Network      │
    │          10.42.0.0/16 (default)      │
    │                                      │
    │  ┌──────┐  ┌──────┐  ┌──────┐      │
    │  │ Pod  │  │ Pod  │  │ Pod  │      │
    │  └──────┘  └──────┘  └──────┘      │
    └──────────────────────────────────────┘
```

**Уровни сети:**
1. **NSX-T (underlay):** Физическая связность между VM (10.246.10.0/24)
2. **Flannel (overlay):** Виртуальная сеть для pods (10.42.0.0/16)
3. **Services:** Виртуальные IP для сервисов (10.43.0.0/16 по умолчанию)

**Flannel:**
- Использует VXLAN для инкапсуляции pod трафика
- Автоматически настраивается k3s
- Не конфликтует с NSX-T (работают на разных уровнях)

---

## 💾 Storage в k3s

### Local-Path Provisioner (встроенный)

```
┌─────────────┐
│  Pod PVC    │ ──> PV (Local-Path) ──> /var/lib/rancher/k3s/storage/
└─────────────┘                         на ноде где запущен pod
```

**Особенности:**
- Автоматически создаёт директории на ноде
- Простой, но **не поддерживает миграцию** pods между нодами
- Подходит для dev/test, не для production

### vSphere CSI (устанавливаем дополнительно)

```
┌─────────────┐
│  Pod PVC    │ ──> PV (vSphere CSI) ──> vSphere Datastore
└─────────────┘                           (VMDK volumes)
```

**Особенности:**
- Persistent volumes в vSphere datastore
- **Поддерживает миграцию** pods (volume detach/attach)
- Production-ready
- Требует vCenter credentials

**Для нашего проекта:** Используем **vSphere CSI** для production workloads.

---

## 🌐 Ingress и LoadBalancer в k3s

### Traefik Ingress (встроенный)

```
Internet
   │
   │ 80/443
   ↓
┌────────────────┐
│ NSX-T Gateway  │
│  NAT/Firewall  │
└────────┬───────┘
         │
    ┌────▼────┐
    │ Traefik │ ──> Service ──> Pods
    │ DaemonSet│
    └─────────┘
   (на каждой ноде, HostPort)
```

**Особенности:**
- Запускается как DaemonSet на всех нодах
- Использует HostPort (80/443 на каждой ноде)
- Автоматически обнаруживает Ingress ресурсы
- Простая конфигурация

### ServiceLB / Klipper LB (встроенный)

```
Service type=LoadBalancer
         ↓
┌────────────────┐
│  ServiceLB     │ ──> Pods на нодах
│  (Klipper LB)  │
└────────────────┘
   Выделяет NodePort на всех нодах
```

**Особенности:**
- Простой LoadBalancer для dev/test
- Использует NodePort под капотом
- External IP = IP одной из нод
- **Не подходит для production** (нет настоящего LB)

**Для production:** Можно заменить на **MetalLB** (на нашей инфраструктуре есть IP pool 10.246.10.200-220).

---

## 🔒 Security в k3s

### По умолчанию k3s:

- ✅ **TLS везде:** Все компоненты используют TLS
- ✅ **RBAC enabled:** Role-Based Access Control
- ✅ **Network Policies:** Flannel поддерживает (с ограничениями)
- ✅ **Pod Security:** Admission controllers включены
- ⚠️ **Server нода запускает workloads:** Отличие от k8s (можно taint)

### Best practices:

1. **Taint Server ноду** (для production):
   ```bash
   kubectl taint nodes [server-node] node-role.kubernetes.io/master=true:NoSchedule
   ```

2. **Ограничить доступ к API:**
   - Firewall правила (DFW в NSX)
   - Только с разрешённых IP

3. **Использовать kubeconfig с ограниченными правами:**
   - Не использовать admin kubeconfig для приложений

4. **Network Policies:**
   - Ограничить трафик между namespaces

---

## 📈 High Availability (HA) в k3s

### Dev-кластер (текущий):
```
┌─────────────┐
│ Server Node │ ──> Workloads
│   (single)  │
└─────────────┘
   │
   └──> Agent Nodes
```

**Нет HA:** Если Server нода упадёт — кластер недоступен.

### Production HA:
```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│ Server 1    │  │ Server 2    │  │ Server 3    │
│ + etcd      │  │ + etcd      │  │ + etcd      │
└──────┬──────┘  └──────┬──────┘  └──────┬──────┘
       │                │                │
       └────────────────┼────────────────┘
                        │
          ┌─────────────▼──────────────┐
          │    External LB or DNS      │
          │   (для API endpoint)       │
          └────────────────────────────┘
                        │
                 Agent Nodes
```

**HA с embedded etcd:**
- Минимум 3 server ноды (для etcd quorum)
- Встроенный etcd автоматически кластеризуется
- Нужен external load balancer для API endpoint

**Альтернатива:** External Database (MySQL/PostgreSQL) вместо embedded etcd.

**Для нашего Dev-кластера:** Пока достаточно 1 server ноды. HA добавим для production.

---

## 🔧 Конфигурация k3s

### Файлы конфигурации

```
/etc/rancher/k3s/
├── k3s.yaml                 # kubeconfig (Server)
├── config.yaml              # k3s configuration
└── registries.yaml          # container registries config

/var/lib/rancher/k3s/
├── server/
│   ├── manifests/          # Auto-deploy manifests (HelmChart CRDs)
│   ├── node-token          # Token для join Agent нод
│   ├── tls/                # Certificates
│   └── db/                 # etcd data (если embedded)
└── agent/
    └── etc/                # Agent config

/usr/local/bin/
└── k3s                     # Основной бинарник (symlinks: kubectl, crictl, ctr)
```

### Основные параметры установки

**Server:**
```bash
curl -sfL https://get.k3s.io | sh -s - server \
  --write-kubeconfig-mode 644 \           # kubeconfig permissions
  --node-ip 10.246.10.50 \                # IP ноды
  --flannel-iface ens192 \                # Network interface
  --disable traefik \                     # Отключить компонент (опционально)
  --disable servicelb \                   # Отключить компонент (опционально)
  --tls-san k3s-api.zeon.local            # Дополнительное имя для API cert
```

**Agent:**
```bash
curl -sfL https://get.k3s.io | K3S_URL=https://10.246.10.50:6443 \
  K3S_TOKEN=... sh -s - agent \
  --node-ip 10.246.10.51
```

---

## 🎓 Когда использовать k3s vs "полный" k8s

### Используй k3s если:
- ✅ Начинаешь с Kubernetes (learning)
- ✅ Dev/test окружения
- ✅ Edge computing / IoT
- ✅ Малые ресурсы (< 8 ГБ RAM)
- ✅ Нужна простота и скорость установки
- ✅ Single-tenant кластер

### Используй "полный" k8s если:
- ⚠️ Большой production кластер (100+ нод)
- ⚠️ Multi-tenant с жёсткой изоляцией
- ⚠️ Нужны специфичные CNI/CSI/Ingress
- ⚠️ Compliance требования (определённые версии компонентов)
- ⚠️ Уже есть экспертиза в k8s

**Для нашего случая:** k3s отлично подходит для начала! Проще, быстрее, меньше движущихся частей.

---

## 📚 Дополнительные ресурсы

**Официальная документация:**
- [k3s.io](https://k3s.io/)
- [docs.k3s.io](https://docs.k3s.io/)
- [GitHub: k3s](https://github.com/k3s-io/k3s)

**Сравнения:**
- [k3s vs k8s](https://www.suse.com/c/rancher_blog/k3s-vs-k8s/)
- [Lightweight Kubernetes](https://thenewstack.io/k3s-lightweight-kubernetes/)

**vSphere Integration:**
- [vSphere CSI with k3s](https://ranchermanager.docs.rancher.com/how-to-guides/new-user-guides/kubernetes-clusters-in-rancher-setup/set-up-cloud-providers/vsphere)

---

## 📊 Summary

**k3s = упрощённый, но полноценный Kubernetes**

| Аспект | Описание |
|--------|----------|
| **Простота** | Одна команда vs многошаговая установка |
| **Размер** | 50 МБ binary vs 500+ МБ компонентов |
| **Ресурсы** | 512 МБ RAM vs 2 ГБ+ RAM |
| **Время установки** | 5-10 минут vs 2-4 часа |
| **Встроенные компоненты** | Traefik, ServiceLB, Storage из коробки |
| **Совместимость** | 100% Kubernetes API, CNCF certified |
| **Production** | Используется в production (Rancher, IoT, Edge) |

**Для нашего проекта:** k3s — идеальный выбор для быстрого старта с Kubernetes на vSphere!

---

**Следующий документ:** [MIGRATION-FROM-K8S.md](./MIGRATION-FROM-K8S.md)
