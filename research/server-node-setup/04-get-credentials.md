# Получение credentials для k3s кластера

> **Этап:** 1.1 - Server Node Setup
> **Цель:** Получение kubeconfig и node-token
> **Дата:** 2025-10-24

---

## 🎯 Что такое credentials в k3s?

После установки k3s Server создаются два важных файла:
1. **kubeconfig** - для доступа к Kubernetes API
2. **node-token** - для присоединения Agent нод

**Важно:** Эти файлы нужны для управления кластером и расширения!

**Предварительные условия:**
- ✅ k3s Server установлен (`03-install-k3s-server.md`)
- ✅ k3s сервис работает: `sudo systemctl status k3s`
- ✅ API Server отвечает: `kubectl get nodes`

---

## 🔑 kubeconfig - доступ к Kubernetes API

### Где находится kubeconfig

```bash
# Основной файл (создается автоматически)
/etc/rancher/k3s/k3s.yaml
```

### Получение kubeconfig

**Метод 1: Просмотр содержимого**
```bash
# Показать содержимое kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml
```

**Метод 2: Копирование для текущего пользователя**
```bash
# Создать стандартную директорию kubectl
mkdir -p ~/.kube

# Скопировать kubeconfig
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

# Изменить владельца файла
sudo chown $(id -u):$(id -g) ~/.kube/config

# Проверить что kubectl работает
kubectl get nodes
```

**Метод 3: Сохранение в отдельную директорию**
```bash
# Создать директорию для k3s credentials
mkdir -p ~/k3s-credentials

# Скопировать kubeconfig
sudo cp /etc/rancher/k3s/k3s.yaml ~/k3s-credentials/kubeconfig.yaml
sudo chown $(id -u):$(id -g) ~/k3s-credentials/kubeconfig.yaml

# Использовать с переменной окружения
export KUBECONFIG=~/k3s-credentials/kubeconfig.yaml
kubectl get nodes
```

### Структура kubeconfig

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: [base64 данные]
    server: https://127.0.0.1:6443  # ← Локальный адрес!
  name: default
contexts:
- context:
    cluster: default
    user: default
  name: default
current-context: default
kind: Config
users:
- name: default
  user:
    client-certificate-data: [base64 данные]
    client-key-data: [base64 данные]
```

### Настройка для удаленного доступа

**⚠️ Важно:** По умолчанию kubeconfig настроен для локального использования (`127.0.0.1:6443`)

**Для удаленного доступа:**
```bash
# 1. Скопировать kubeconfig на локальную машину
scp k3s-admin@10.246.10.50:~/k3s-credentials/kubeconfig.yaml ~/k3s-kubeconfig.yaml

# 2. Изменить server URL в файле
sed -i 's/127.0.0.1:6443/10.246.10.50:6443/' ~/k3s-kubeconfig.yaml

# 3. Использовать
export KUBECONFIG=~/k3s-kubeconfig.yaml
kubectl get nodes
```

---

## 🎫 node-token - для Agent нод

### Где находится node-token

```bash
# Основной файл (создается при инициализации сервера)
/var/lib/rancher/k3s/server/node-token
```

### Получение node-token

```bash
# Просмотр token
sudo cat /var/lib/rancher/k3s/server/node-token

# Пример вывода:
# K10a8f5c4d2e1f7b9a3c6d8e2f4g7h1i5j9k3l7m1n5o9p3q7r1s5t9u3v7w1x5y9z3
```

### Сохранение node-token

```bash
# Сохранить в файл
sudo cat /var/lib/rancher/k3s/server/node-token > ~/k3s-credentials/node-token.txt

# Проверить содержимое
cat ~/k3s-credentials/node-token.txt
```

### Использование node-token

**Для присоединения Agent нод используется команда:**
```bash
# На Agent ноде
curl -sfL https://get.k3s.io | K3S_URL=https://10.246.10.50:6443 K3S_TOKEN=[ваш-token] sh -
```

---

## 📁 Структура директории credentials

После выполнения всех команд у вас должна быть:

```bash
~/k3s-credentials/
├── kubeconfig.yaml           # Для доступа к API
├── node-token.txt           # Для Agent нод
└── cluster-info.txt         # Сводная информация
```

### Создание сводного файла

```bash
# Создать файл с информацией о кластере
cat > ~/k3s-credentials/cluster-info.txt << EOF
# k3s Cluster Information
# Дата создания: $(date)

# Server Node
Server URL: https://10.246.10.50:6443
Node Name: k3s-server-01
Node IP: 10.246.10.50

