# Задание для AI-агента: Установка k3s Server Node

> **Этап:** 1.1 - Server Node Setup
> **Ответственный:** AI-агент + Оператор
> **Статус:** 🚀 В работе
> **Дата создания:** 2025-10-24

---

## 📋 Контекст

Ты AI-агент, работающий над проектом **k3s на VMware vSphere с NSX-T**.

### Что уже готово:
- ✅ **VM Template:** `k3s-ubuntu2404-minimal-template` создан и протестирован
- ✅ **Cloud-init конфигурации:** Готовы для всех нод
- ✅ **NSX-T инфраструктура:** Segment и сеть настроены
- ✅ **IP-план:** 10.246.10.50 (Server), 10.246.10.51-52 (Agents)

### Что делаем сейчас:
**Устанавливаем первую k3s Server ноду** — сердце кластера!

---

## 🎯 Цель задания

Установить **k3s в режиме server** на ноде `10.246.10.50` и получить:
1. Работающий Kubernetes API Server
2. kubeconfig для доступа к кластеру
3. node-token для присоединения Agent нод

---

## 💡 Что такое k3s Server Node?

**k3s Server Node** включает:
- **Control Plane:** API Server, Controller Manager, Scheduler
- **etcd:** Встроенная база данных состояния кластера
- **kubelet:** Может также запускать workload pods (по умолчанию)
- **Встроенные компоненты:** Traefik, ServiceLB, CoreDNS, Flannel

**Установка = ОДНА команда:**
```bash
curl -sfL https://get.k3s.io | sh -s - server [параметры]
```

Это намного проще чем `kubeadm` из "полного" Kubernetes!

---

## 🔧 Твоя роль как AI-агента

Ты эксперт по установке k3s. Твоя задача:

1. **Создать пошаговые инструкции** для оператора
2. **Написать скрипт установки** k3s Server с правильными параметрами
3. **Документировать процедуры** получения kubeconfig и node-token
4. **Подготовить валидационные проверки** работоспособности
5. **Создать troubleshooting guide** для типичных проблем

**Важно:** Все артефакты должны быть **готовы к использованию** без изменений!

---

## 📊 Исходные данные

### Server Node Specification:
```yaml
Hostname: k3s-server-01
IP Address: 10.246.10.50
Gateway: 10.246.10.1
DNS: 172.17.10.3, 8.8.8.8
Network Interface: ens192
vCPU: 2
RAM: 4 GB
Disk: 40 GB

SSH User: k8s-admin
SSH Auth: password (admin) или SSH key
```

### k3s Installation Parameters:
```yaml
Installation Method: curl https://get.k3s.io
k3s Version: latest stable
Node IP: 10.246.10.50
Flannel Interface: ens192
```

### Встроенные компоненты k3s (оставляем):
- ✅ **Flannel CNI** — сетевое взаимодействие pods
- ✅ **Traefik Ingress** — входящий HTTP/HTTPS трафик
- ✅ **ServiceLB** — LoadBalancer для Services
- ✅ **Local-Path Storage** — локальное хранилище
- ✅ **CoreDNS** — DNS для кластера

**Не отключаем встроенные компоненты!** Они нужны для dev-кластера.

---

## 📝 Структура задания

Создай следующие артефакты **последовательно**:

---

### Этап 1: Документация процесса установки

**Создай:** `research/server-node-setup/01-installation-process.md`

**Содержание:**
- Обзор процесса установки k3s Server
- Что происходит при выполнении установочного скрипта
- Какие файлы и сервисы создаются
- Архитектура компонентов на Server ноде
- Сравнение с "полным" Kubernetes (kubeadm)

**Цель:** Оператор должен понимать что именно устанавливается.

---

### Этап 2: Клонирование VM для Server

**Создай:** `research/server-node-setup/02-clone-vm-for-server.md`

