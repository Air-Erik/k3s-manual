# Валидация k3s кластера после установки Agent нод

> **Этап:** 1.2.5 - Cluster Validation
> **Дата:** 2025-10-24
> **Статус:** ✅ Проверка готовности кластера

---

## 📋 Обзор

После установки Agent нод необходимо **полностью проверить кластер** перед использованием в production.

### Что проверяем:
1. **Статус всех нод** — все Ready
2. **Системные компоненты** — все Running
3. **Pod scheduling** — workloads размещаются на Agent нодах
4. **Networking** — pods могут общаться между нодами
5. **Flannel CNI** — overlay сеть работает
6. **Встроенные сервисы** — Traefik, CoreDNS, ServiceLB

### Результат валидации:
- ✅ Кластер полностью функционален
- ✅ Готов к развёртыванию приложений
- ✅ Все компоненты работают корректно

---

## 🏛️ Проверка с Server ноды

### SSH к Server ноде

```bash
# Подключение к Server ноде для управления кластером
ssh k8s-admin@10.246.10.50

# Проверить что Server нода работает
hostname
# Ожидается: k3s-server-01

sudo systemctl status k3s --no-pager
# Ожидается: Active: active (running)
```

### Основная проверка нод

```bash
# Список всех нод кластера
kubectl get nodes

# Ожидаемый вывод (все Ready):
# NAME            STATUS   ROLES                  AGE   VERSION
# k3s-server-01   Ready    control-plane,master   1h    v1.30.x+k3s1
# k3s-agent-01    Ready    <none>                 15m   v1.30.x+k3s1
# k3s-agent-02    Ready    <none>                 12m   v1.30.x+k3s1

# ✅ Критерии успеха:
# - Ровно 3 ноды
# - Все в статусе Ready
# - Server имеет роль control-plane,master
# - Agent ноды имеют роль <none> (это нормально)
# - Версии k3s одинаковые у всех нод
```

### Подробная информация о нодах

```bash
# Детальная информация с IP адресами
kubectl get nodes -o wide

# Ожидаемый вывод:
# NAME          STATUS ROLES               AGE VERSION        INTERNAL-IP   EXTERNAL-IP OS-IMAGE       KERNEL-VERSION     CONTAINER-RUNTIME
# k3s-server-01 Ready  control-plane,master 1h  v1.30.x+k3s1  10.246.10.50  <none>      Ubuntu 24.04   6.8.0-xx-generic   containerd://1.7.x-k3s1
# k3s-agent-01  Ready  <none>               15m v1.30.x+k3s1  10.246.10.51  <none>      Ubuntu 24.04   6.8.0-xx-generic   containerd://1.7.x-k3s1
# k3s-agent-02  Ready  <none>               12m v1.30.x+k3s1  10.246.10.52  <none>      Ubuntu 24.04   6.8.0-xx-generic   containerd://1.7.x-k3s1

# ✅ Проверить:
# - INTERNAL-IP соответствуют плану: .50, .51, .52
# - OS-IMAGE = Ubuntu 24.04 на всех нодах
# - CONTAINER-RUNTIME = containerd на всех нодах
# - Kernel версии совместимы
```

### Статус кластера

```bash
# Информация о кластере
kubectl cluster-info

# Ожидаемый вывод:
# Kubernetes control plane is running at https://10.246.10.50:6443
# CoreDNS is running at https://10.246.10.50:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

# Версия API Server
kubectl version --short

# Ожидается:
# Client Version: v1.30.x+k3s1
# Server Version: v1.30.x+k3s1
```

---

## 🔧 Проверка на Agent нодах

### Статус k3s-agent service

```bash
# С Server ноды проверить статус agent на обеих Agent нодах
ssh k8s-admin@10.246.10.51 "sudo systemctl status k3s-agent --no-pager"
ssh k8s-admin@10.246.10.52 "sudo systemctl status k3s-agent --no-pager"

# Ожидается на каждой Agent ноде:
# ● k3s-agent.service - Lightweight Kubernetes
#    Loaded: loaded (/etc/systemd/system/k3s-agent.service; enabled; preset: enabled)
#    Active: active (running) since [время] ago
#    Main PID: [pid] (k3s)
```

