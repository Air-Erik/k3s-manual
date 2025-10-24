# Cloud-init манифесты для k3s кластера

> **Дата:** 2025-10-24
> **Цель:** Правильные cloud-init манифесты для vSphere

---

## 🎯 Обзор

Этот документ объясняет **правильное использование** cloud-init манифестов для k3s кластера в vSphere.

### ⚠️ Важно понимать

- **Metadata:** Сеть, hostname, время, локализация
- **User Data:** Пользователи, SSH, команды, пакеты
- **vSphere UI:** Два отдельных поля для заполнения

---

## 📁 Структура манифестов

### Server нода (k3s-server-01)

| Файл | Назначение | vSphere поле |
|------|------------|--------------|
| `server-node-metadata.yaml` | Сеть, hostname, время | **Cloud-init metadata** |
| `server-node-userdata.yaml` | Пользователи, SSH, команды | **Cloud-init user data** |

### Agent нода 1 (k3s-agent-01)

| Файл | Назначение | vSphere поле |
|------|------------|--------------|
| `agent-node-01-metadata.yaml` | Сеть, hostname, время | **Cloud-init metadata** |
| `agent-node-01-userdata.yaml` | Пользователи, SSH, команды | **Cloud-init user data** |

### Agent нода 2 (k3s-agent-02)

| Файл | Назначение | vSphere поле |
|------|------------|--------------|
| `agent-node-02-metadata.yaml` | Сеть, hostname, время | **Cloud-init metadata** |
| `agent-node-02-userdata.yaml` | Пользователи, SSH, команды | **Cloud-init user data** |

---

## 🔧 Использование в vSphere

### Шаг 1: Создание VM Customization Specification

1. **Откройте vSphere Client**
2. **Home** → **Policies and Profiles** → **VM Customization**
3. **Create** → **New Customization Spec**
4. **Name:** `k3s-server-customization` (или `k3s-agent-customization`)

### Шаг 2: Настройка Cloud-init

#### 2.1 Cloud-init metadata

1. **Выберите:** "Use cloud-init"
2. **Cloud-init metadata:** Скопируйте содержимое `*-metadata.yaml`
3. **Проверьте:** Содержит сеть, hostname, время

#### 2.2 Cloud-init user data

1. **Cloud-init user data:** Скопируйте содержимое `*-userdata.yaml`
2. **Проверьте:** Содержит пользователей, SSH, команды

### Шаг 3: Клонирование VM

1. **Выберите Template:** `k3s-ubuntu2404-minimal-template`
2. **Правый клик** → **Clone** → **Clone to Virtual Machine**
3. **Customization:** Выберите созданную спецификацию
4. **Запустите VM**

---

## 📋 Содержимое манифестов

### Metadata (сеть, hostname, время)

```yaml
# Настройка хоста
hostname: k3s-server-01
fqdn: k3s-server-01
manage_etc_hosts: true

# Настройка сети
network:
  version: 2
  renderer: networkd
  ethernets:
    nic0:
      match:
        driver: vmxnet3
      addresses:
        - 10.246.10.50/24
      routes:
        - to: default
          via: 10.246.10.1
      nameservers:
        addresses: [172.17.10.3, 8.8.8.8]

# Настройки времени
timezone: UTC
ntp:
  enabled: true
  servers:
    - 0.pool.ntp.org
    - 1.pool.ntp.org
    - 2.pool.ntp.org
```

### User Data (пользователи, SSH, команды)

```yaml
# Пользователь
users:
  - name: k3s-admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3NN...5+Fi35iKr5qArSLJkj+rcK0Ej19EjA eric@REMOTE-VM

# Настройки SSH
ssh_pwauth: true
chpasswd:
  list: |
    k3s-admin:admin
  expire: false
  encrypted: false

# Минимальные команды
runcmd:
  - mkdir -p /opt/k3s-setup
  - chown k3s-admin:k3s-admin /opt/k3s-setup
  - ufw allow ssh
  - ufw allow 6443/tcp comment 'k3s API Server'
  - ufw --force enable
```

---

## ✅ Преимущества нового подхода

### 🎯 Соответствие vSphere best practices:

1. **Разделение ответственности:** Metadata vs User Data
2. **Простая сеть:** Через metadata, без файлов
3. **Минимальные команды:** Только необходимое для запуска
4. **Правильная структура:** Следует vSphere стандартам

### 🔧 Упрощение:

1. **Меньше файлов:** Только 2 файла на ноду
2. **Проще настройка:** Копируй и вставляй в vSphere UI
3. **Меньше ошибок:** Стандартная структура
4. **Быстрее развёртывание:** Минимальные команды

---

## 🚨 Важные замечания

### ⚠️ SSH ключи:

```yaml
# Замените на реальный SSH ключ:
ssh_authorized_keys:
  - ssh-ed25519 AAAAC3NN...5+Fi35iKr5qArSLJkj+rcK0Ej19EjA eric@REMOTE-VM
```

### ⚠️ Пароли:

```yaml
# Пароль admin для первоначального доступа:
chpasswd:
  list: |
    k3s-admin:admin
  expire: false
  encrypted: false
```

### ⚠️ Сеть:

```yaml
# Убедитесь что IP адреса правильные:
addresses:
  - 10.246.10.50/24  # Server
  - 10.246.10.51/24  # Agent 1
  - 10.246.10.52/24  # Agent 2
```

---

## 🎯 Следующие шаги

1. **Создайте VM Customization Specifications** в vSphere
2. **Скопируйте содержимое** metadata и userdata файлов
3. **Клонируйте VM** из Template с customization
4. **Проверьте** что cloud-init отработал корректно
5. **Установите k3s** на ноды

---

**Создано:** 2025-10-24
**AI-агент:** VM Template Specialist
**Цель:** Правильные cloud-init манифесты для vSphere
