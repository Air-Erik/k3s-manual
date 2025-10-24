# Troubleshooting k3s Server Node

> **Этап:** 1.1 - Server Node Setup
> **Цель:** Решение типичных проблем при установке k3s Server
> **Дата:** 2025-10-24

---

## 🎯 Типичные проблемы и решения

Этот guide покрывает 90% проблем при установке k3s Server.

---

## 🚨 Проблема 1: k3s service не стартует

### Симптомы
```bash
sudo systemctl status k3s
# ● k3s.service - Lightweight Kubernetes
#    Active: failed (Result: exit-code)
```

### Диагностика
```bash
# Детальные логи
sudo journalctl -u k3s -n 50 --no-pager

# Проверка портов
sudo netstat -tulpn | grep 6443
```

### Решения

**1. Порт 6443 занят**
```bash
# Найти процесс
sudo lsof -i :6443

# Если другой k3s процесс
sudo pkill k3s
sudo systemctl restart k3s
```

**2. DNS проблемы**
```bash
# Проверить DNS
nslookup github.com

# Временно изменить DNS
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
sudo systemctl restart k3s
```

**3. Недостаток места**
```bash
# Проверить место
df -h /

# Очистить если нужно
sudo apt clean
sudo docker system prune -f  # если Docker установлен
```

---

## 🔴 Проблема 2: Node в состоянии NotReady

### Симптомы
```bash
kubectl get nodes
# k3s-server-01   NotReady   control-plane,master   5m
```

### Диагностика
```bash
kubectl describe node k3s-server-01 | grep -A 10 "Conditions:"
kubectl get pods -A | grep -v Running
```

### Решения

**1. Flannel CNI проблемы**
```bash
# Проверить flannel интерфейс
ip addr show flannel.1

# Если нет интерфейса, перезапустить k3s
sudo systemctl restart k3s

# Ждать до 2 минут
kubectl get nodes --watch
```

**2. Container runtime проблемы**
```bash
# Проверить containerd (встроен в k3s)
sudo k3s crictl info

# Если не работает - переустановка
/usr/local/bin/k3s-uninstall.sh
curl -sfL https://get.k3s.io | sh -s - server [ваши параметры]
```

**3. Сетевые проблемы**
```bash
# Проверить MTU интерфейса
ip link show ens192

# Если MTU != 1500, исправить
sudo ip link set ens192 mtu 1500
sudo systemctl restart k3s
```

---

## ⚠️ Проблема 3: kubectl не работает

### Симптомы
```bash
kubectl get nodes
# The connection to the server localhost:8080 was refused
```

### Решения

**1. Kubeconfig не настроен**
```bash
# Установить KUBECONFIG
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Или скопировать в стандартное место
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
```

**2. Использовать k3s kubectl**
```bash
# Всегда работает
sudo k3s kubectl get nodes
```

**3. Права доступа**
```bash
# Исправить права
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
```

---

## 💥 Проблема 4: System pods не стартуют

### Симптомы
```bash
kubectl get pods -A
# coredns-xxx         0/1   CrashLoopBackOff
# traefik-xxx         0/1   Pending
```

### Диагностика
```bash
# Логи проблемного pod
kubectl logs -n kube-system [pod-name]
kubectl describe pod -n kube-system [pod-name]
```

### Решения

**1. CoreDNS проблемы**
```bash
# Проверить что DNS работает на хосте
nslookup google.com

# Проверить /etc/resolv.conf
cat /etc/resolv.conf

# Если проблема с upstream DNS
kubectl edit configmap -n kube-system coredns
# Изменить upstream DNS на 8.8.8.8
```

**2. Traefik проблемы**
```bash
# Проверить что порты 80/443 свободны
sudo netstat -tulpn | grep -E ":80|:443"

# Если порты заняты nginx/apache
sudo systemctl stop nginx apache2
sudo systemctl restart k3s
```

**3. Нехватка ресурсов**
```bash
# Проверить память и CPU
free -h
top

# Если нехватка - увеличить VM ресурсы в vSphere
```

---

## 🌐 Проблема 5: Сетевые проблемы

### Симптомы
```bash
# Pods не могут резолвить DNS
kubectl run test --image=busybox:1.28 --rm -it -- nslookup kubernetes.default
# server can't find kubernetes.default: NXDOMAIN
```

### Решения

**1. Firewall блокирует**
```bash
# Проверить UFW
sudo ufw status

# Открыть необходимые порты
sudo ufw allow 53/udp    # DNS
sudo ufw allow 8472/udp  # Flannel VXLAN
sudo ufw reload
```

**2. Flannel overlay проблемы**
```bash
# Проверить что Flannel использует правильный интерфейс
ip route | grep flannel.1

# Перезапустить сеть
sudo ip link delete flannel.1
sudo systemctl restart k3s
```