**Содержание:**
- Пошаговая инструкция клонирования VM из Template в vSphere UI
- Применение cloud-init конфигурации для Server ноды
- Где взять: `manifests/cloud-init/server-node-userdata.yaml` и `server-node-metadata.yaml`
- Первый boot и проверка cloud-init
- SSH подключение к новой VM

**Важно:**
- Использовать vSphere vApp Properties для передачи cloud-init
- Или использовать ISO образ с cloud-init конфигом
- Или использовать VMware guestinfo для cloud-init

**Формат:** Детальные инструкции с указанием каждого параметра.

---

### Этап 3: Скрипт установки k3s Server

**Создай:** `scripts/install-k3s-server.sh`

**Содержание:**
- Проверка prerequisites (network, DNS, disk space)
- Установка k3s через curl
- Правильные параметры установки
- Проверка успешности установки
- Получение kubeconfig
- Сохранение node-token
- Валидация работоспособности

**Требования:**
- Idempotent (можно запускать несколько раз)
- Обработка ошибок (set -e -o pipefail)
- Логирование действий
- Цветной вывод для удобства
- Комментарии на русском языке

**Пример структуры:**
```bash
#!/bin/bash
# Скрипт установки k3s Server Node
# Версия: 1.0
# Дата: 2025-10-24

set -e -o pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Установка k3s Server Node ===${NC}"

# 1. Проверка prerequisites
echo -e "${YELLOW}[1/6] Проверка prerequisites...${NC}"
# ...

# 2. Установка k3s
echo -e "${YELLOW}[2/6] Установка k3s server...${NC}"
curl -sfL https://get.k3s.io | sh -s - server \
  --write-kubeconfig-mode 644 \
  --node-ip 10.246.10.50 \
  --flannel-iface ens192 \
  --node-name k3s-server-01

# 3. Ожидание запуска
echo -e "${YELLOW}[3/6] Ожидание запуска k3s...${NC}"
# ...

# 4. Получение kubeconfig
echo -e "${YELLOW}[4/6] Получение kubeconfig...${NC}"
# ...

# 5. Сохранение node-token
echo -e "${YELLOW}[5/6] Сохранение node-token...${NC}"
# ...

# 6. Валидация
echo -e "${YELLOW}[6/6] Валидация установки...${NC}"
# ...

echo -e "${GREEN}✅ k3s Server успешно установлен!${NC}"
```

**Параметры установки k3s:**
```bash
--write-kubeconfig-mode 644      # Права доступа к kubeconfig (чтобы читать без sudo)
--node-ip 10.246.10.50           # IP адрес ноды
--flannel-iface ens192           # Интерфейс для Flannel CNI
--node-name k3s-server-01        # Имя ноды в кластере
--cluster-init                   # Опционально: для будущего HA (если планируем 3 server)
```

**Не используем (для dev-кластера):**
- `--disable traefik` — оставляем встроенный Traefik
- `--disable servicelb` — оставляем встроенный ServiceLB
- `--flannel-backend=none` — оставляем Flannel

---

### Этап 4: Получение credentials

**Создай:** `research/server-node-setup/03-get-credentials.md`

**Содержание:**

#### 4.1. kubeconfig
```bash
# Где находится
/etc/rancher/k3s/k3s.yaml

# Как получить
sudo cat /etc/rancher/k3s/k3s.yaml

# Как использовать локально
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Или для kubectl на локальной машине
# Скопировать содержимое k3s.yaml
# Заменить server: https://127.0.0.1:6443 → https://10.246.10.50:6443
```

#### 4.2. node-token
```bash
# Где находится
/var/lib/rancher/k3s/server/node-token

# Как получить
sudo cat /var/lib/rancher/k3s/server/node-token

# Для чего нужен
# Этот token используется для присоединения Agent нод (Этап 1.2)
```

