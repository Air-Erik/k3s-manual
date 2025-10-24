# Troubleshooting k3s Agent Nodes

> **Этап:** 1.2.6 - Troubleshooting Guide
> **Дата:** 2025-10-24
> **Статус:** 🔧 Руководство по устранению проблем

---

## 📋 Обзор

Этот документ содержит **решения типичных проблем** при установке и эксплуатации k3s Agent нод.

### Структура troubleshooting:
1. **Симптомы проблемы** — что видит оператор
2. **Диагностика** — как определить причину
3. **Решения** — конкретные шаги исправления
4. **Профилактика** — как избежать в будущем

### Типы проблем:
- 🔌 **Подключение:** Agent не может присоединиться к Server
- 🚨 **Статус нод:** NotReady, SchedulingDisabled
- 📦 **Pod scheduling:** Workloads не запускаются на Agent
- 🔑 **Аутентификация:** Неправильные credentials
- 🌐 **Сеть:** Connectivity, CNI, DNS проблемы
- ⚙️ **Система:** Ресурсы, файловая система, службы

---

## 🔌 Проблема 1: Agent нода не присоединяется к кластеру

### Симптомы:

```bash
# k3s-agent service не запускается или падает
sudo systemctl status k3s-agent
# Active: failed (Result: exit-code)

# Логи показывают ошибки подключения
sudo journalctl -u k3s-agent -f
# "failed to contact server"
# "connection refused"
# "timeout"
```

### Диагностика:

#### Шаг 1: Проверить сетевую доступность Server

```bash
# На Agent ноде проверить доступность Server API
ping 10.246.10.50
# PING 10.246.10.50: 56 data bytes
# 64 bytes from 10.246.10.50: icmp_seq=0 ttl=64 time=1.234 ms

# Проверить API порт
curl -k -s --connect-timeout 5 https://10.246.10.50:6443/version
# Должен вернуть JSON с версией k3s

# Если нет ответа:
telnet 10.246.10.50 6443
# Trying 10.246.10.50...
# Connected to 10.246.10.50. (успех)
# или
# Connection refused (проблема)
```

#### Шаг 2: Проверить статус Server ноды

```bash
# SSH к Server ноде
ssh k8s-admin@10.246.10.50

# k3s Server работает?
sudo systemctl status k3s --no-pager
# Active: active (running) - OK
# Active: failed - проблема

# API Server отвечает?
kubectl get nodes
# Если работает - Server OK
# Если ошибка - проблема с Server

exit
```

#### Шаг 3: Проверить node-token

```bash
# На Agent ноде проверить что token правильный
echo $K3S_TOKEN
# Должен быть формата: K10xxx::server:xxxxx
# Длина ~55 символов

# Получить актуальный token с Server
ssh k8s-admin@10.246.10.50 "sudo cat /var/lib/rancher/k3s/server/node-token"
# Сравнить с используемым
```

### Решения:

#### Решение A: Проблема сети

```bash
# 1. Проверить NSX-T connectivity
ping 10.246.10.1  # Gateway
ping 8.8.8.8      # Internet

# 2. Проверить firewall на Agent ноде
sudo ufw status
sudo ufw allow 6443
sudo ufw allow 10250

# 3. Проверить что Agent и Server в одном сегменте
ip route show
# Должен быть route к 10.246.10.0/24
```

#### Решение B: Проблема с Server нодой

```bash
# SSH к Server ноде
ssh k8s-admin@10.246.10.50

# Перезапустить k3s Server если нужно
sudo systemctl restart k3s
sleep 30

# Проверить логи Server
sudo journalctl -u k3s -n 50

# Проверить что API доступен
kubectl get nodes

exit
```

#### Решение C: Неправильный node-token

```bash
# 1. Получить свежий token
TOKEN=$(ssh k8s-admin@10.246.10.50 "sudo cat /var/lib/rancher/k3s/server/node-token")

# 2. Переустановить Agent с правильным token
sudo /usr/local/bin/k3s-agent-uninstall.sh 2>/dev/null || true

# 3. Установить заново
curl -sfL https://get.k3s.io | \
  K3S_URL=https://10.246.10.50:6443 \
  K3S_TOKEN="$TOKEN" \
  sh -s - agent \
  --node-ip $(hostname -I | awk '{print $1}') \
  --node-name $(hostname)
```

