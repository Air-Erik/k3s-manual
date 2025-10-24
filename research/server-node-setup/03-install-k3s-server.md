# Установка k3s Server на клонированную VM

> **Этап:** 1.1 - Server Node Setup
> **Цель:** Установка k3s Server на подготовленную VM
> **Дата:** 2025-10-24

---

## 🎯 Цель этапа

После клонирования VM из Template и успешной проверки cloud-init, нужно установить k3s Server.

**Предварительные условия:**
- ✅ VM клонирована из Template (`02-clone-vm-for-server.md`)
- ✅ SSH подключение работает (`ssh k3s-admin@10.246.10.50`)
- ✅ Сеть настроена правильно
- ✅ cloud-init отработал успешно

---

## 📋 Что будет установлено?

**k3s Server включает:**
- **Kubernetes API Server** на порту 6443
- **etcd** база данных (встроенная)
- **kubelet** для запуска pods на Server ноде
- **Встроенные компоненты:**
  - Traefik (Ingress Controller)
  - ServiceLB (Load Balancer)
  - Local-path (Storage)
  - CoreDNS (DNS)
  - Flannel (CNI)

**Результат:** Полнофункциональный Kubernetes кластер одной командой!

---

## 🔧 Способы установки

### Способ 1: Автоматическая установка (рекомендуется)

**Используем готовый скрипт `install-k3s-server.sh`**

### Способ 2: Ручная установка

**Выполняем команды пошагово для понимания процесса**

---

## 🚀 Способ 1: Автоматическая установка

### Шаг 1: Подключение к VM

```bash
# С вашей локальной машины подключитесь к Server VM
ssh k3s-admin@10.246.10.50

# Если SSH ключ не работает, используйте пароль
ssh k3s-admin@10.246.10.50
# Пароль: admin
```

### Шаг 2: Скачивание скрипта установки

```bash
# На Server VM скачайте скрипт установки
# Вариант 1: Если скрипт в репозитории доступен по URL
curl -o install-k3s-server.sh https://raw.githubusercontent.com/[ваш-repo]/k3s-manual/main/scripts/install-k3s-server.sh

# Вариант 2: Если скрипт на локальной машине - скопируйте через scp
# На локальной машине:
# scp scripts/install-k3s-server.sh k3s-admin@10.246.10.50:~/

# Вариант 3: Создайте файл вручную (если нужно)
nano install-k3s-server.sh
# Скопируйте содержимое из scripts/install-k3s-server.sh
```

### Шаг 3: Запуск установки

```bash
# На Server VM сделайте скрипт исполняемым
chmod +x install-k3s-server.sh

# Запустите установку (НЕ под sudo!)
./install-k3s-server.sh
```

### Шаг 4: Мониторинг установки

**Скрипт выполнит 6 этапов:**

```
[1/6] Проверка prerequisites...
✅ sudo права проверены
✅ Интерфейс ens192 найден
✅ IP адрес: 10.246.10.50
✅ Интернет доступен
✅ DNS работает
✅ Свободное место: достаточно
✅ Порт 6443 свободен

[2/6] Установка k3s server...
📥 Скачивание k3s...
🔧 Установка бинарника...
⚙️  Создание systemd сервиса...

[3/6] Ожидание запуска k3s...
⏳ k3s сервис запускается...
✅ k3s сервис запущен
✅ API Server доступен

[4/6] Настройка kubeconfig...
📁 Создание ~/k3s-credentials/
📄 Копирование kubeconfig
✅ kubectl настроен

[5/6] Сохранение node-token...
🔑 node-token сохранен для Agent нод

[6/6] Базовая валидация...
✅ Нода в состоянии Ready
✅ Системные pods запущены
✅ API Server отвечает

🎉 k3s Server успешно установлен!
```

**Время установки: 3-5 минут**

### Шаг 5: Проверка результата

```bash
# Проверка что все работает
kubectl get nodes
# k3s-server-01   Ready   control-plane,master   2m   v1.30.x+k3s1

kubectl get pods -A
# Все pods должны быть Running

curl -k https://10.246.10.50:6443/version
# Должен вернуть JSON с версией Kubernetes
```

---

## 🛠️ Способ 2: Ручная установка (для понимания)

### Шаг 1: Подключение к VM

```bash
ssh k3s-admin@10.246.10.50
```

### Шаг 2: Проверка готовности

```bash
# Проверка сети
ip addr show ens192
ping 10.246.10.1
ping 8.8.8.8

# Проверка свободного места
df -h
# Должно быть минимум 2GB свободно

# Проверка что порт 6443 свободен
sudo netstat -tulpn | grep 6443
# Вывод должен быть пустым
```

### Шаг 3: Установка k3s одной командой

```bash
# Основная команда установки k3s Server
curl -sfL https://get.k3s.io | sh -s - server \
  --write-kubeconfig-mode 644 \
  --node-ip 10.246.10.50 \
  --flannel-iface ens192 \
  --node-name k3s-server-01
```

**Объяснение параметров:**
- `server` - режим установки (Server vs Agent)
- `--write-kubeconfig-mode 644` - права доступа к kubeconfig (без sudo)
- `--node-ip 10.246.10.50` - IP адрес ноды для кластера
- `--flannel-iface ens192` - сетевой интерфейс для Flannel CNI
- `--node-name k3s-server-01` - имя ноды в кластере

### Шаг 4: Проверка установки