#### 4.3. Сохранение в безопасное место
```bash
# Создать директорию для credentials
mkdir -p ~/k3s-credentials

# Сохранить kubeconfig
sudo cp /etc/rancher/k3s/k3s.yaml ~/k3s-credentials/kubeconfig.yaml
sudo chown $(id -u):$(id -g) ~/k3s-credentials/kubeconfig.yaml

# Сохранить node-token
sudo cat /var/lib/rancher/k3s/server/node-token > ~/k3s-credentials/node-token.txt

echo "Credentials сохранены в ~/k3s-credentials/"
```

---

### Этап 5: Валидация установки

**Создай:** `research/server-node-setup/04-validate-installation.md`

**Содержание:**
Комплексные проверки работоспособности k3s Server.

#### 5.1. Проверка systemd сервиса
```bash
# Статус k3s service
sudo systemctl status k3s

# Должен быть: active (running)
```

#### 5.2. Проверка kubectl
```bash
# kubectl уже установлен как symlink к k3s
sudo k3s kubectl version

# Или если настроили kubeconfig
kubectl version
```

#### 5.3. Проверка ноды
```bash
# Список нод (должна быть 1 нода: k3s-server-01)
kubectl get nodes

# Подробная информация
kubectl get nodes -o wide

# Ожидаемый вывод:
# NAME             STATUS   ROLES                  AGE   VERSION
# k3s-server-01    Ready    control-plane,master   1m    v1.30.x+k3s1
```

#### 5.4. Проверка системных pods
```bash
# Все системные pods должны быть Running
kubectl get pods -A

# Ожидаемые namespaces:
# - kube-system: coredns, traefik, metrics-server
# - kube-flannel: flannel daemonset (если используется)
```

#### 5.5. Проверка API Server
```bash
# Доступность API через curl
curl -k https://10.246.10.50:6443/version

# Должен вернуть JSON с версией Kubernetes
```

#### 5.6. Проверка Traefik Ingress
```bash
# Traefik pod должен быть Running
kubectl get pods -n kube-system | grep traefik

# Traefik service
kubectl get svc -n kube-system traefik
```

#### 5.7. Проверка CoreDNS
```bash
# CoreDNS pod должен быть Running
kubectl get pods -n kube-system | grep coredns

# Тест DNS резолюции внутри кластера
kubectl run test-dns --image=busybox:1.28 --rm -it --restart=Never -- nslookup kubernetes.default
```

#### 5.8. Проверка Flannel
```bash
# Проверка flannel интерфейса
ip addr show flannel.1

# Должен существовать с IP из диапазона 10.42.x.x
```

#### 5.9. Комплексный тест
```bash
# Создать тестовый deployment
kubectl create deployment nginx --image=nginx --replicas=1

# Проверить что pod запустился
kubectl get pods

# Проверить логи
kubectl logs deployment/nginx

# Удалить тестовый deployment
kubectl delete deployment nginx
```

**Скрипт валидации:**
Также создай `scripts/validate-k3s-server.sh` с автоматизацией всех проверок.

---

### Этап 6: Troubleshooting Guide

**Создай:** `research/server-node-setup/05-troubleshooting.md`

**Содержание:**
Решения типичных проблем при установке k3s Server.

#### Проблема 1: k3s service не стартует

**Симптомы:**
```bash
sudo systemctl status k3s
# Failed to start k3s
```

**Диагностика:**
```bash
# Логи k3s
sudo journalctl -u k3s -f

# Проверка портов
sudo netstat -tulpn | grep 6443
```

**Решения:**
1. Проверить что порт 6443 свободен
2. Проверить network connectivity
3. Проверить DNS резолюцию
4. Переустановить k3s

#### Проблема 2: Node в состоянии NotReady

**Симптомы:**
```bash
kubectl get nodes
# k3s-server-01   NotReady   ...
```

**Диагностика:**
```bash
kubectl describe node k3s-server-01
# Смотреть Events и Conditions
```

**Решения:**
1. Проверить flannel pod: `kubectl get pods -A | grep flannel`
2. Проверить network connectivity между pods
3. Перезапустить k3s: `sudo systemctl restart k3s`

