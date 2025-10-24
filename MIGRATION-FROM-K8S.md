# Миграция с "полного" Kubernetes на k3s

> **Аудитория:** Team Lead, Операторы, переходящие с k8s на k3s
> **Цель:** Понять ключевые отличия и что нужно изменить

---

## 🎯 Зачем мигрировать на k3s?

### Проблемы с "полным" Kubernetes:
- ❌ Сложная установка (kubeadm, kube-vip, множество компонентов)
- ❌ Долгое время развёртывания (4+ часов)
- ❌ Высокие требования к ресурсам
- ❌ Много "движущихся частей" = больше точек отказа
- ❌ Сложность для новичков в Kubernetes

### Преимущества k3s:
- ✅ Простая установка (одна команда)
- ✅ Быстрое развёртывание (1.5 часа)
- ✅ Меньше ресурсов (512 МБ RAM vs 2 ГБ)
- ✅ Встроенные компоненты "из коробки"
- ✅ Проще понять и отладить

---

## 📋 Сравнение проектов

### Инфраструктура (переиспользуется)

| Компонент | k8s проект | k3s проект | Изменения |
|-----------|------------|------------|-----------|
| **vSphere** | 8.0.3 | 8.0.3 | ✅ Без изменений |
| **NSX-T** | 4.2.3, T1-k8s-zeon-dev | 4.2.3, T1-k8s-zeon-dev | ✅ Переиспользуем |
| **Segment** | k8s-zeon-dev-segment | k8s-zeon-dev-segment | ✅ Переиспользуем |
| **Subnet** | 10.246.10.0/24 | 10.246.10.0/24 | ✅ Переиспользуем |

### Компоненты кластера (меняется)

| Компонент | k8s (kubeadm) | k3s | Комментарий |
|-----------|---------------|-----|-------------|
| **Control Plane** | 3 ноды (cp-01, cp-02, cp-03) | 1 нода (k3s-server-01) | k3s: начинаем с 1, HA позже |
| **Workers** | 2 ноды (w-01, w-02) | 2 ноды (agent-01, agent-02) | Аналогично |
| **Итого нод** | 5 (3 CP + 2 W) | 3 (1 S + 2 A) | k3s: меньше нод |
| **API VIP** | kube-vip (10.246.10.100) | Не нужен (прямой IP server) | k3s: упрощение |
| **CNI** | Cilium (устанавливаем) | Flannel (встроен) | k3s: из коробки |
| **Ingress** | NGINX (устанавливаем) | Traefik (встроен) | k3s: из коробки |
| **LoadBalancer** | MetalLB (устанавливаем) | ServiceLB (встроен) | k3s: из коробки |
| **Storage** | Local-path (устанавливаем) | Local-path (встроен) | k3s: из коробки |

### IP-адресация (разные диапазоны)

| Назначение | k8s проект | k3s проект | Конфликты |
|------------|------------|------------|-----------|
| **Control Plane** | 10.246.10.10-12 | 10.246.10.50 | ✅ Нет |
| **Workers** | 10.246.10.20-30 | 10.246.10.51-52 | ✅ Нет |
| **API VIP** | 10.246.10.100 | Не используется | ✅ Нет |
| **MetalLB/ServiceLB** | 10.246.10.200-220 | 10.246.10.200-220 | ✅ Можно переиспользовать |

**Вывод:** Разные IP диапазоны = никаких конфликтов между k8s и k3s ✅

---

## 🔄 Что меняется

### VM Template

**k8s проект:**
```
VM Template: k8s-ubuntu2404-template
Содержит:
  - Ubuntu 24.04 LTS
  - kubeadm, kubelet, kubectl (предустановлены)
  - containerd (настроен)
  - sysctl настройки
  - swap отключен
```

**k3s проект:**
```
VM Template: k3s-ubuntu2404-minimal-template
Содержит:
  - Ubuntu 24.04 LTS (minimal)
  - Базовые утилиты (curl, wget, etc.)
  - ❌ БЕЗ kubeadm, kubelet, kubectl
  - ❌ БЕЗ containerd
  - ❌ БЕЗ K8s-специфичных настроек

k3s установит всё сам!
```

**Важно:** Нужен **новый** VM Template! Старый от k8s не подходит.

### Процесс установки

**k8s проект (kubeadm):**
```bash
# На первом Control Plane
1. Настроить kube-vip манифест
2. kubeadm init --config kubeadm-config.yaml --upload-certs
3. Скопировать kubeconfig
4. Сохранить join token

# На остальных Control Plane
5. kubeadm join [VIP]:6443 --token ... --control-plane --certificate-key ...

# На Workers
6. kubeadm join [VIP]:6443 --token ...

# Установка CNI
7. kubectl apply -f cilium-install.yaml

# Ждём пока всё поднимется
8. Валидация (15+ минут)
```
**Время:** 2-4 часа, 8+ шагов