# Для Agent нод
Server: https://10.246.10.50:6443
Token: $(cat ~/k3s-credentials/node-token.txt)

# Файлы
kubeconfig: ~/k3s-credentials/kubeconfig.yaml
node-token: ~/k3s-credentials/node-token.txt

# Команды для Agent нод
curl -sfL https://get.k3s.io | K3S_URL=https://10.246.10.50:6443 K3S_TOKEN=$(cat ~/k3s-credentials/node-token.txt) sh -
EOF

# Показать содержимое
cat ~/k3s-credentials/cluster-info.txt
```

---

## ✅ Проверка credentials

### Проверка kubeconfig

```bash
# Проверка подключения к API
kubectl get nodes

# Ожидаемый вывод:
# NAME             STATUS   ROLES                  AGE   VERSION
# k3s-server-01    Ready    control-plane,master   5m    v1.30.x+k3s1

# Проверка системных pods
kubectl get pods -A

# Должны быть Running:
# kube-system   coredns-xxx
# kube-system   traefik-xxx
# kube-system   local-path-provisioner-xxx
# kube-system   metrics-server-xxx (опционально)
```

### Проверка node-token

```bash
# Проверка что token существует и не пустой
if [ -s ~/k3s-credentials/node-token.txt ]; then
    echo "✅ Node token сохранен"
    echo "Token length: $(wc -c < ~/k3s-credentials/node-token.txt) characters"
else
    echo "❌ Node token не найден или пустой"
fi

# Показать часть token (для безопасности)
echo "Token preview: $(cat ~/k3s-credentials/node-token.txt | cut -c1-20)..."
```

---

## 🔐 Безопасность credentials

### Важные моменты

1. **kubeconfig** содержит TLS сертификаты - храните безопасно!
2. **node-token** позволяет присоединять новые ноды - не делитесь!
3. Оба файла дают **полный доступ** к кластеру

### Рекомендуемые права доступа

```bash
# Установить правильные права
chmod 600 ~/k3s-credentials/kubeconfig.yaml
chmod 600 ~/k3s-credentials/node-token.txt
chmod 644 ~/k3s-credentials/cluster-info.txt

# Проверить права
ls -la ~/k3s-credentials/
# Должно показать:
# -rw-------  kubeconfig.yaml
# -rw-------  node-token.txt
# -rw-r--r--  cluster-info.txt
```

### Backup credentials

```bash
# Создать backup архив
tar -czf ~/k3s-credentials-backup-$(date +%Y%m%d).tar.gz -C ~ k3s-credentials/

# Или отправить на другую машину
scp ~/k3s-credentials/* user@backup-server:~/k3s-backups/
```

---

## 🚨 Troubleshooting

### Проблема: kubectl не работает

**Симптомы:**
```bash
kubectl get nodes
# The connection to the server localhost:8080 was refused
```

**Решение:**
```bash
# Убедитесь что KUBECONFIG настроен
export KUBECONFIG=~/.kube/config

# Или используйте k3s kubectl
sudo k3s kubectl get nodes
```

### Проблема: Permission denied для kubeconfig

**Симптомы:**
```bash
kubectl get nodes
# error: open ~/.kube/config: permission denied
```

**Решение:**
```bash
# Исправить права владельца
sudo chown $(id -u):$(id -g) ~/.kube/config
chmod 600 ~/.kube/config
```

### Проблема: Не могу найти node-token

**Симптомы:**
```bash
sudo cat /var/lib/rancher/k3s/server/node-token
# No such file or directory
```

**Решение:**
```bash
# Проверить что k3s server работает
sudo systemctl status k3s

# Подождать инициализации (может занять до 2 минут)
# Или перезапустить k3s
sudo systemctl restart k3s
```

### Проблема: Удаленное подключение не работает

**Симптомы:**
```bash
kubectl get nodes
# Unable to connect to the server: dial tcp 10.246.10.50:6443: connect: connection refused
```

**Решение:**
```bash
# На сервере проверить что API Server слушает на всех интерфейсах
sudo netstat -tulpn | grep 6443

# Проверить firewall
sudo ufw status | grep 6443

# Если нужно, открыть порт
sudo ufw allow 6443/tcp
```

---

## 🎯 Следующий шаг

После получения credentials переходим к:
**Этап 5:** Валидация установки → `05-validate-installation.md`

**Команды для проверки:**
```bash
# Базовая проверка
kubectl get nodes
kubectl get pods -A

# Детальная валидация
./validate-k3s-server.sh
```

---

**Создано:** 2025-10-24
**AI-агент:** Server Node Setup Specialist
**Для:** k3s на vSphere проект 🚀