```bash
# Проверка systemd сервиса
sudo systemctl status k3s
# Должен быть: active (running)

# Проверка что kubectl работает
sudo k3s kubectl get nodes
# k3s-server-01   Ready   control-plane,master   1m

# Проверка системных pods
sudo k3s kubectl get pods -A
# Все pods должны быть Running
```

### Шаг 5: Настройка kubectl для пользователя

```bash
# Создание директории для credentials
mkdir -p ~/k3s-credentials
mkdir -p ~/.kube

# Копирование kubeconfig
sudo cp /etc/rancher/k3s/k3s.yaml ~/k3s-credentials/kubeconfig.yaml
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

# Изменение владельца
sudo chown $(id -u):$(id -g) ~/k3s-credentials/kubeconfig.yaml
sudo chown $(id -u):$(id -g) ~/.kube/config

# Проверка что kubectl работает без sudo
kubectl get nodes
```

### Шаг 6: Сохранение node-token

```bash
# Сохранение токена для Agent нод
sudo cat /var/lib/rancher/k3s/server/node-token > ~/k3s-credentials/node-token.txt

# Создание информационного файла
cat > ~/k3s-credentials/cluster-info.txt << EOF
# k3s Cluster Information
Server URL: https://10.246.10.50:6443
Node Token: $(cat ~/k3s-credentials/node-token.txt)
Node Name: k3s-server-01

# Команда для Agent нод:
curl -sfL https://get.k3s.io | K3S_URL=https://10.246.10.50:6443 K3S_TOKEN=$(cat ~/k3s-credentials/node-token.txt) sh -
EOF
```

---

## ✅ Критерии успеха

k3s Server установлен успешно если:

### Базовые проверки
- ✅ `sudo systemctl status k3s` показывает active (running)
- ✅ `kubectl get nodes` показывает 1 ноду в Ready
- ✅ `kubectl get pods -A` показывает все pods Running
- ✅ `curl -k https://10.246.10.50:6443/version` возвращает JSON

### Файлы созданы
- ✅ `~/k3s-credentials/kubeconfig.yaml` существует
- ✅ `~/k3s-credentials/node-token.txt` существует
- ✅ `~/.kube/config` настроен для kubectl

### Системные компоненты
- ✅ CoreDNS pod Running
- ✅ Traefik pod Running
- ✅ Local-path provisioner Running
- ✅ Flannel интерфейс создан

---

## 🚨 Troubleshooting установки

### Проблема: "Нет доступа к интернету"

```bash
# Проверка
ping 8.8.8.8
curl -I https://get.k3s.io

# Решение: проверить DNS и gateway
cat /etc/netplan/*.yaml
sudo netplan apply
```

### Проблема: "Порт 6443 занят"

```bash
# Проверка
sudo netstat -tulpn | grep 6443

# Решение: остановить процесс или использовать другой порт
sudo pkill -f k3s
```

### Проблема: k3s service не стартует

```bash
# Диагностика
sudo journalctl -u k3s -n 50

# Частые причины:
# 1. Недостаток памяти - увеличить RAM VM
# 2. DNS проблемы - проверить /etc/resolv.conf
# 3. Firewall - проверить ufw status
```

### Проблема: kubectl не работает

```bash
# Проверка KUBECONFIG
echo $KUBECONFIG
ls -la ~/.kube/config

# Решение
export KUBECONFIG=~/.kube/config
# или
sudo k3s kubectl get nodes
```

---

## 🔄 Переустановка k3s (если нужно)

```bash
# Остановка k3s
sudo systemctl stop k3s

# Удаление k3s
/usr/local/bin/k3s-uninstall.sh

# Очистка данных
sudo rm -rf /var/lib/rancher/k3s/
sudo rm -rf /etc/rancher/k3s/

# Установка заново
curl -sfL https://get.k3s.io | sh -s - server \
  --write-kubeconfig-mode 644 \
  --node-ip 10.246.10.50 \
  --flannel-iface ens192 \
  --node-name k3s-server-01
```

---

## 📊 Что происходит под капотом?

### Файлы k3s после установки

```bash
# Основные файлы
/usr/local/bin/k3s                    # Главный бинарник
/usr/local/bin/kubectl -> k3s         # kubectl = symlink
/etc/systemd/system/k3s.service       # systemd сервис
/etc/rancher/k3s/k3s.yaml            # kubeconfig
/var/lib/rancher/k3s/server/          # Данные сервера
├── db/                               # etcd база
├── tls/                             # TLS сертификаты
├── manifests/                       # Встроенные компоненты
└── node-token                       # Token для Agent нод
```

### Сетевые интерфейсы

```bash
# После установки появляется flannel интерфейс
ip addr show flannel.1
# flannel.1: inet 10.42.0.0/32 scope global flannel.1
```

### Процессы

```bash
# k3s запускается как один процесс
ps aux | grep k3s
# k3s server --write-kubeconfig-mode 644 --node-ip 10.246.10.50 ...
```

---

## 🎯 Следующий шаг

После успешной установки k3s Server переходим к:

**Этап 4:** Получение credentials → `04-get-credentials.md`

**Важная информация для следующих этапов:**
- Server URL: `https://10.246.10.50:6443`
- kubeconfig: `~/k3s-credentials/kubeconfig.yaml`
- node-token: `~/k3s-credentials/node-token.txt`

---

**Создано:** 2025-10-24
**AI-агент:** Server Node Setup Specialist
**Для:** k3s на vSphere проект 🚀

**Извините за пропуск этого критически важного этапа!** 😔