#### Решение D: Полная переустановка

```bash
# 1. Удалить существующую установку
sudo /usr/local/bin/k3s-agent-uninstall.sh

# 2. Очистить данные
sudo rm -rf /var/lib/rancher/k3s/
sudo rm -rf /etc/rancher/k3s/

# 3. Установить заново с правильными параметрами
export K3S_NODE_TOKEN="<правильный_token>"
export K3S_NODE_IP="<IP_ноды>"
export K3S_NODE_NAME="<имя_ноды>"

curl -sfL https://get.k3s.io | \
  K3S_URL=https://10.246.10.50:6443 \
  K3S_TOKEN=${K3S_NODE_TOKEN} \
  sh -s - agent \
  --node-ip ${K3S_NODE_IP} \
  --node-name ${K3S_NODE_NAME}
```

---

## 🚨 Проблема 2: Agent нода в состоянии NotReady

### Симптомы:

```bash
# На Server ноде kubectl показывает Agent в NotReady
kubectl get nodes
# NAME           STATUS     ROLES    AGE   VERSION
# k3s-agent-01   NotReady   <none>   5m    v1.30.x+k3s1
```

### Диагностика:

#### Подробная информация о проблемной ноде

```bash
# Детали о состоянии ноды
kubectl describe node k3s-agent-01

# Обратить внимание на:
# Conditions: Ready=False (причина)
# Events: последние события
# Addresses: правильные ли IP адреса
# System Info: ресурсы, версии

# Типичные причины NotReady:
# - kubelet не работает
# - CNI (Flannel) проблемы
# - Недостаточно ресурсов
# - Filesystem проблемы
```

#### Проверка kubelet на Agent ноде

```bash
# SSH к проблемной Agent ноде
ssh k8s-admin@10.246.10.51

# Статус k3s-agent (содержит kubelet)
sudo systemctl status k3s-agent --no-pager

# Логи k3s-agent за последние 100 строк
sudo journalctl -u k3s-agent -n 100

# Искать в логах:
# "kubelet started" - должно быть
# "failed to sync" - проблема
# "network plugin not ready" - CNI проблема
# "disk pressure" - мало места
```

#### Проверка ресурсов

```bash
# На Agent ноде проверить ресурсы
free -h
# Достаточно ли RAM? Минимум 512MB свободной

df -h
# Достаточно ли места? Минимум 1GB свободного в /

# Проверить что нет процессов-пожирателей ресурсов
top
```

### Решения:

#### Решение A: Проблема с kubelet

```bash
# На Agent ноде перезапустить k3s-agent
sudo systemctl restart k3s-agent

# Ожидать 30-60 секунд
sleep 60

# Проверить статус
sudo systemctl status k3s-agent

# На Server ноде проверить что нода Ready
kubectl get nodes
```

#### Решение B: CNI (Flannel) проблемы

```bash
# Проверить Flannel интерфейс на Agent ноде
ip addr show flannel.1
# Должен быть UP с IP 10.42.x.0/32

# Если flannel.1 отсутствует или DOWN:
sudo systemctl restart k3s-agent

# Проверить Flannel процессы
ps aux | grep flannel

# Проверить VXLAN порт 8472
sudo netstat -ulpn | grep 8472
```

#### Решение C: Недостаточно ресурсов

```bash
# Если мало RAM - увеличить в vSphere
# Временно: освободить память
sudo systemctl stop snapd
sudo systemctl stop unattended-upgrades

# Если мало диска - очистить
sudo apt clean
sudo docker system prune -f 2>/dev/null || true
sudo journalctl --vacuum-time=1d

# Увеличить ресурсы VM в vSphere:
# CPU: минимум 2 vCPU
# RAM: минимум 2 GB
# Disk: минимум 40 GB
```

#### Решение D: Filesystem проблемы

```bash
# Проверить filesystem errors
dmesg | grep -i "error\|failed"

# Проверить inode usage
df -i

# Проверить mount points
mount | grep k3s

# Если проблемы с /var/lib/rancher/k3s:
sudo systemctl stop k3s-agent
sudo umount /var/lib/rancher/k3s 2>/dev/null || true
sudo mount -a
sudo systemctl start k3s-agent
```

---

## 📦 Проблема 3: Pods не запускаются на Agent нодах

