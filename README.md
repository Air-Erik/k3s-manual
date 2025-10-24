# k3s на VMware vSphere с NSX-T

> **Упрощённая альтернатива полному Kubernetes**
> **Статус:** 🚀 Готов к развёртыванию
> **Инфраструктура:** VMware vSphere 8.0 + NSX-T 4.2

---

## 📋 О проекте

Этот репозиторий содержит полную документацию и автоматизацию для развёртывания **k3s кластера** на инфраструктуре VMware vSphere с NSX-T.

### Почему k3s?

- ✅ **Простота:** Установка одной командой, единый бинарник
- ✅ **Легковесность:** Меньше ресурсов (512 МБ RAM vs 2 ГБ у k8s)
- ✅ **Скорость:** Быстрое развёртывание (минуты vs часы)
- ✅ **Встроенные компоненты:** Traefik, ServiceLB, Local Storage из коробки
- ✅ **Production-ready:** Используется Rancher, CNCF certified
- ✅ **Совместимость:** 100% Kubernetes API совместимость

### k3s vs "полный" Kubernetes

| Характеристика | k3s | Kubernetes (kubeadm) |
|----------------|-----|----------------------|
| Установка | 1 команда | Многошаговый процесс |
| Размер | ~50 МБ бинарник | Множество компонентов |
| RAM (минимум) | 512 МБ | 2 ГБ |
| Время установки | 2-5 минут | 30+ минут |
| etcd | Встроенный или SQLite | Только etcd |
| Ingress | Traefik (встроен) | Требует установки |
| LoadBalancer | ServiceLB (встроен) | Требует установки |
| Storage | Local-path (встроен) | Требует установки |
| CNI | Flannel (встроен) | Требует установки |
| Сложность управления | Низкая | Высокая |

---

## 🏗️ Архитектура кластера

### Dev-кластер (текущий)
```
┌─────────────────────────────────────────────────────────────┐
│                    NSX-T Segment                            │
│                 k8s-zeon-dev-segment                        │
│                   10.246.10.0/24                           │
└─────────────────────────────────────────────────────────────┘
                              │
                              │
                    ┌─────────▼─────────┐
                    │   k3s-server-01   │
                    │   10.246.10.50    │
                    │  (Server + Agent) │
                    └───────────────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
         ┌────▼────┐     ┌────▼────┐
         │ agent-01│     │ agent-02│
         │ .10.51  │     │ .10.52  │
         └─────────┘     └─────────┘
```

**Компоненты:**
- **1 Server нода** (10.246.10.50) — API Server + etcd + scheduler + controller
- **2 Agent ноды** (10.246.10.51-52) — workload ноды
- **Встроенные сервисы:** Traefik (ingress), ServiceLB, Local Storage

---

## 🚀 Быстрый старт

### Для Team Lead:
1. **Прочитайте** [TEAM-LEAD-GUIDE.md](./TEAM-LEAD-GUIDE.md) — полное руководство
2. **Изучите** [K3S-ARCHITECTURE.md](./K3S-ARCHITECTURE.md) — архитектура и особенности
3. **Следуйте** [PROJECT-PLAN.md](./PROJECT-PLAN.md) — пошаговый план

### Для начала работы:
1. **Инфраструктура готова:** NSX-T segment уже настроен
2. **Создайте VM Template:** Minimal Ubuntu 24.04 (без K8s компонентов!)
3. **Следуйте плану:** Этап за этапом с AI-агентами

---

## 📁 Структура репозитория

```
k3s/
├── README.md                     # Этот файл
├── TEAM-LEAD-GUIDE.md            # Руководство для Team Lead
├── AI-AGENT-WORKFLOW.md          # Процесс работы с AI
├── PROJECT-PLAN.md               # Детальный план проекта
├── K3S-ARCHITECTURE.md           # Архитектура k3s
├── MIGRATION-FROM-K8S.md         # Отличия от "полного" k8s
│
├── docs/                         # Документация по этапам
│   ├── 00-infrastructure-reuse.md    # Переиспользование инфраструктуры
│   ├── 01-vm-template-prep.md        # Подготовка VM Template
│   ├── 02-server-node-setup.md       # Установка Server ноды
│   ├── 03-agent-nodes-setup.md       # Установка Agent нод
│   ├── 04-storage-setup.md           # Настройка vSphere CSI
│   └── 05-validation.md              # Валидация кластера
│
├── manifests/                    # Kubernetes манифесты
│   ├── vsphere-csi/              # vSphere CSI Driver
│   └── examples/                 # Примеры приложений
│
├── scripts/                      # Скрипты автоматизации
│   ├── install-k3s-server.sh    # Установка Server ноды
│   ├── install-k3s-agent.sh     # Установка Agent ноды
│   └── validate-cluster.sh      # Валидация кластера
│
├── research/                     # Research материалы от AI
│   └── (будут создаваться AI-агентами)
│
└── nsx-configs/                  # NSX-T конфигурации
    └── segments.md               # Параметры сети (из k8s проекта)
```

---

## 🎯 Этапы развёртывания

### Этап 0: Подготовка (30 минут)
- ✅ NSX-T segment готов (переиспользуем из k8s проекта)
- ⏳ Создание VM Template (Minimal Ubuntu 24.04)
- ⏳ Подготовка cloud-init конфигураций

