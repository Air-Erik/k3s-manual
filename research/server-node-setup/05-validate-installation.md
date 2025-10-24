# Валидация установки k3s Server Node

> **Этап:** 1.1 - Server Node Setup
> **Цель:** Комплексная проверка работоспособности k3s Server
> **Дата:** 2025-10-24

---

## 🎯 Цель валидации

Убедиться что k3s Server Node работает корректно и готов к:
- Приему Agent нод
- Развертыванию приложений
- Production использованию

---

## ✅ Чек-лист валидации

### Базовые проверки
- [ ] systemd сервис k3s активен
- [ ] kubectl команды работают
- [ ] Нода в состоянии Ready
- [ ] Все системные pods Running
- [ ] API Server отвечает
- [ ] DNS работает внутри кластера

### Встроенные компоненты k3s
- [ ] Traefik Ingress Controller
- [ ] ServiceLB (Load Balancer)
- [ ] Local-path Storage
- [ ] CoreDNS
- [ ] Flannel CNI

### Сетевая проверка
- [ ] Pod-to-pod коммуникация
- [ ] Service discovery
- [ ] Ingress HTTP трафик

---

## 🔍 Детальные проверки

### 1. Проверка systemd сервиса

```bash
# Статус k3s service
sudo systemctl status k3s

# Ожидаемый результат:
# ● k3s.service - Lightweight Kubernetes
#    Loaded: loaded (/etc/systemd/system/k3s.service; enabled; preset: enabled)
#    Active: active (running) since ...
```

**Проверка автозапуска:**
```bash
# Должен быть enabled
sudo systemctl is-enabled k3s
# Expected: enabled
```

**Проверка логов:**
```bash
# Последние логи (должны быть без ошибок)
sudo journalctl -u k3s -n 20 --no-pager
```

### 2. Проверка kubectl

```bash
# kubectl должен работать без sudo
kubectl version --client

# Проверка подключения к API
kubectl cluster-info

# Ожидаемый вывод:
# Kubernetes control plane is running at https://127.0.0.1:6443
# CoreDNS is running at https://127.0.0.1:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

### 3. Проверка ноды

```bash
# Список нод (должна быть 1 нода в Ready)
kubectl get nodes

# Ожидаемый вывод:
# NAME             STATUS   ROLES                  AGE   VERSION
# k3s-server-01    Ready    control-plane,master   10m   v1.30.x+k3s1

# Детальная информация о ноде
kubectl get nodes -o wide

# Проверка что IP адрес правильный
kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}'
# Должен показать: 10.246.10.50
```

**Проверка условий ноды:**
```bash
kubectl describe node k3s-server-01 | grep -A 10 "Conditions:"

# Должны быть True:
# Ready                True
# MemoryPressure       False
# DiskPressure         False
# PIDPressure          False
```

### 4. Проверка системных pods

```bash
# Все системные pods должны быть Running
kubectl get pods -A

# Ожидаемые pods в kube-system:
# coredns-xxx              1/1   Running
# local-path-provisioner-xxx 1/1   Running
# metrics-server-xxx       1/1   Running
# traefik-xxx              1/1   Running
```

**Детальная проверка каждого компонента:**

**CoreDNS:**
```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=10
```

**Traefik:**
```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
kubectl get svc -n kube-system traefik
```

**Local-path provisioner:**
```bash
kubectl get pods -n kube-system -l app=local-path-provisioner
kubectl get storageclass
# Должен показать: local-path (default)
```

### 5. Проверка API Server

```bash
# Локальная проверка
curl -k https://127.0.0.1:6443/version

# Внешняя проверка
curl -k https://10.246.10.50:6443/version

# Ожидаемый JSON ответ:
# {
#   "major": "1",
#   "minor": "30",
#   "gitVersion": "v1.30.x+k3s1",
#   ...
# }
```

### 6. Проверка DNS

**DNS внутри кластера:**
```bash
# Тест DNS с busybox pod
kubectl run dns-test --image=busybox:1.28 --rm -it --restart=Never -- nslookup kubernetes.default

# Ожидаемый вывод:
# Server:    10.43.0.10
# Address 1: 10.43.0.10 kube-dns.kube-system.svc.cluster.local
# Name:      kubernetes.default
# Address 1: 10.43.0.1 kubernetes.default.svc.cluster.local
```

**DNS резолюция внешних имен:**
```bash
kubectl run dns-external --image=busybox:1.28 --rm -it --restart=Never -- nslookup google.com

# Должен успешно резолвить
```

### 7. Проверка Flannel CNI

```bash
# Проверка flannel интерфейса на ноде
ip addr show flannel.1