### Симптомы:

```bash
# Все pods запускаются только на Server ноде
kubectl get pods -A -o wide
# Все pods имеют NODE = k3s-server-01
# Agent ноды пустые

# Или pods в состоянии Pending на Agent нодах
kubectl get pods | grep Pending
```

### Диагностика:

#### Проверить taints и labels нод

```bash
# Проверить taints (ограничения) на нодах
kubectl describe node k3s-agent-01 | grep Taints
kubectl describe node k3s-agent-02 | grep Taints

# Должно быть: Taints: <none>
# Если есть taints - pods не будут планироваться

# Проверить labels нод
kubectl get nodes --show-labels
```

#### Проверить resource requests vs available

```bash
# Доступные ресурсы на нодах
kubectl describe node k3s-agent-01 | grep -A 5 "Allocated resources"

# Проверить что есть свободные CPU/Memory
# Allocatable: cpu: 2, memory: 2Gi
# Requests: cpu: 100m, memory: 200Mi
# → Свободно: cpu: 1900m, memory: 1.8Gi
```

#### Проверить scheduler

```bash
# События scheduler
kubectl get events --sort-by=.metadata.creationTimestamp | tail -20

# Искать сообщения:
# "Scheduled" - успешное размещение
# "FailedScheduling" - проблемы размещения
# "Insufficient cpu/memory" - не хватает ресурсов
```

### Решения:

#### Решение A: Удалить неправильные taints

```bash
# Если на Agent нодах есть taints, удалить их
kubectl taint node k3s-agent-01 <taint-key>-
kubectl taint node k3s-agent-02 <taint-key>-

# Пример удаления стандартного taint:
kubectl taint node k3s-agent-01 node.kubernetes.io/unschedulable-

# Проверить что taints удалены
kubectl describe node k3s-agent-01 | grep Taints
# Должно быть: Taints: <none>
```

#### Решение B: Принудительное размещение на Agent

```bash
# Создать deployment с nodeSelector для тестирования
kubectl create deployment test-on-agent --image=nginx --replicas=1

# Добавить nodeSelector для Agent ноды
kubectl patch deployment test-on-agent -p '{"spec":{"template":{"spec":{"nodeSelector":{"kubernetes.io/hostname":"k3s-agent-01"}}}}}'

# Проверить что pod запустился на Agent ноде
kubectl get pods -o wide | grep test-on-agent

# Если запустился - Agent нода рабочая
# Удалить тест
kubectl delete deployment test-on-agent
```

#### Решение C: Увеличить ресурсы Agent нод

```bash
# В vSphere увеличить ресурсы Agent нод:
# CPU: 4 vCPU (вместо 2)
# RAM: 4 GB (вместо 2)

# После изменения перезапустить ноды:
ssh k8s-admin@10.246.10.51 "sudo reboot"
ssh k8s-admin@10.246.10.52 "sudo reboot"

# Подождать 2-3 минуты и проверить
kubectl get nodes
```

#### Решение D: Настроить pod распределение

```bash
# Добавить pod anti-affinity для равномерного распределения
kubectl create deployment spread-test --image=nginx --replicas=3

# Применить anti-affinity правило
kubectl patch deployment spread-test -p '
{
  "spec": {
    "template": {
      "spec": {
        "affinity": {
          "podAntiAffinity": {
            "preferredDuringSchedulingIgnoredDuringExecution": [
              {
                "weight": 100,
                "podAffinityTerm": {
                  "labelSelector": {
                    "matchExpressions": [
                      {
                        "key": "app",
                        "operator": "In",
                        "values": ["spread-test"]
                      }
                    ]
                  },
                  "topologyKey": "kubernetes.io/hostname"
                }
              }
            ]
          }
        }
      }
    }
  }
}'

# Проверить распределение по нодам
kubectl get pods -o wide | grep spread-test

# Очистить
kubectl delete deployment spread-test
```

---

## 🔑 Проблема 4: Неправильный или устаревший node-token

### Симптомы:

```bash
# Логи Agent показывают authentication failed
sudo journalctl -u k3s-agent -f
# "authentication failed"
# "unauthorized"
# "invalid token"
```

### Диагностика:

```bash
# Проверить используемый token на Agent ноде
sudo systemctl show k3s-agent | grep Environment
# Найти K3S_TOKEN= в переменных

# Получить актуальный token с Server ноды
ssh k8s-admin@10.246.10.50 "sudo cat /var/lib/rancher/k3s/server/node-token"

# Сравнить tokens - должны быть одинаковые
```

### Решения:

#### Получить правильный token и переустановить

```bash
# 1. Получить актуальный token
TOKEN=$(ssh k8s-admin@10.246.10.50 "sudo cat /var/lib/rancher/k3s/server/node-token")
echo "Актуальный token: $TOKEN"

# 2. Удалить Agent с неправильным token
sudo /usr/local/bin/k3s-agent-uninstall.sh

# 3. Переустановить с правильным token
curl -sfL https://get.k3s.io | \
  K3S_URL=https://10.246.10.50:6443 \
  K3S_TOKEN="$TOKEN" \
  sh -s - agent \
  --node-ip $(hostname -I | awk '{print $1}') \
  --node-name $(hostname)

# 4. Проверить успешность
sudo systemctl status k3s-agent
sudo journalctl -u k3s-agent -n 20
```

---

## ⚡ Проблема 5: Agent и Server разных версий k3s

### Симптомы:

```bash
# kubectl показывает разные VERSION для нод
kubectl get nodes
# NAME           STATUS   ROLES                  AGE   VERSION
# k3s-server-01  Ready    control-plane,master   1h    v1.30.5+k3s1
# k3s-agent-01   Ready    <none>                 10m   v1.30.3+k3s1  ← старая версия
```

### Диагностика:

```bash
# Проверить версии k3s binary на нодах
ssh k8s-admin@10.246.10.50 "k3s --version"
ssh k8s-admin@10.246.10.51 "k3s --version"

# Версии должны совпадать
```

### Решения:

#### Обновить k3s на Agent ноде

```bash
# На Agent ноде скачать ту же версию что на Server
ssh k8s-admin@10.246.10.51

# Остановить k3s-agent
sudo systemctl stop k3s-agent

# Обновить k3s binary
curl -sfL https://get.k3s.io | sh -

# Или принудительно скачать конкретную версию
# curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.30.5+k3s1 sh -

# Запустить agent заново
sudo systemctl start k3s-agent

# Проверить версию
k3s --version

exit
```

#### Альтернатива: переустановка Agent

```bash
# Если обновление не помогло - полная переустановка
ssh k8s-admin@10.246.10.51

# Удалить
sudo /usr/local/bin/k3s-agent-uninstall.sh

# Установить заново (получит версию Server автоматически)
TOKEN=$(ssh k8s-admin@10.246.10.50 "sudo cat /var/lib/rancher/k3s/server/node-token")
curl -sfL https://get.k3s.io | \
  K3S_URL=https://10.246.10.50:6443 \
  K3S_TOKEN="$TOKEN" \
  sh -s - agent \
  --node-ip 10.246.10.51 \
  --node-name k3s-agent-01

exit
```

---

## 🗑️ Проблема 6: Полное удаление Agent для переустановки

### Когда нужно полное удаление:

- Agent нода "сломалась" и не восстанавливается
- Нужно изменить IP адрес или hostname ноды
- Множественные проблемы, проще переустановить
- Тестирование процесса установки

### Полная очистка Agent ноды:

```bash
# SSH к Agent ноде
ssh k8s-admin@10.246.10.51

# 1. Остановить и удалить k3s-agent service
sudo systemctl stop k3s-agent 2>/dev/null || true
sudo systemctl disable k3s-agent 2>/dev/null || true

# 2. Удалить через официальный uninstall скрипт
sudo /usr/local/bin/k3s-agent-uninstall.sh 2>/dev/null || true

# 3. Очистить все данные k3s
sudo rm -rf /var/lib/rancher/k3s/
sudo rm -rf /etc/rancher/k3s/

# 4. Удалить k3s binary и скрипты
sudo rm -f /usr/local/bin/k3s
sudo rm -f /usr/local/bin/k3s-agent-uninstall.sh

# 5. Очистить systemd
sudo rm -f /etc/systemd/system/k3s-agent.service
sudo systemctl daemon-reload

# 6. Удалить containerd данные (если нужно)
sudo rm -rf /var/lib/containerd/

# 7. Очистить сетевые интерфейсы
sudo ip link delete flannel.1 2>/dev/null || true
sudo ip link delete cni0 2>/dev/null || true

# 8. Перезагрузить для полной очистки
sudo reboot
```