### Этап 1: Server нода (15 минут)
- ⏳ Клонирование VM для Server ноды
- ⏳ Установка k3s в режиме server
- ⏳ Получение kubeconfig и node-token

### Этап 2: Agent ноды (10 минут)
- ⏳ Клонирование VM для Agent нод
- ⏳ Присоединение Agent нод к кластеру
- ⏳ Валидация базового кластера

### Этап 3: vSphere CSI (20 минут)
- ⏳ Установка vSphere CSI Driver
- ⏳ Создание StorageClass
- ⏳ Тестирование PVC

### Этап 4: Валидация (15 минут)
- ⏳ Развёртывание тестового приложения
- ⏳ Проверка Traefik ingress
- ⏳ Проверка ServiceLB

**Общее время:** ~1.5 часа (vs 4+ часов для полного k8s)

---

## 🛠️ Технологический стек

### Базовая платформа:
- **k3s:** v1.30+ (последняя stable)
- **OS:** Ubuntu 24.04 LTS (minimal)
- **Container Runtime:** containerd (встроен в k3s)

### Встроенные компоненты k3s:
- **CNI:** Flannel (по умолчанию)
- **Ingress:** Traefik v2
- **LoadBalancer:** Klipper ServiceLB
- **Storage:** Local-path provisioner
- **DNS:** CoreDNS
- **Metrics:** Metrics Server (опционально)

### Дополнительные компоненты:
- **Storage:** vSphere CSI Driver (для persistent storage)
- **Networking:** NSX-T (underlay)

### Инфраструктура:
- **Virtualization:** VMware vSphere 8.0.3
- **Network:** NSX-T 4.2.3
- **Segment:** k8s-zeon-dev-segment (10.246.10.0/24)

---

## 👥 Команда и процесс работы

### Роли:
1. **Team Lead (AI)** — планирование, координация, создание заданий
2. **AI-агенты** — создание документации, скриптов, конфигураций
3. **Оператор (человек)** — выполнение на реальной инфраструктуре

### Workflow:
```
Team Lead → Создаёт задание → AI-агент → Создаёт артефакты
                                    ↓
                            Оператор → Применяет на инфре
                                    ↓
                            Обратная связь → Team Lead
```

**Подробнее:** [AI-AGENT-WORKFLOW.md](./AI-AGENT-WORKFLOW.md)

---

## 📊 Текущий статус

```
⏳ Этап 0: Подготовка                        [██░░░░░░░░░░░░░░░░░░]  10%
⏳ Этап 1: Server нода                       [░░░░░░░░░░░░░░░░░░░░]   0%
⏳ Этап 2: Agent ноды                        [░░░░░░░░░░░░░░░░░░░░]   0%
⏳ Этап 3: vSphere CSI                       [░░░░░░░░░░░░░░░░░░░░]   0%
⏳ Этап 4: Валидация                         [░░░░░░░░░░░░░░░░░░░░]   0%
```

**Следующий шаг:** Подготовка VM Template → см. [docs/01-vm-template-prep.md](./docs/01-vm-template-prep.md)

---

## 🔗 Полезные ссылки

**Официальная документация:**
- [k3s Documentation](https://docs.k3s.io/)
- [k3s GitHub](https://github.com/k3s-io/k3s)
- [vSphere CSI Driver](https://docs.vmware.com/en/VMware-vSphere-Container-Storage-Plug-in/)

**Внутренние документы:**
- [TEAM-LEAD-GUIDE.md](./TEAM-LEAD-GUIDE.md) — руководство для Team Lead
- [AI-AGENT-WORKFLOW.md](./AI-AGENT-WORKFLOW.md) — процесс работы
- [PROJECT-PLAN.md](./PROJECT-PLAN.md) — план проекта

---

## 📝 Примечания

### Отличия от "полного" Kubernetes проекта:
- **Простота:** Один бинарник вместо множества компонентов
- **Скорость:** Установка минуты вместо часов
- **Встроенные компоненты:** Не нужно устанавливать Cilium, MetalLB, NGINX
- **Меньше VM:** 3 ноды вместо 5 для начала

### Переиспользование из k8s проекта:
- ✅ NSX-T segment (k8s-zeon-dev-segment)
- ✅ IP-план (используем диапазон 10.246.10.50-60)
- ✅ Workflow (Team Lead + AI-агенты + Оператор)
- ❌ VM Template (нужен новый, minimal без K8s)
- ❌ kubeadm конфигурации (не используются в k3s)

---

## 🆘 Поддержка

**Если возникают вопросы:**
1. Проверьте [TEAM-LEAD-GUIDE.md](./TEAM-LEAD-GUIDE.md)
2. Изучите [K3S-ARCHITECTURE.md](./K3S-ARCHITECTURE.md)
3. Создайте файл `QUESTIONS.md` с вопросами

---

**Создано:** 2025-10-22
**Team Lead:** AI Orchestrator
**Цель:** Простой и быстрый путь к Kubernetes на vSphere

🚀 **Начните с [TEAM-LEAD-GUIDE.md](./TEAM-LEAD-GUIDE.md)!**
