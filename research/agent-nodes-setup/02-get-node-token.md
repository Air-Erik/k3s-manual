# Получение node-token с k3s Server ноды

> **Этап:** 1.2.2 - Node Token Management
> **Дата:** 2025-10-24
> **Статус:** 🔑 Получение credentials

---

## 📋 Обзор

**Node-token** — это секретный ключ аутентификации, который требуется для присоединения Agent нод к k3s кластеру.

**Важно:** Без правильного node-token Agent нода НЕ сможет присоединиться к кластеру!

### Что нужно знать:
- Token генерируется автоматически при установке k3s Server
- Token одинаков для всех Agent нод одного кластера
- Token хранится в файле на Server ноде
- Token необходимо передать на каждую Agent ноду при установке

---

## 🗂️ Где находится node-token

### Расположение файла на Server ноде:
```bash
/var/lib/rancher/k3s/server/node-token
```

### Права доступа:
```bash
# Владелец: root:root
# Права: 600 (только root может читать)
-rw------- 1 root root 55 Oct 24 10:30 /var/lib/rancher/k3s/server/node-token
```

### Почему именно там:
- `/var/lib/rancher/k3s/` — рабочая директория k3s
- `/server/` — данные специфичные для Server ноды
- `node-token` — файл с токеном для присоединения нод

---

## 🔍 Как получить node-token

### Метод 1: Прямое чтение файла (рекомендуемый)

```bash
# SSH подключение к Server ноде
ssh k8s-admin@10.246.10.50

# Чтение token (требуются права sudo)
sudo cat /var/lib/rancher/k3s/server/node-token
```

**Пример вывода:**
```
K10abcd1234567890::server:1234567890abcdef1234567890abcdef
```

### Метод 2: Через переменную окружения (для скриптов)

```bash
# SSH к Server ноде
ssh k8s-admin@10.246.10.50

# Сохранить в переменную для использования
export NODE_TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)
echo "Token получен: ${NODE_TOKEN}"
```

### Метод 3: Удалённое получение (одной командой)

```bash
# С локальной машины оператора (без SSH сессии)
ssh k8s-admin@10.246.10.50 "sudo cat /var/lib/rancher/k3s/server/node-token"
```

### Метод 4: Через k3s CLI (альтернативный)

```bash
# На Server ноде
sudo k3s server --print-token
# Но этот способ менее надёжен, используйте cat
```

---

## 🔒 Безопасность node-token

### Уровень доступа токена:

**⚠️ КРИТИЧЕСКИ ВАЖНО:** Node-token даёт **полные права** на присоединение нод к кластеру!

```yaml
С node-token можно:
  ✅ Присоединить любое количество Agent нод
  ✅ Получить доступ к внутренней сети кластера
  ✅ Запускать контейнеры на присоединённых нодах

С node-token НЕЛЬЗЯ:
  ❌ Управлять кластером (нет доступа к API как admin)
  ❌ Читать секреты из других namespaces
  ❌ Создавать Server ноды (только Agent)
```

### Правила безопасности:

#### 🔐 Хранение токена:
```bash
# ✅ ПРАВИЛЬНО: Сохранить в безопасном месте
mkdir -p ~/.k3s-credentials
chmod 700 ~/.k3s-credentials
ssh k8s-admin@10.246.10.50 "sudo cat /var/lib/rancher/k3s/server/node-token" > ~/.k3s-credentials/node-token.txt
chmod 600 ~/.k3s-credentials/node-token.txt

# ❌ НЕПРАВИЛЬНО: Не коммитить в git!
echo "node-token" >> .gitignore
```

#### 🚫 Что НЕ делать с токеном:
- ❌ НЕ коммитить в публичные репозитории
- ❌ НЕ передавать в незашифрованном виде
- ❌ НЕ хранить в логах или скриптах
- ❌ НЕ использовать в CI/CD без шифрования

#### ♻️ Ротация токена (при компрометации):
```bash
# На Server ноде (если нужно изменить токен)
sudo systemctl stop k3s
sudo rm /var/lib/rancher/k3s/server/node-token
sudo systemctl start k3s

# Новый токен будет сгенерирован автоматически
sudo cat /var/lib/rancher/k3s/server/node-token
```

---

## 💾 Сохранение токена для использования

### Вариант 1: Локальное сохранение (рекомендуется)

```bash
# Создать директорию для credentials
mkdir -p ~/k3s-credentials
chmod 700 ~/k3s-credentials

# Получить и сохранить токен
ssh k8s-admin@10.246.10.50 "sudo cat /var/lib/rancher/k3s/server/node-token" > ~/k3s-credentials/node-token.txt

# Защитить файл
chmod 600 ~/k3s-credentials/node-token.txt

# Проверить сохранение
echo "Node token сохранён в ~/k3s-credentials/node-token.txt"
cat ~/k3s-credentials/node-token.txt
```

### Вариант 2: Переменная окружения (для сессии)

```bash
# Экспорт в переменную для текущей shell сессии
export K3S_NODE_TOKEN=$(ssh k8s-admin@10.246.10.50 "sudo cat /var/lib/rancher/k3s/server/node-token")

# Проверить
echo "Token загружен: ${K3S_NODE_TOKEN}"

# Использовать в установке Agent
echo "Готов для установки Agent нод с токеном: ${K3S_NODE_TOKEN}"
```

### Вариант 3: Временный файл (для автоматизации)

```bash
# Создать временный файл
TEMP_TOKEN_FILE=$(mktemp /tmp/k3s-token.XXXXXX)
ssh k8s-admin@10.246.10.50 "sudo cat /var/lib/rancher/k3s/server/node-token" > "$TEMP_TOKEN_FILE"

# Использовать в скриптах
TOKEN=$(cat "$TEMP_TOKEN_FILE")

# Очистить после использования
rm "$TEMP_TOKEN_FILE"
```