#### Проблема 3: kubectl не работает

**Симптомы:**
```bash
kubectl get nodes
# The connection to the server localhost:8080 was refused
```

**Решения:**
```bash
# Настроить KUBECONFIG
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Или скопировать в ~/.kube/config
```

#### Проблема 4: CoreDNS pods не стартуют

**Симптомы:**
```bash
kubectl get pods -n kube-system
# coredns   CrashLoopBackOff
```

**Решения:**
1. Проверить логи: `kubectl logs -n kube-system deployment/coredns`
2. Проверить что DNS 172.17.10.3 доступен с ноды
3. Проверить конфигурацию Flannel

#### Проблема 5: Traefik не работает

**Симптомы:**
```bash
kubectl get pods -n kube-system
# traefik   CrashLoopBackOff
```

**Решения:**
1. Проверить логи: `kubectl logs -n kube-system deployment/traefik`
2. Проверить что порты 80/443 свободны на host
3. Проверить ServiceLB

#### Проблема 6: Полная переустановка k3s

```bash
# Остановить k3s
sudo systemctl stop k3s

# Удалить k3s
/usr/local/bin/k3s-uninstall.sh

# Очистить данные
sudo rm -rf /var/lib/rancher/k3s/
sudo rm -rf /etc/rancher/k3s/

# Установить заново
curl -sfL https://get.k3s.io | sh -s - server [параметры]
```

---

### Этап 7: Подготовка к Agent нодам

**Создай:** `research/server-node-setup/06-prepare-for-agents.md`

**Содержание:**
Что нужно сделать перед присоединением Agent нод.

#### 7.1. Проверить что Server готов
```bash
# k3s service работает
sudo systemctl status k3s

# Node в состоянии Ready
kubectl get nodes

# Все системные pods Running
kubectl get pods -A
```

#### 7.2. Сохранить node-token
```bash
# Получить token
sudo cat /var/lib/rancher/k3s/server/node-token

# Сохранить для использования на Agent нодах
# Понадобится для команды установки Agent
```

#### 7.3. Проверить connectivity
```bash
# API Server доступен
curl -k https://10.246.10.50:6443/version

# Порт 6443 открыт
sudo netstat -tulpn | grep 6443
```

#### 7.4. Firewall rules (если используется)
```bash
# Убедиться что порты открыты:
# 6443 - Kubernetes API
# 10250 - Kubelet
# 8472 - Flannel VXLAN (или 4789)

# Если firewall включен
sudo ufw allow 6443/tcp
sudo ufw allow 10250/tcp
sudo ufw allow 8472/udp
```

#### 7.5. Информация для Agent нод
Подготовить следующую информацию для Этапа 1.2:
```yaml
Server URL: https://10.246.10.50:6443
Node Token: [содержимое /var/lib/rancher/k3s/server/node-token]
```

---

## 📦 Артефакты на выходе

После выполнения всех этапов должны быть созданы:

### Документация:
- [ ] `research/server-node-setup/01-installation-process.md`
- [ ] `research/server-node-setup/02-clone-vm-for-server.md`
- [ ] `research/server-node-setup/03-get-credentials.md`
- [ ] `research/server-node-setup/04-validate-installation.md`
- [ ] `research/server-node-setup/05-troubleshooting.md`
- [ ] `research/server-node-setup/06-prepare-for-agents.md`

### Скрипты:
- [ ] `scripts/install-k3s-server.sh` — установка k3s Server
- [ ] `scripts/validate-k3s-server.sh` — валидация установки

---

## ✅ Критерии успеха

Задание считается выполненным когда:

1. **Все артефакты созданы** и сохранены
2. **Скрипты готовы к использованию** без изменений
3. **Инструкции понятны** оператору