### Проверка логов Agent нод

```bash
# Логи последних 20 строк с каждой Agent ноды
echo "=== k3s-agent-01 logs ==="
ssh k8s-admin@10.246.10.51 "sudo journalctl -u k3s-agent -n 20 --no-pager"

echo "=== k3s-agent-02 logs ==="
ssh k8s-admin@10.246.10.52 "sudo journalctl -u k3s-agent -n 20 --no-pager"

# ✅ Успешные сообщения в логах:
# "Successfully registered node k3s-agent-xx"
# "kubelet started"
# "Node controller sync successful"
# "Established connection to apiserver"

# ❌ Проблемы (не должно быть):
# "failed to contact server"
# "authentication failed"
# "connection refused"
```

### Проверка процессов на Agent нодах

```bash
# k3s процессы на Agent нодах
ssh k8s-admin@10.246.10.51 "ps aux | grep k3s | grep -v grep"
ssh k8s-admin@10.246.10.52 "ps aux | grep k3s | grep -v grep"

# Ожидается на каждой Agent ноде:
# root  [pid] ... k3s agent
# И различные child процессы kubelet, containerd
```

### Важно: API Server НЕ доступен с Agent нод

```bash
# Это НОРМАЛЬНО — Agent ноды не имеют доступа к kubectl
ssh k8s-admin@10.246.10.51 "kubectl get nodes"
# Ошибка: The connection to the server localhost:8080 was refused

# ✅ Это правильно! kubectl работает только на Server ноде
# Agent ноды подключаются к API через внутренние механизмы
```

---

## 📦 Проверка системных pods

### Все системные pods

```bash
# На Server ноде: список всех pods во всех namespaces
kubectl get pods -A

# Ожидаемый вывод (все должны быть Running):
# NAMESPACE     NAME                                     READY   STATUS    RESTARTS   AGE
# kube-system   coredns-7b98449c4-xxxxx                  1/1     Running   0          1h
# kube-system   local-path-provisioner-84db5d44d9-xxxxx  1/1     Running   0          1h
# kube-system   metrics-server-67c658944b-xxxxx          1/1     Running   0          1h
# kube-system   traefik-56b8c5fb5c-xxxxx                 1/1     Running   0          1h

# ✅ Все pods должны быть Running
# ✅ READY колонка = 1/1 (или 2/2 для multi-container pods)
# ✅ RESTARTS = 0 или небольшое число
```

### Pods с распределением по нодам

```bash
# Показать на каких нодах запущены системные pods
kubectl get pods -A -o wide

# Ожидается:
# - Некоторые pods на k3s-server-01
# - Возможно некоторые на Agent нодах (зависит от tolerations)
# - Flannel/CNI pods на всех нодах

# Важные системные pods:
# - coredns: обычно 1 replica, может быть на любой ноде
# - traefik: ingress controller, может быть на любой ноде
# - metrics-server: метрики, может быть на любой ноде
# - local-path-provisioner: storage, обычно на Server
```

---

## 🚀 Проверка pod scheduling (размещение workloads)

### Создание тестового deployment

```bash
# Создать простой nginx deployment с 3 репликами
kubectl create deployment nginx-test --image=nginx --replicas=3

# Ожидать создания pods
kubectl wait --for=condition=ready pod -l app=nginx-test --timeout=60s

# Должен вывести:
# pod/nginx-test-xxx condition met
# pod/nginx-test-yyy condition met
# pod/nginx-test-zzz condition met
```

### Проверка распределения pods по нодам

```bash
# Показать где запущены nginx pods
kubectl get pods -o wide | grep nginx-test

# Ожидаемый результат - pods распределены по нодам:
# nginx-test-xxx  1/1  Running  0  2m  10.42.0.x  k3s-server-01
# nginx-test-yyy  1/1  Running  0  2m  10.42.1.x  k3s-agent-01
# nginx-test-zzz  1/1  Running  0  2m  10.42.2.x  k3s-agent-02

# ✅ Успех если:
# - Все 3 pods Running
# - Pods размещены на разных нодах (желательно)
# - Pod IPs из диапазонов Flannel (10.42.x.x)
```

### Проверка работы scheduler

