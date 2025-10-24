# k3s Project Plan

> **Цель:** Развернуть k3s кластер на VMware vSphere с NSX-T
> **Статус:** 🚀 Ready to Start
> **Обновлено:** 2025-10-22

---

## Обзор проекта

### Цель
Развернуть работающий k3s кластер на существующей инфраструктуре VMware vSphere с NSX-T, используя упрощённый подход по сравнению с "полным" Kubernetes.

### Почему k3s?
- **Простота:** Установка одной командой vs многошаговый процесс kubeadm
- **Скорость:** 1.5 часа vs 4+ часов для полного k8s
- **Легковесность:** Меньше ресурсов, один бинарник ~50 МБ
- **Встроенные компоненты:** Traefik, ServiceLB, Storage из коробки
- **Production-ready:** CNCF certified, используется в production

### Scope
**Dev-кластер (текущий):**
- 1 Server нода (API + etcd + workloads)
- 2 Agent ноды (workers)
- Встроенные компоненты k3s
- vSphere CSI для persistent storage

**Production (будущее):**
- 3 Server ноды (HA)
- 3+ Agent нод
- Возможная замена компонентов (Cilium, MetalLB)

---

## Этапы проекта

### ✅ Этап -1: Инициализация (COMPLETED)

**Ответственный:** Team Lead
**Срок:** 2025-10-22
**Статус:** ✅ COMPLETED

**Задачи:**
- [x] Создание структуры репозитория
- [x] Копирование NSX-T конфигурации из k8s проекта
- [x] Создание руководств (TEAM-LEAD-GUIDE, AI-AGENT-WORKFLOW)
- [x] Подготовка PROJECT-PLAN (этот документ)
- [x] Создание документации архитектуры (K3S-ARCHITECTURE)

**Артефакты:**
- [x] `k3s/README.md` ✅
- [x] `k3s/TEAM-LEAD-GUIDE.md` ✅
- [x] `k3s/AI-AGENT-WORKFLOW.md` ✅
- [x] `k3s/PROJECT-PLAN.md` ✅ (этот файл)
- [x] `k3s/K3S-ARCHITECTURE.md` ✅
- [x] `k3s/nsx-configs/segments.md` ✅ (адаптирован)
- [x] Структура папок (docs/, manifests/, scripts/, research/) ✅

---

### ⏳ Этап 0: Подготовка инфраструктуры

**Ответственный:** AI-исполнитель + Оператор
**Срок:** TBD
**Зависимости:** Нет (NSX-T уже готов)
**Статус:** ⏳ TODO

#### Задачи:

**0.1. VM Template Preparation**
- **Документ:** `docs/01-vm-template-prep.md`
- **AI задание:** `research/vm-template-prep/AI-AGENT-TASK.md`
- **Цель:** Создать minimal VM Template для k3s (БЕЗ K8s компонентов!)
- **Артефакты:**
  - [ ] Minimal Ubuntu 24.04 VM создана в vSphere
  - [ ] Cloud-init конфигурации для k3s нод
  - [ ] Скрипт `scripts/prepare-minimal-vm.sh`
  - [ ] VM Template создан в vSphere
  - [ ] Тестовое клонирование прошло успешно

**Отличие от k8s:**
- ❌ НЕ устанавливаем kubeadm, kubelet, kubectl
- ❌ НЕ настраиваем containerd заранее
- ✅ Только minimal Ubuntu + базовые утилиты
- ✅ k3s установится сам с containerd

**Критерии завершения этапа 0:**
- [x] NSX-T сегмент готов (переиспользуем) ✅
- [ ] VM Template готов, можно клонировать
- [ ] Cloud-init работает корректно

**Оценка времени:** ~30 минут

---

### ⏳ Этап 1: k3s Cluster Bootstrap

**Ответственный:** AI-исполнитель + Оператор
**Срок:** TBD
**Зависимости:** ✅ Этап 0 завершён
**Статус:** ⏳ TODO

#### Задачи:

**1.1. Server Node Setup**
- **Документ:** `docs/02-server-node-setup.md`
- **AI задание:** `research/server-node-setup/AI-AGENT-TASK.md`
- **Цель:** Установить k3s server ноду
- **Артефакты:**
  - [ ] VM клонирована для Server (10.246.10.50)
  - [ ] Скрипт `scripts/install-k3s-server.sh` создан
  - [ ] k3s установлен на Server ноде
  - [ ] kubeconfig получен (`/etc/rancher/k3s/k3s.yaml`)
  - [ ] node-token сохранён (`/var/lib/rancher/k3s/server/node-token`)
  - [ ] API Server доступен (curl https://10.246.10.50:6443/version)

**Команда установки (пример):**
```bash
curl -sfL https://get.k3s.io | sh -s - server \
  --node-ip 10.246.10.50 \
  --flannel-iface ens192
```

**Критерии успеха:**
- k3s systemd service запущен
- kubectl get nodes показывает 1 node (Server)
- Системные поды работают (traefik, coredns, etc.)

**Оценка времени:** ~15 минут

**1.2. Agent Nodes Setup**
- **Документ:** `docs/03-agent-nodes-setup.md`
- **AI задание:** `research/agent-nodes-setup/AI-AGENT-TASK.md`
- **Цель:** Присоединить Agent ноды к кластеру
- **Артефакты:**
  - [ ] 2 VM клонированы для Agent (10.246.10.51-52)
  - [ ] Скрипт `scripts/install-k3s-agent.sh` создан
  - [ ] Agent ноды присоединены к кластеру
  - [ ] kubectl get nodes показывает 3 ноды (1 Server + 2 Agent)
  - [ ] Все ноды в состоянии Ready

**Команда установки Agent (пример):**
```bash
curl -sfL https://get.k3s.io | K3S_URL=https://10.246.10.50:6443 \
  K3S_TOKEN=[node-token] sh -s - agent \
  --node-ip [agent-ip]
```

**Критерии успеха:**
- Все ноды в состоянии Ready
- Pod можно запланировать на любой ноде
- Базовый кластер работает

**Оценка времени:** ~20 минут (10 мин × 2 agent)

**Критерии завершения этапа 1:**
- [ ] 1 Server нода установлена и работает
- [ ] 2 Agent ноды присоединены
- [ ] kubectl get nodes показывает 3 Ready ноды
- [ ] Встроенные компоненты работают (Traefik, CoreDNS)
- [ ] Можно развернуть тестовый pod

---

### ⏳ Этап 2: Storage Setup (vSphere CSI)

**Ответственный:** AI-исполнитель + Оператор
**Срок:** TBD
**Зависимости:** ✅ Этап 1 завершён
**Статус:** ⏳ TODO

#### Задачи:

**2.1. vSphere CSI Driver Installation**
- **Документ:** `docs/04-storage-setup.md`
- **AI задание:** `research/vsphere-csi-setup/AI-AGENT-TASK.md`
- **Цель:** Настроить persistent storage через vSphere
- **Артефакты:**
  - [ ] vSphere CSI манифесты созданы в `manifests/vsphere-csi/`
  - [ ] vSphere credentials настроены (Secret)
  - [ ] CSI Driver установлен
  - [ ] StorageClass создан
  - [ ] Тестовый PVC создан и bound
  - [ ] Тестовый Pod с PVC работает

**Важно:**
- k3s использует тот же vSphere CSI что и полный k8s
- Требуется vCenter credentials
- Datastore должен быть доступен

**Критерии успеха:**
- CSI Controller и Node pods работают
- StorageClass создан (с параметрами vSphere)
- PVC успешно создаётся и привязывается
- Pod может монтировать volume

**Оценка времени:** ~25 минут

**Критерии завершения этапа 2:**
- [ ] vSphere CSI Driver установлен
- [ ] StorageClass создан и протестирован
- [ ] PVC/PV работают корректно
- [ ] Persistent storage доступен для приложений

---

### ⏳ Этап 3: Validation & Testing

**Ответственный:** AI-исполнитель + Оператор
**Срок:** TBD
**Зависимости:** ✅ Этапы 1-2 завершены
**Статус:** ⏳ TODO

#### Задачи:

**3.1. Cluster Validation**
- **Документ:** `docs/05-validation.md`
- **AI задание:** `research/validation/AI-AGENT-TASK.md`
- **Цель:** Убедиться что кластер полностью работоспособен
- **Артефакты:**
  - [ ] Скрипт `scripts/validate-cluster.sh` создан
  - [ ] Тестовое приложение развёрнуто
  - [ ] Traefik Ingress протестирован
  - [ ] ServiceLB протестирован (LoadBalancer service)
  - [ ] Local Storage протестирован
  - [ ] vSphere CSI протестирован
  - [ ] Документация troubleshooting создана

**Тесты:**
1. **Базовый deployment:**
   ```bash
   kubectl create deployment nginx --image=nginx --replicas=3
   kubectl expose deployment nginx --port=80 --type=LoadBalancer
   ```

2. **Ingress test:**
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: test-ingress
   spec:
     rules:
     - host: test.k3s.local
       http:
         paths:
         - path: /
           pathType: Prefix
           backend:
             service:
               name: nginx
               port:
                 number: 80
   ```

3. **Storage test:**
   ```bash
   kubectl apply -f manifests/examples/pvc-test.yaml
   kubectl apply -f manifests/examples/pod-with-pvc.yaml
   ```

**Критерии успеха:**
- Deployment успешно создаётся
- LoadBalancer service получает external IP
- Ingress работает с Traefik
- PVC создаётся и bind к PV
- Pod может писать в persistent volume

**Оценка времени:** ~20 минут

**Критерии завершения этапа 3:**
- [ ] Все компоненты валидированы
- [ ] Тестовое приложение работает
- [ ] Ingress доступен
- [ ] LoadBalancer работает
- [ ] Storage функционален
- [ ] Troubleshooting guide создан

---

## Tracking прогресса

### Общий статус этапов:
```
✅ Этап -1: Инициализация            [████████████████████] 100%
⏳ Этап  0: Подготовка               [░░░░░░░░░░░░░░░░░░░░]   0%
⏳ Этап  1: Cluster Bootstrap        [░░░░░░░░░░░░░░░░░░░░]   0%
⏳ Этап  2: Storage Setup            [░░░░░░░░░░░░░░░░░░░░]   0%
⏳ Этап  3: Validation               [░░░░░░░░░░░░░░░░░░░░]   0%
```

### Estimated Timeline:
| Этап | Оценка времени | Зависимости |
|------|---------------|--------------|
| 0 | 30 мин | Нет |
| 1.1 | 15 мин | Этап 0 |
| 1.2 | 20 мин | Этап 1.1 |
| 2 | 25 мин | Этап 1 |
| 3 | 20 мин | Этапы 1-2 |
| **Итого** | **~1.5 часа** | - |

**vs полный Kubernetes:** ~4+ часа (kubeadm + kube-vip + HA + CNI + MetalLB + NGINX)

---

## Риски и меры митигации

### Риск 1: k3s версия несовместима с vSphere CSI
**Вероятность:** Низкая
**Воздействие:** Среднее
**Митигация:** Использовать последнюю stable версию k3s

### Риск 2: Встроенный Flannel конфликтует с NSX
**Вероятность:** Очень низкая
**Воздействие:** Среднее
**Митигация:** Flannel работает на overlay, NSX на underlay — разные уровни

### Риск 3: VM Template от k8s проекта используется по ошибке
**Вероятность:** Средняя
**Воздействие:** Высокое (конфликты)
**Митигация:**
- Чётко указать в документации: нужен **новый** minimal template
- Назвать template явно: `k3s-ubuntu2404-minimal-template`

### Риск 4: Недостаточно ресурсов на VM
**Вероятность:** Низкая
**Воздействие:** Высокое
**Митигация:**
- Server node: минимум 2 vCPU, 4 GB RAM
- Agent node: минимум 2 vCPU, 2 GB RAM
- Проверить доступные ресурсы перед клонированием

---

## Сравнение с k8s проектом

| Аспект | k8s (kubeadm) | k3s |
|--------|---------------|-----|
| **Установка** | Многошаговый процесс | Одна команда |
| **Время** | 4+ часов | 1.5 часа |
| **VM Template** | С предустановленными K8s компонентами | Minimal Ubuntu |
| **HA Method** | kube-vip (external VIP) | Embedded или external DB |
| **CNI** | Cilium (устанавливается отдельно) | Flannel (встроен) |
| **Ingress** | NGINX (устанавливается отдельно) | Traefik (встроен) |
| **LoadBalancer** | MetalLB (устанавливается отдельно) | ServiceLB (встроен) |
| **Storage** | Local-path (устанавливается отдельно) | Local-path (встроен) |
| **Сложность** | Высокая | Низкая |
| **Ноды (dev)** | 5 (3 CP + 2 Workers) | 3 (1 Server + 2 Agents) |

**Вывод:** k3s значительно проще и быстрее для начала работы с Kubernetes!

---

## Следующие шаги (СЕЙЧАС)

### Для Team Lead:
**← СЛЕДУЮЩИЙ ШАГ:** Создать задание для AI-агента по Этапу 0 (VM Template Prep) ⬅️

**Действия:**
1. Создать `research/vm-template-prep/AI-AGENT-TASK.md`
2. Включить:
   - Требования к minimal Ubuntu VM
   - Cloud-init конфигурации для k3s
   - Скрипты подготовки
   - Отличия от k8s template

### Для оператора:
**Ожидайте:** Team Lead создаст задание для AI-агента

**Затем:**
1. Откройте новый чат с AI-агентом
2. Прикрепите контекстные файлы
3. Следуйте инструкциям из задания

---

## Артефакты проекта

### Документация:
```
k3s/
├── README.md                     ✅
├── TEAM-LEAD-GUIDE.md           ✅
├── AI-AGENT-WORKFLOW.md         ✅
├── PROJECT-PLAN.md              ✅ (этот файл)
├── K3S-ARCHITECTURE.md          ✅
└── MIGRATION-FROM-K8S.md        ⏳
```

### По этапам:
```
docs/
├── 01-vm-template-prep.md       ⏳
├── 02-server-node-setup.md      ⏳
├── 03-agent-nodes-setup.md      ⏳
├── 04-storage-setup.md          ⏳
└── 05-validation.md             ⏳
```

### Research (создаётся AI-агентами):
```
research/
├── vm-template-prep/
│   └── AI-AGENT-TASK.md         ⏳
├── server-node-setup/
│   └── AI-AGENT-TASK.md         ⏳
├── agent-nodes-setup/
│   └── AI-AGENT-TASK.md         ⏳
├── vsphere-csi-setup/
│   └── AI-AGENT-TASK.md         ⏳
└── validation/
    └── AI-AGENT-TASK.md         ⏳
```

---

## Критерии успеха проекта

**Dev-кластер считается успешно развёрнутым, когда:**

✅ **Кластер работает:**
- 1 Server нода + 2 Agent ноды в состоянии Ready
- k3s services запущены (k3s, k3s-agent)
- kubectl доступен и работает

✅ **Встроенные компоненты работают:**
- Traefik принимает ingress трафик
- ServiceLB раздаёт LoadBalancer IPs
- CoreDNS резолвит имена
- Local Storage provisioner создаёт volumes

✅ **vSphere CSI работает:**
- Persistent volumes создаются в vSphere datastore
- PVC успешно bind к PV
- Pods могут монтировать volumes

✅ **Тестовое приложение развёрнуто:**
- Deployment с 3 репликами работает
- Service type LoadBalancer получает IP
- Ingress маршрутизирует трафик
- Persistent data сохраняется

✅ **Документация complete:**
- Все этапы задокументированы
- Troubleshooting guide создан
- Процедуры валидации готовы

---

**Team Lead: Готов начать! Следующий шаг — создать задание для AI-агента по VM Template Prep.**

**Оператор: Ожидайте задание от Team Lead.**

🚀 **Let's build a k3s cluster!**