**Валидация успеха (выполнит оператор):**
- [ ] VM для Server ноды клонирована из Template
- [ ] k3s Server установлен успешно
- [ ] `systemctl status k3s` показывает active (running)
- [ ] `kubectl get nodes` показывает 1 ноду в Ready
- [ ] Все системные pods в состоянии Running
- [ ] kubeconfig получен и работает
- [ ] node-token сохранён для Agent нод
- [ ] API Server доступен по https://10.246.10.50:6443

---

## 🎯 Порядок работы с оператором

### Для оператора:

**Шаг 1:** Прикрепи к AI-агенту файлы:
- `README.md`
- `nsx-configs/segments.md`
- `research/server-node-setup/AI-AGENT-TASK.md` (это задание)

**Шаг 2:** Используй промпт:
```
Привет! Ты AI-агент, работающий над проектом k3s на vSphere.

Я прикрепил:
1. README.md — обзор проекта
2. nsx-configs/segments.md — параметры сети
3. AI-AGENT-TASK.md — твоя задача

Твоя задача: Установить k3s Server Node.

Контекст:
- Этап 0 (VM Template) завершён успешно ✅
- VM Template готов к клонированию
- Cloud-init конфигурации созданы
- Сейчас устанавливаем первую k3s ноду (Server)

Инфраструктура:
- Server IP: 10.246.10.50
- DNS: 172.17.10.3, 8.8.8.8
- Gateway: 10.246.10.1
- Interface: ens192

k3s — это ПРОСТАЯ установка одной командой!
curl -sfL https://get.k3s.io | sh -s - server [параметры]

Пожалуйста:
1. Прочитай AI-AGENT-TASK.md полностью
2. Создавай артефакты последовательно (Этапы 1-7)
3. Пиши готовые к использованию скрипты
4. Фокус на простоте k3s!

Начнём с Этапа 1: Документация процесса установки.
Готов?
```

**Шаг 3:** Работай с AI итеративно
- AI создаёт артефакт → сохраняешь в репозиторий
- Переходишь к следующему

**Шаг 4:** После получения всех артефактов:
1. Клонируй VM для Server ноды в vSphere
2. Применить cloud-init для IP 10.246.10.50
3. SSH к VM и выполни `scripts/install-k3s-server.sh`
4. Выполни валидацию
5. Сохрани kubeconfig и node-token

**Шаг 5:** Сообщи Team Lead о результатах

---

## ⏱️ Оценка времени

| Этап | AI создание | Оператор применение | Итого |
|------|-------------|---------------------|-------|
| Этапы 1-7 (документы + скрипты) | 15 мин | - | 15 мин |
| Клонирование VM | - | 3 мин | 3 мин |
| Установка k3s Server | - | 5 мин | 5 мин |
| Валидация | - | 5 мин | 5 мин |
| **ИТОГО** | **15 мин** | **13 мин** | **~28 мин** |

---

## 📚 Полезные ссылки для AI-агента

**Официальная документация:**
- [k3s Quick Start](https://docs.k3s.io/quick-start)
- [k3s Installation Options](https://docs.k3s.io/installation/configuration)
- [k3s Server Configuration](https://docs.k3s.io/reference/server-config)
- [k3s Networking](https://docs.k3s.io/networking)

**Важные замечания:**
- k3s устанавливается одной командой (не нужен kubeadm!)
- kubectl уже встроен как symlink
- systemd service создаётся автоматически
- Все компоненты в одном бинарнике

---

## 🎉 Финальная проверка

Перед передачей результатов Team Lead, убедись что:

- ✅ Все 6 документов созданы
- ✅ 2 скрипта готовы (install + validate)
- ✅ Инструкции понятны и детальны
- ✅ Troubleshooting guide покрывает основные проблемы
- ✅ Оператор может выполнить всё без дополнительных вопросов

---

**Удачи, AI-агент! Создавай отличную документацию для k3s Server! 🚀**

**Team Lead ждёт результатов для перехода к Этапу 1.2 (Agent Nodes).**