```bash
# Информация о размещении
kubectl describe pods -l app=nginx-test | grep "Node:"

# Ожидается:
# Node: k3s-server-01/10.246.10.50
# Node: k3s-agent-01/10.246.10.51
# Node: k3s-agent-02/10.246.10.52

# Scheduler успешно размещает workloads на Agent нодах!
```

### Очистка тестового deployment

```bash
# Удалить тестовый deployment
kubectl delete deployment nginx-test

# Проверить что pods удалились
kubectl get pods | grep nginx-test
# Не должно быть вывода
```

---

## 🌐 Проверка сети между pods

### Создание test pods на разных нодах

```bash
# Создать test pod на Server ноде (с node selector)
kubectl run test-server --image=nginx --labels="test=server" \
  --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"k3s-server-01"}}}'

# Создать test pod на Agent ноде
kubectl run test-agent --image=nginx --labels="test=agent" \
  --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"k3s-agent-01"}}}'

# Ожидать запуска
kubectl wait --for=condition=ready pod test-server --timeout=60s
kubectl wait --for=condition=ready pod test-agent --timeout=60s
```

### Тест connectivity между pods

```bash
# Получить IP адреса test pods
kubectl get pods -o wide | grep test-

# Ожидается:
# test-server  1/1  Running  0  1m  10.42.0.x  k3s-server-01
# test-agent   1/1  Running  0  1m  10.42.1.x  k3s-agent-01

# Проверить connectivity Server → Agent
kubectl exec test-server -- ping -c 3 $(kubectl get pod test-agent -o jsonpath='{.status.podIP}')

# Проверить connectivity Agent → Server
kubectl exec test-agent -- ping -c 3 $(kubectl get pod test-server -o jsonpath='{.status.podIP}')

# ✅ Успех если ping проходит в обе стороны
# Это подтверждает что Flannel overlay сеть работает
```

### HTTP connectivity test

```bash
# Проверить HTTP соединение между pods
kubectl exec test-server -- curl -s -m 5 $(kubectl get pod test-agent -o jsonpath='{.status.podIP}')
kubectl exec test-agent -- curl -s -m 5 $(kubectl get pod test-server -o jsonpath='{.status.podIP}')

# Ожидается HTML ответ nginx (страница по умолчанию)
# Если timeout или connection refused - проблема сети
```

### Очистка test pods

```bash
# Удалить test pods
kubectl delete pod test-server test-agent

# Проверить что удалились
kubectl get pods | grep test-
# Не должно быть вывода
```

---

## 🕸️ Проверка Flannel CNI

### Flannel интерфейсы на всех нодах

```bash
# Проверить flannel.1 интерфейс на каждой ноде
echo "=== Server node flannel ==="
ssh k8s-admin@10.246.10.50 "ip addr show flannel.1"

echo "=== Agent node 1 flannel ==="
ssh k8s-admin@10.246.10.51 "ip addr show flannel.1"

echo "=== Agent node 2 flannel ==="
ssh k8s-admin@10.246.10.52 "ip addr show flannel.1"

# Ожидается на каждой ноде:
# flannel.1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450
# inet 10.42.X.0/32 scope global flannel.1
#
# Где X = 0 (server), 1 (agent-01), 2 (agent-02)
```

### Flannel pod subnets

```bash
# Каждая нода получает свой pod subnet
# Server:   10.42.0.0/24
# Agent-01: 10.42.1.0/24
# Agent-02: 10.42.2.0/24

# Создать pod на каждой ноде и проверить IP
kubectl run temp-pod-server --image=busybox --sleep=3600 \
  --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"k3s-server-01"}}}'

kubectl run temp-pod-agent1 --image=busybox --sleep=3600 \
  --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"k3s-agent-01"}}}'

kubectl run temp-pod-agent2 --image=busybox --sleep=3600 \
  --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"k3s-agent-02"}}}'

# Получить IPs
kubectl get pods -o wide | grep temp-pod

# Ожидается:
# temp-pod-server  ... 10.42.0.x  k3s-server-01
# temp-pod-agent1  ... 10.42.1.x  k3s-agent-01
# temp-pod-agent2  ... 10.42.2.x  k3s-agent-02

# Удалить временные pods
kubectl delete pod temp-pod-server temp-pod-agent1 temp-pod-agent2
```