# Ожидаемый вывод:
# flannel.1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450
#     inet 10.42.0.0/32 scope global flannel.1
```

**Проверка flannel pods (если используется флагелл как DaemonSet):**
```bash
kubectl get pods -A | grep flannel
# Может быть пустым (flannel встроен в k3s)
```

### 8. Комплексный тест pod-to-pod

```bash
# Создать тестовый deployment
kubectl create deployment nginx-test --image=nginx:1.25 --replicas=2

# Ждать запуска pods
kubectl wait --for=condition=ready pod -l app=nginx-test --timeout=60s

# Проверить что pods получили IP из Flannel диапазона
kubectl get pods -l app=nginx-test -o wide

# IPs должны быть из диапазона 10.42.x.x

# Тест коммуникации между pods
POD1=$(kubectl get pods -l app=nginx-test -o jsonpath='{.items[0].metadata.name}')
POD2=$(kubectl get pods -l app=nginx-test -o jsonpath='{.items[1].metadata.name}')
POD2_IP=$(kubectl get pod $POD2 -o jsonpath='{.status.podIP}')

kubectl exec $POD1 -- curl -s --connect-timeout 5 http://$POD2_IP

# Должен вернуть HTML страницу nginx

# Удалить тест
kubectl delete deployment nginx-test
```

### 9. Проверка Service и ServiceLB

```bash
# Создать тестовый сервис
kubectl create deployment web-test --image=nginx:1.25
kubectl expose deployment web-test --port=80 --type=LoadBalancer

# Проверить что Service получил External IP
kubectl get svc web-test

# ServiceLB должен назначить IP из диапазона 10.246.10.200-220
# Если External IP = <pending>, подождать 1-2 минуты

# Тест доступности
EXTERNAL_IP=$(kubectl get svc web-test -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -s http://$EXTERNAL_IP

# Должен вернуть nginx welcome page

# Удалить тест
kubectl delete svc web-test
kubectl delete deployment web-test
```

### 10. Проверка Storage

```bash
# Создать тестовый PVC
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: local-path
EOF

# Проверить что PVC в состоянии Bound
kubectl get pvc test-pvc

# Создать pod использующий PVC
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: storage-test
spec:
  containers:
  - name: test
    image: busybox:1.28
    command: ['sh', '-c', 'echo "Hello k3s" > /data/test.txt && sleep 30']
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: test-pvc
EOF

# Дождаться завершения
kubectl wait --for=condition=complete pod/storage-test --timeout=60s

# Проверить что файл создался (PV должно быть на /opt/local-path-provisioner/)
sudo find /opt/local-path-provisioner -name "test.txt" -exec cat {} \;
# Должен показать: Hello k3s

# Удалить тест
kubectl delete pod storage-test
kubectl delete pvc test-pvc
```

---

## 🚀 Автоматизированная валидация

Для быстрой проверки используйте скрипт валидации:

```bash
# Запуск полной валидации
./validate-k3s-server.sh

# Или отдельные проверки
./validate-k3s-server.sh --basic        # Только базовые проверки
./validate-k3s-server.sh --network      # Только сетевые проверки
./validate-k3s-server.sh --storage      # Только проверки хранилища
```

---

## 📊 Ожидаемые результаты

### Успешная валидация должна показать:

```
✅ systemd service: active (running)
✅ kubectl: работает
✅ Node status: Ready
✅ System pods: все Running
✅ API Server: отвечает на :6443
✅ DNS: внутренний и внешний работают
✅ CNI: flannel интерфейс активен
✅ ServiceLB: назначает внешние IP
✅ Storage: local-path provisioner работает
✅ Pod-to-pod: коммуникация работает

🎉 k3s Server готов к production!
```

### Производительность:

```
📈 Метрики производительности:
• API Server response time: < 100ms
• Pod startup time: < 30s
• DNS resolution time: < 5s
• Storage provision time: < 10s
```

---

## ❌ Критичные ошибки

**Остановить использование если:**
- Node в состоянии NotReady > 5 минут
- CoreDNS pods в CrashLoopBackOff
- API Server не отвечает
- Pod-to-pod коммуникация не работает
- Storage не может создавать PV

**В таких случаях:**
1. Проверьте troubleshooting guide
2. Соберите логи: `sudo journalctl -u k3s -n 100`
3. При необходимости переустановите k3s

---

## 🎯 Следующий шаг

После успешной валидации переходим к:
**Этап 6:** Troubleshooting Guide → `05-troubleshooting.md`

**Готовность к Agent нодам:**
- Сохраните node-token: `~/k3s-credentials/node-token.txt`
- Server URL: `https://10.246.10.50:6443`
- Все проверки пройдены ✅

---

**Создано:** 2025-10-24
**AI-агент:** Server Node Setup Specialist
**Для:** k3s на vSphere проект 🚀