### Удаление ноды из кластера:

```bash
# На Server ноде удалить ноду из кластера
ssh k8s-admin@10.246.10.50

# Удалить ноду (если она еще в списке)
kubectl delete node k3s-agent-01

# Проверить что удалена
kubectl get nodes

exit
```

### Переустановка с нуля:

```bash
# После reboot Agent ноды - установить заново
ssh k8s-admin@10.246.10.51

# Проверить что система чистая
sudo systemctl status k3s-agent
# Unit k3s-agent.service could not be found. ← это хорошо

ps aux | grep k3s
# Не должно быть процессов k3s

# Установить заново
TOKEN=$(ssh k8s-admin@10.246.10.50 "sudo cat /var/lib/rancher/k3s/server/node-token")

curl -sfL https://get.k3s.io | \
  K3S_URL=https://10.246.10.50:6443 \
  K3S_TOKEN="$TOKEN" \
  sh -s - agent \
  --node-ip 10.246.10.51 \
  --node-name k3s-agent-01

# Проверить установку
sudo systemctl status k3s-agent

exit
```

---

## 🌐 Проблема 7: Сетевые проблемы

### Симптомы CNI/Flannel проблем:

```bash
# Pods не могут обращаться друг к другу
kubectl exec pod1 -- ping <pod2-ip>
# Network unreachable

# flannel.1 интерфейс отсутствует
ssh k8s-admin@10.246.10.51 "ip addr show flannel.1"
# Device "flannel.1" does not exist

# Разные pod subnets на нодах
kubectl get nodes -o jsonpath='{.items[*].spec.podCIDR}'
```

### Решения CNI проблем:

#### Перезапустить Flannel на всех нодах

```bash
# Перезапустить k3s на всех нодах (Flannel встроен)
ssh k8s-admin@10.246.10.50 "sudo systemctl restart k3s"
ssh k8s-admin@10.246.10.51 "sudo systemctl restart k3s-agent"
ssh k8s-admin@10.246.10.52 "sudo systemctl restart k3s-agent"

# Подождать 60 секунд
sleep 60

# Проверить flannel интерфейсы
ssh k8s-admin@10.246.10.50 "ip addr show flannel.1"
ssh k8s-admin@10.246.10.51 "ip addr show flannel.1"
ssh k8s-admin@10.246.10.52 "ip addr show flannel.1"
```

#### Проверить MTU настройки

```bash
# Проверить MTU физических интерфейсов
ssh k8s-admin@10.246.10.50 "ip link show ens192"
ssh k8s-admin@10.246.10.51 "ip link show ens192"
ssh k8s-admin@10.246.10.52 "ip link show ens192"

# MTU должен быть 1500 на ens192
# flannel.1 должен быть 1450 (на 50 меньше для VXLAN overhead)

# Если MTU проблемы - настроить в NSX-T или vSphere
```

---

## 🔍 Общие диагностические команды

### Быстрая диагностика Agent ноды

```bash
#!/bin/bash
# Скрипт быстрой диагностики Agent ноды
# Запускать на Agent ноде

echo "=== AGENT NODE DIAGNOSTICS ==="

echo "Hostname: $(hostname)"
echo "IP: $(hostname -I)"
echo "Uptime: $(uptime)"

echo -e "\n=== K3S AGENT STATUS ==="
systemctl is-active k3s-agent || echo "k3s-agent NOT ACTIVE"

echo -e "\n=== CONNECTIVITY TO SERVER ==="
ping -c 2 10.246.10.50 || echo "Server не пингуется"
curl -k -s --connect-timeout 5 https://10.246.10.50:6443/version >/dev/null && echo "API доступен" || echo "API недоступен"

echo -e "\n=== RESOURCES ==="
free -h | grep Mem
df -h / | tail -1

echo -e "\n=== FLANNEL ==="
ip addr show flannel.1 2>/dev/null | grep inet || echo "flannel.1 отсутствует"

echo -e "\n=== RECENT LOGS ==="
journalctl -u k3s-agent -n 5 --no-pager 2>/dev/null || echo "Нет логов k3s-agent"

echo -e "\n=== DIAGNOSTICS COMPLETE ==="
```