### Вариант 4: Прямая передача в команду (для простоты)

```bash
# Использование токена напрямую в команде установки Agent
# (будет показано в следующих этапах)

TOKEN=$(ssh k8s-admin@10.246.10.50 "sudo cat /var/lib/rancher/k3s/server/node-token")
curl -sfL https://get.k3s.io | K3S_URL=https://10.246.10.50:6443 K3S_TOKEN="$TOKEN" sh -s - agent
```

---

## ✅ Проверка токена

### Валидация формата токена:

```bash
# Правильный токен имеет формат:
# K10<случайные_символы>::server:<hex_строка>
# Длина: ~55 символов

# Проверить формат
TOKEN=$(cat ~/k3s-credentials/node-token.txt)
if [[ $TOKEN =~ ^K10.*::server:[a-f0-9]{32}$ ]]; then
    echo "✅ Токен имеет правильный формат"
else
    echo "❌ Токен имеет неправильный формат!"
fi
```

### Тест доступности Server API:

```bash
# Убедиться что Server доступен для Agent подключения
curl -k -s --connect-timeout 5 https://10.246.10.50:6443/version

# Ожидаемый ответ (JSON с версией):
# {
#   "major": "1",
#   "minor": "30+",
#   "gitVersion": "v1.30.x-k3s1",
#   ...
# }
```

---

## 📝 Пошаговая инструкция для оператора

### Получение токена (выполнить один раз):

```bash
# Шаг 1: SSH к Server ноде
ssh k8s-admin@10.246.10.50

# Шаг 2: Проверить статус k3s Server
sudo systemctl status k3s
# Должен быть: active (running)

# Шаг 3: Получить токен
sudo cat /var/lib/rancher/k3s/server/node-token

# Шаг 4: Скопировать вывод (пример):
# K107d8f2b4c9e1a6f::server:a1b2c3d4e5f6789012345678901234ab

# Шаг 5: Выйти с Server ноды
exit
```

### Сохранение токена локально:

```bash
# Шаг 1: На локальной машине создать директорию
mkdir -p ~/k3s-credentials && chmod 700 ~/k3s-credentials

# Шаг 2: Получить токен удалённо и сохранить
ssh k8s-admin@10.246.10.50 "sudo cat /var/lib/rancher/k3s/server/node-token" > ~/k3s-credentials/node-token.txt

# Шаг 3: Защитить файл
chmod 600 ~/k3s-credentials/node-token.txt

# Шаг 4: Проверить что токен сохранён
ls -la ~/k3s-credentials/
cat ~/k3s-credentials/node-token.txt
```

### Использование токена (будет в следующих этапах):

```bash
# Загрузить токен в переменную для использования
export K3S_NODE_TOKEN=$(cat ~/k3s-credentials/node-token.txt)
echo "Токен готов: ${K3S_NODE_TOKEN}"

# Теперь можно устанавливать Agent ноды!
```

---

## 🔧 Troubleshooting

### Проблема 1: Файл node-token не найден

**Симптомы:**
```bash
sudo cat /var/lib/rancher/k3s/server/node-token
# cat: /var/lib/rancher/k3s/server/node-token: No such file or directory
```

**Решение:**
```bash
# Проверить что k3s Server установлен и запущен
sudo systemctl status k3s

# Если не запущен - запустить
sudo systemctl start k3s

# Подождать генерации токена (30 сек)
sleep 30
sudo cat /var/lib/rancher/k3s/server/node-token
```

### Проблема 2: Нет прав на чтение файла

**Симптомы:**
```bash
cat /var/lib/rancher/k3s/server/node-token
# cat: /var/lib/rancher/k3s/server/node-token: Permission denied
```

**Решение:**
```bash
# Использовать sudo
sudo cat /var/lib/rancher/k3s/server/node-token

# Или временно изменить права (НЕ рекомендуется в production)
sudo chmod 644 /var/lib/rancher/k3s/server/node-token
cat /var/lib/rancher/k3s/server/node-token
sudo chmod 600 /var/lib/rancher/k3s/server/node-token
```

### Проблема 3: SSH подключение не работает

**Симптомы:**
```bash
ssh k8s-admin@10.246.10.50
# ssh: connect to host 10.246.10.50 port 22: Connection refused
```

**Решение:**
```bash
# Проверить доступность Server ноды
ping 10.246.10.50

# Проверить SSH service на Server ноде (через консоль vSphere)
sudo systemctl status ssh
sudo systemctl start ssh

# Проверить firewall
sudo ufw status
```

---

## 📊 Статус выполнения

После выполнения этого этапа у вас должно быть:

- ✅ **Node-token получен** с Server ноды
- ✅ **Token сохранён локально** в безопасном месте
- ✅ **Формат токена проверен**
- ✅ **Server доступность подтверждена**

**Готовность к следующему этапу:**
```bash
# Проверить что токен готов к использованию
export K3S_NODE_TOKEN=$(cat ~/k3s-credentials/node-token.txt)
echo "Token length: ${#K3S_NODE_TOKEN} symbols"
# Должно быть: ~55 символов

echo "Server API доступен:"
curl -k -s https://10.246.10.50:6443/version | grep gitVersion
# Должно показать версию k3s
```

---

## ➡️ Следующий шаг

**Токен получен! Теперь можно переходить к клонированию VM для Agent нод.**

**Далее:** [03-clone-vms-for-agents.md](./03-clone-vms-for-agents.md)

---

**Node-token — это ключ к вашему k3s кластеру! Берегите его! 🔑**