**k3s проект:**
```bash
# На Server ноде
1. curl -sfL https://get.k3s.io | sh -

# На Agent нодах
2. curl -sfL https://get.k3s.io | K3S_URL=... K3S_TOKEN=... sh -

# Всё уже работает!
3. kubectl get nodes  # Сразу Ready
```
**Время:** 10-15 минут, 3 команды

### Скрипты

**k8s проект:**
```
scripts/
├── prepare-vm.sh                # Установка K8s компонентов
├── validate-vm-template.sh      # Валидация template
├── cleanup-vm-for-template.sh   # Очистка перед template
├── pre-bootstrap-setup.sh       # Подготовка к kubeadm
├── cluster-validation.sh        # Валидация кластера
├── generate-join-commands.sh    # Генерация join команд
└── etcd-backup.sh              # Backup etcd
```

**k3s проект:**
```
scripts/
├── prepare-minimal-vm.sh        # Минимальная подготовка
├── install-k3s-server.sh        # Установка server (wrapper)
├── install-k3s-agent.sh         # Установка agent (wrapper)
└── validate-cluster.sh          # Валидация кластера
```

**Вывод:** k3s требует меньше скриптов!

### Манифесты

**k8s проект:**
```
manifests/
├── kubeadm-config-cp01.yaml     # kubeadm конфиг
├── kubeadm-config-join-cp.yaml  # kubeadm join CP
├── kubeadm-config-join-worker.yaml # kubeadm join Worker
├── kube-vip.yaml                # kube-vip для API VIP
├── cilium/                      # Cilium CNI манифесты
├── metallb/                     # MetalLB манифесты
├── nginx-ingress/               # NGINX Ingress манифесты
└── vsphere-csi/                 # vSphere CSI манифесты
```

**k3s проект:**
```
manifests/
├── vsphere-csi/                 # vSphere CSI манифесты (нужен!)
└── examples/                    # Примеры приложений

# Cilium, MetalLB, NGINX — НЕ НУЖНЫ!
# Traefik, ServiceLB, Storage — встроены в k3s
```

**Вывод:** Намного меньше манифестов для управления!

---

## 🛠️ Пошаговая миграция

### Шаг 1: Подготовка

**Что сохранить из k8s проекта:**
- ✅ NSX-T конфигурацию (segments.md)
- ✅ Workflow документы (TEAM-LEAD-GUIDE, AI-AGENT-WORKFLOW)
- ✅ Структуру репозитория

**Что НЕ нужно:**
- ❌ VM Template от k8s
- ❌ kubeadm конфигурации
- ❌ kube-vip манифесты
- ❌ Cilium/MetalLB/NGINX манифесты

**Действия:**
1. Создать папку `k3s/`
2. Скопировать `nsx-configs/segments.md` (адаптировать IP-план)
3. Создать новые документы (README, TEAM-LEAD-GUIDE, PROJECT-PLAN)

### Шаг 2: Создать новый VM Template

**k8s Template НЕ подходит!** Нужен новый minimal template.

**Процесс:**
1. Создать Minimal Ubuntu 24.04 VM в vSphere
2. Установить базовые пакеты (curl, wget, vim)
3. Настроить cloud-init
4. Конвертировать в Template
5. Назвать: `k3s-ubuntu2404-minimal-template`

**AI-агент создаст:** Детальные инструкции в `research/vm-template-prep/`

### Шаг 3: Развернуть k3s кластер

**Следовать PROJECT-PLAN.md:**
1. Этап 0: VM Template
2. Этап 1: Server + Agent ноды
3. Этап 2: vSphere CSI
4. Этап 3: Валидация

**Время:** ~1.5 часа (vs 4+ часов для k8s)

### Шаг 4: Мигрировать workloads (если были)

**Если у вас уже есть приложения в k8s кластере:**

1. **Export resources:**
   ```bash
   kubectl get all -n [namespace] -o yaml > app-export.yaml
   ```

2. **Проверить совместимость:**
   - Ingress: k3s использует Traefik (отличается от NGINX)
   - LoadBalancer: k3s использует ServiceLB (отличается от MetalLB)
   - Storage: проверить StorageClass

3. **Адаптировать манифесты:**
   - Ingress annotations для Traefik
   - LoadBalancer IP может измениться

4. **Apply в k3s:**
   ```bash
   kubectl apply -f app-export.yaml
   ```

**Для нового проекта:** Нет миграции, начинаем с чистого листа ✅

---

## ⚙️ Технические отличия

### kubeconfig

**k8s (kubeadm):**
```bash
# Копируем вручную
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

**k3s:**
```bash
# Уже готов!
sudo cat /etc/rancher/k3s/k3s.yaml

# Или напрямую
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

### kubectl

**k8s (kubeadm):**
```bash
# Устанавливаем отдельно
sudo apt install kubectl
```