### Сохранить как diagnostic-agent.sh и запускать:

```bash
# На Agent ноде
chmod +x diagnostic-agent.sh
./diagnostic-agent.sh
```

---

## 🆘 Экстренное восстановление

### Если кластер полностью "сломался":

#### 1. Проверить Server ноду (самое важное)

```bash
ssh k8s-admin@10.246.10.50

# Server должен работать
sudo systemctl status k3s
kubectl get nodes

# Если Server не работает - восстановить в первую очередь
sudo systemctl restart k3s
sleep 60
kubectl get nodes

exit
```

#### 2. Переустановить все Agent ноды

```bash
# Параллельно переустановить Agent ноды
TOKEN=$(ssh k8s-admin@10.246.10.50 "sudo cat /var/lib/rancher/k3s/server/node-token")

# Agent-01
ssh k8s-admin@10.246.10.51 "
  sudo /usr/local/bin/k3s-agent-uninstall.sh 2>/dev/null || true
  curl -sfL https://get.k3s.io | K3S_URL=https://10.246.10.50:6443 K3S_TOKEN='$TOKEN' sh -s - agent --node-ip 10.246.10.51 --node-name k3s-agent-01
" &

# Agent-02
ssh k8s-admin@10.246.10.52 "
  sudo /usr/local/bin/k3s-agent-uninstall.sh 2>/dev/null || true
  curl -sfL https://get.k3s.io | K3S_URL=https://10.246.10.50:6443 K3S_TOKEN='$TOKEN' sh -s - agent --node-ip 10.246.10.52 --node-name k3s-agent-02
" &

# Ждать завершения
wait

# Проверить результат
sleep 120
ssh k8s-admin@10.246.10.50 "kubectl get nodes"
```

#### 3. Валидация восстановленного кластера

```bash
# Запустить полную валидацию
ssh k8s-admin@10.246.10.50

kubectl get nodes
kubectl get pods -A
kubectl create deployment test-recovery --image=nginx --replicas=3
kubectl wait --for=condition=ready pod -l app=test-recovery --timeout=120s
kubectl get pods -o wide | grep test-recovery
kubectl delete deployment test-recovery

echo "Кластер восстановлен!"
exit
```

---

## 📞 Когда обращаться за помощью

### Проблемы требующие эскалации:

1. **Инфраструктурные проблемы:**
   - NSX-T сегмент недоступен
   - vSphere хосты недоступны
   - Сетевые проблемы в ДЦ

2. **Критические ошибки k3s:**
   - etcd corruption на Server ноде
   - Невозможно восстановить API Server
   - Массовые потери данных

3. **Неизвестные ошибки:**
   - Новые типы ошибок не покрытые в этом guide
   - Kernel panics или system crashes
   - Подозрения на bugs в k3s

### Информация для предоставления при эскалации:

```bash
# Собрать диагностическую информацию
kubectl get nodes -o wide
kubectl get pods -A
kubectl get events --sort-by=.metadata.creationTimestamp | tail -20

# Логи с проблемных нод
ssh k8s-admin@<проблемная-нода> "sudo journalctl -u k3s-agent -n 100"

# Системная информация
ssh k8s-admin@<нода> "uname -a && free -h && df -h"
```

---

## ✅ Проверочный чек-лист после troubleshooting

После решения любых проблем убедитесь что:

- [ ] **Все 3 ноды** в статусе Ready
- [ ] **k3s-agent services** активны на Agent нодах
- [ ] **Системные pods** Running во всех namespaces
- [ ] **Pod scheduling** работает на Agent нодах
- [ ] **Сеть между pods** функционирует
- [ ] **Test deployment** успешно создается и работает

**Команда полной проверки:**
```bash
ssh k8s-admin@10.246.10.50 "
kubectl get nodes &&
kubectl get pods -A | grep -v Running | grep -v Completed &&
kubectl create deployment health-check --image=nginx --replicas=2 &&
kubectl wait --for=condition=ready pod -l app=health-check --timeout=60s &&
kubectl delete deployment health-check &&
echo 'Кластер полностью здоров!'
"
```

---

**Troubleshooting — это норма при работе с Kubernetes! Главное методично диагностировать и решать проблемы! 🔧✅**