### Flannel VXLAN трафик

```bash
# Проверить VXLAN туннели (UDP порт 8472)
ssh k8s-admin@10.246.10.50 "sudo netstat -ulpn | grep 8472"
ssh k8s-admin@10.246.10.51 "sudo netstat -ulpn | grep 8472"
ssh k8s-admin@10.246.10.52 "sudo netstat -ulpn | grep 8472"

# Ожидается на каждой ноде:
# udp  0  0  0.0.0.0:8472  0.0.0.0:*  [pid]/flannel
```

---

## 🛠️ Проверка встроенных сервисов k3s

### Traefik Ingress Controller

```bash
# Проверить что Traefik запущен
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik

# Ожидается:
# NAME                      READY   STATUS    RESTARTS   AGE
# traefik-56b8c5fb5c-xxxxx  1/1     Running   0          1h

# Проверить Traefik service
kubectl get svc -n kube-system traefik

# Ожидается LoadBalancer service
# NAME      TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)
# traefik   LoadBalancer   10.43.x.x      10.246.10.x   80:xxx/TCP,443:xxx/TCP
```

### CoreDNS

```bash
# Проверить CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Ожидается:
# NAME                      READY   STATUS    RESTARTS   AGE
# coredns-7b98449c4-xxxxx   1/1     Running   0          1h

# Тест DNS резолюции
kubectl run dns-test --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default

# Ожидается успешный DNS ответ:
# Name:   kubernetes.default.svc.cluster.local
# Address: 10.43.0.1
```

### Local Path Provisioner (Storage)

```bash
# Проверить storage provisioner
kubectl get pods -n kube-system -l app=local-path-provisioner

# Ожидается:
# NAME                                    READY   STATUS    RESTARTS   AGE
# local-path-provisioner-84db5d44d9-xxxxx 1/1     Running   0          1h

# Проверить StorageClass
kubectl get storageclass

# Ожидается:
# NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
# local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  1h
```

### ServiceLB (встроенный LoadBalancer)

```bash
# ServiceLB автоматически работает для LoadBalancer services
# Проверить что traefik получил External IP

kubectl get svc -n kube-system traefik -o wide

# EXTERNAL-IP должен быть из диапазона ServiceLB (10.246.10.200-220)
# Если <pending> - проверить настройки ServiceLB
```

---

## ✅ Итоговая валидация кластера

### Полная сводка статуса

```bash
# Сводная проверка всего кластера
echo "=== CLUSTER NODES ==="
kubectl get nodes

echo "=== SYSTEM PODS ==="
kubectl get pods -A

echo "=== CLUSTER INFO ==="
kubectl cluster-info

echo "=== STORAGE ==="
kubectl get storageclass

echo "=== SERVICES ==="
kubectl get svc -A
```

### Финальный тест: deployment приложения

```bash
# Создать полноценное приложение для итогового теста
kubectl create deployment final-test --image=nginx --replicas=2

# Создать service
kubectl expose deployment final-test --port=80 --type=LoadBalancer

# Ожидать получения External IP
kubectl wait --for=jsonpath='{.status.loadBalancer.ingress}' service/final-test --timeout=60s

# Проверить работу
kubectl get svc final-test
EXTERNAL_IP=$(kubectl get svc final-test -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Тест HTTP запроса
curl -s http://$EXTERNAL_IP | grep "Welcome to nginx"

# Ожидается: "Welcome to nginx!" в HTML ответе

# Очистка
kubectl delete deployment final-test
kubectl delete service final-test
```

### Проверочный чек-лист

```bash
# Финальный чек-лист - всё должно быть ✅

echo "✅ Cluster Health Check:"

# 1. Все ноды Ready
READY_NODES=$(kubectl get nodes --no-headers | grep -c " Ready ")
echo "Ready nodes: $READY_NODES/3"

# 2. Все system pods Running
RUNNING_PODS=$(kubectl get pods -A --no-headers | grep -c " Running ")
echo "Running system pods: $RUNNING_PODS"

# 3. DNS работает
if kubectl exec -it $(kubectl get pods -l app=final-test -o name | head -1) -- nslookup kubernetes.default >/dev/null 2>&1; then
    echo "✅ DNS working"
else
    echo "❌ DNS issues"
fi

# 4. Pod networking
kubectl run network-test --image=busybox --rm -it --restart=Never -- ping -c 1 8.8.8.8 >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Pod networking working"
else
    echo "❌ Pod networking issues"
fi

echo "=== VALIDATION COMPLETE ==="
```