**k3s:**
```bash
# Уже встроен как symlink
sudo k3s kubectl get nodes
# или
kubectl get nodes  # если добавлен /usr/local/bin в PATH
```

### Systemd services

**k8s (kubeadm):**
```bash
# Множество services
systemctl status kubelet
systemctl status containerd
systemctl status kube-apiserver      # на CP
systemctl status kube-controller-manager
systemctl status kube-scheduler
systemctl status etcd
```

**k3s:**
```bash
# Один service
systemctl status k3s         # на Server
systemctl status k3s-agent   # на Agent
```

### Logs

**k8s (kubeadm):**
```bash
# Разные источники логов
journalctl -u kubelet
journalctl -u containerd
kubectl logs -n kube-system kube-apiserver-cp-01
kubectl logs -n kube-system kube-controller-manager-cp-01
```

**k3s:**
```bash
# Все логи в одном месте
journalctl -u k3s
# или
journalctl -u k3s-agent
```

### Certificates

**k8s (kubeadm):**
```bash
# Проверка сертификатов
kubeadm certs check-expiration
```

**k3s:**
```bash
# Автоматически ротируются k3s
# Хранятся в /var/lib/rancher/k3s/server/tls/
```

---

## 🔧 Настройка k3s для vSphere

### Что работает "из коробки":
- ✅ Базовый кластер
- ✅ CNI (Flannel)
- ✅ Ingress (Traefik)
- ✅ LoadBalancer (ServiceLB)
- ✅ Local Storage

### Что нужно настроить:
- ⚙️ vSphere CSI Driver (для persistent storage в vSphere)
- ⚙️ Cloud Provider (опционально, для интеграции с vSphere)

**vSphere CSI:**
```bash
# Те же манифесты что и для k8s!
kubectl apply -f vsphere-csi-driver.yaml
kubectl apply -f vsphere-storageclass.yaml
```

**Cloud Provider (опционально):**
```bash
# При установке k3s
curl -sfL https://get.k3s.io | sh -s - server \
  --disable-cloud-controller \
  --kubelet-arg="cloud-provider=external"

# Затем установить vSphere Cloud Provider
```

**Для нашего проекта:** vSphere CSI достаточно, Cloud Provider опционально.

---

## 📊 Сравнение результатов

### Метрики

| Метрика | k8s (kubeadm) | k3s | Улучшение |
|---------|---------------|-----|-----------|
| **Время установки** | 4+ часов | 1.5 часа | 2.5x быстрее |
| **Количество нод** | 5 (3 CP + 2 W) | 3 (1 S + 2 A) | 40% меньше |
| **RAM (Control Plane)** | 8 ГБ × 3 = 24 ГБ | 4 ГБ × 1 = 4 ГБ | 6x меньше |
| **Количество команд** | 20+ команд | 3 команды | 7x меньше |
| **Скриптов** | 7 скриптов | 4 скрипта | 43% меньше |
| **Манифестов** | 15+ файлов | 5 файлов | 66% меньше |
| **Сложность** | Высокая | Низкая | Значительно проще |

### Функциональность

| Функция | k8s | k3s | Комментарий |
|---------|-----|-----|-------------|
| **Kubernetes API** | ✅ | ✅ | 100% совместимость |
| **Deployments** | ✅ | ✅ | Идентично |
| **Services** | ✅ | ✅ | Идентично |
| **Ingress** | ✅ NGINX | ✅ Traefik | Отличается controller |
| **LoadBalancer** | ✅ MetalLB | ✅ ServiceLB | Отличается реализация |
| **Storage** | ✅ vSphere CSI | ✅ vSphere CSI | Идентично |
| **HA Control Plane** | ✅ 3 ноды | ⚠️ Нужно 3 server | k3s: dev=1, prod=3 |

---

## 🎓 Выводы

### Преимущества k3s:
1. **Простота:** Одна команда vs множество шагов
2. **Скорость:** 1.5 часа vs 4+ часов
3. **Ресурсы:** Меньше VM, меньше RAM
4. **Меньше сложности:** Меньше компонентов для управления
5. **Встроенные сервисы:** Всё работает "из коробки"

### Когда k8s лучше:
- Большой production кластер (100+ нод)
- Нужна специфичная конфигурация компонентов
- Multi-tenant с жёсткой изоляцией
- Compliance требования

### Для нашего случая:
**k3s — идеальный выбор!**
- Dev/test кластер
- Начинаем с Kubernetes
- Нужна простота и скорость
- Достаточно встроенных компонентов

---

## 🚀 Следующие шаги

1. **Прочитайте:** [K3S-ARCHITECTURE.md](./K3S-ARCHITECTURE.md)
2. **Следуйте:** [PROJECT-PLAN.md](./PROJECT-PLAN.md)
3. **Начните:** Этап 0 — VM Template Preparation

**Время до работающего кластера:** ~1.5 часа ⚡

---

**Миграция с k8s на k3s — это упрощение без потери функциональности!** 🎉