**3. NSX-T connectivity**
```bash
# Проверить основную связность
ping 10.246.10.1  # Gateway
ping 8.8.8.8      # Internet

# Проверить что VM в правильном segment
# (это делается в vSphere UI)
```

---

## 💾 Проблема 6: Storage проблемы

### Симптомы
```bash
kubectl get pvc
# test-pvc   Pending   local-path   1Gi
```

### Решения

**1. Local-path provisioner не работает**
```bash
# Проверить pod provisioner
kubectl get pods -n kube-system | grep local-path

# Проверить StorageClass
kubectl get sc
# local-path должен быть (default)

# Если нет, перезапустить k3s
sudo systemctl restart k3s
```

**2. Права доступа к директории**
```bash
# Проверить директорию local-path (обычно /opt/local-path-provisioner)
sudo ls -la /opt/local-path-provisioner/

# Исправить права если нужно
sudo chown -R root:root /opt/local-path-provisioner/
sudo chmod -R 755 /opt/local-path-provisioner/
```

---

## 🔄 Полная переустановка k3s

### Когда нужно
- Множественные критичные проблемы
- Повреждение etcd базы
- Неразрешимые сетевые проблемы

### Процедуре переустановки

```bash
# 1. Остановить k3s
sudo systemctl stop k3s

# 2. Удалить k3s
/usr/local/bin/k3s-uninstall.sh

# 3. Очистить данные
sudo rm -rf /var/lib/rancher/k3s/
sudo rm -rf /etc/rancher/k3s/

# 4. Очистить network interfaces
sudo ip link delete flannel.1 2>/dev/null || true

# 5. Установить заново
curl -sfL https://get.k3s.io | sh -s - server \
  --write-kubeconfig-mode 644 \
  --node-ip 10.246.10.50 \
  --flannel-iface ens192 \
  --node-name k3s-server-01

# 6. Валидация
kubectl get nodes
```

---

## 🛠️ Полезные команды диагностики

### Системная информация
```bash
# Версии
k3s --version
kubectl version

# Статус сервисов
sudo systemctl status k3s
sudo systemctl is-enabled k3s

# Логи
sudo journalctl -u k3s -f                 # Мониторинг логов
sudo journalctl -u k3s -n 100 --no-pager  # Последние 100 строк
```

### Кластерная информация
```bash
# Общая информация
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A

# Детальная диагностика
kubectl describe node k3s-server-01
kubectl top node                          # Требует metrics-server
```

### Сетевая диагностика
```bash
# Интерфейсы
ip addr show
ip route

# Порты
sudo netstat -tulpn | grep k3s
sudo ss -tlnp | grep 6443

# Connectivity
curl -k https://127.0.0.1:6443/version
curl -k https://10.246.10.50:6443/version
```

### Storage диагностика
```bash
# StorageClass и PV
kubectl get sc
kubectl get pv
kubectl get pvc -A

# Local path директория
sudo ls -la /opt/local-path-provisioner/
```

---

## 📞 Когда обращаться за помощью

**Создайте файл диагностики перед обращением:**

```bash
# Создать диагностический отчет
mkdir -p ~/k3s-diagnostics

# Системная информация
sudo systemctl status k3s > ~/k3s-diagnostics/systemctl-status.txt
sudo journalctl -u k3s -n 200 --no-pager > ~/k3s-diagnostics/k3s-logs.txt

# Кластерная информация
kubectl get nodes -o wide > ~/k3s-diagnostics/nodes.txt
kubectl get pods -A > ~/k3s-diagnostics/pods.txt
kubectl cluster-info > ~/k3s-diagnostics/cluster-info.txt

# Сетевая информация
ip addr show > ~/k3s-diagnostics/network-interfaces.txt
ip route > ~/k3s-diagnostics/routes.txt
sudo netstat -tulpn > ~/k3s-diagnostics/ports.txt

# Создать архив
tar -czf ~/k3s-diagnostics-$(date +%Y%m%d-%H%M).tar.gz ~/k3s-diagnostics/

echo "Диагностический архив готов: ~/k3s-diagnostics-$(date +%Y%m%d-%H%M).tar.gz"
```

---

## 🎯 Следующий шаг

После решения проблем переходим к:
**Этап 7:** Подготовка к Agent нодам → `06-prepare-for-agents.md`

**Если все проблемы решены:**
- k3s Server работает стабильно
- Все валидационные проверки пройдены
- node-token сохранен для Agent нод

---

**Создано:** 2025-10-24
**AI-агент:** Server Node Setup Specialist
**Для:** k3s на vSphere проект 🚀