---

## 📊 Критерии успешной валидации

Кластер считается **полностью готовым** если:

### Ноды (обязательно ✅):
- [ ] **3 ноды в Ready** статусе
- [ ] **Правильные IP адреса**: .50, .51, .52
- [ ] **Одинаковая версия k3s** на всех нодах
- [ ] **Server нода** имеет роли control-plane,master
- [ ] **Agent ноды** имеют роль <none>

### Системные компоненты (обязательно ✅):
- [ ] **CoreDNS** работает (DNS резолюция)
- [ ] **Traefik** работает (ingress controller)
- [ ] **Local Path Provisioner** работает (storage)
- [ ] **Flannel CNI** работает (pod networking)
- [ ] **ServiceLB** работает (LoadBalancer services)

### Networking (обязательно ✅):
- [ ] **Pod-to-pod** связь между нодами
- [ ] **Service discovery** работает
- [ ] **External connectivity** из pods
- [ ] **LoadBalancer** services получают External IP

### Scheduling (обязательно ✅):
- [ ] **Pods размещаются** на Agent нодах
- [ ] **Scheduler** корректно распределяет workloads
- [ ] **Multi-replica deployments** работают

---

## 🚨 Troubleshooting валидации

### Если ноды в NotReady

```bash
# Диагностика NotReady нод
kubectl describe node <node-name>

# Частые причины:
# - kubelet не запущен: перезапустить k3s/k3s-agent
# - CNI проблемы: проверить flannel
# - Ресурсы: проверить RAM/CPU
# - Сеть: проверить connectivity

# Решение:
ssh k8s-admin@<node-ip> "sudo systemctl restart k3s-agent"
```

### Если pods не запускаются

```bash
# Диагностика pod проблем
kubectl describe pod <pod-name>
kubectl logs <pod-name>

# Частые причины:
# - ImagePullBackOff: проблемы с Docker registry
# - CrashLoopBackOff: ошибка в приложении
# - Pending: нет ресурсов или проблемы scheduler

# Проверить events:
kubectl get events --sort-by=.metadata.creationTimestamp
```

### Если сеть не работает

```bash
# Диагностика networking
kubectl get pods -n kube-system | grep flannel

# Если flannel pods отсутствуют или не Running:
ssh k8s-admin@10.246.10.50 "sudo systemctl restart k3s"
ssh k8s-admin@10.246.10.51 "sudo systemctl restart k3s-agent"
ssh k8s-admin@10.246.10.52 "sudo systemctl restart k3s-agent"
```

---

## 📈 Производительность кластера

### Базовые метрики

```bash
# Использование ресурсов нод
kubectl top nodes
# Требует metrics-server (встроен в k3s)

# Использование ресурсов pods
kubectl top pods -A
```

### Тест нагрузки

```bash
# Простой stress test
kubectl create deployment stress-test --image=nginx --replicas=10

# Проверить распределение
kubectl get pods -o wide | grep stress-test

# Должны быть распределены по всем 3 нодам

# Очистка
kubectl delete deployment stress-test
```

---

## ➡️ Следующий шаг

**✅ Кластер полностью валидирован и готов к работе!**

**Имеем:**
- **✅ 3-node кластер:** Server + 2 Agent нод
- **✅ Все компоненты:** API, etcd, scheduler, kubelet, CNI
- **✅ Встроенные сервисы:** Traefik, CoreDNS, ServiceLB, Storage
- **✅ Pod networking:** Flannel VXLAN overlay
- **✅ Load balancing:** ServiceLB для External IP

**Далее:** [06-troubleshooting.md](./06-troubleshooting.md) — руководство по устранению проблем

---

**k3s кластер готов к production workloads! 🎉🚀**
