# Создание VM в vSphere для k3s Template

> **Этап:** 0 - VM Template Preparation
> **Статус:** ✅ ГОТОВО
> **Дата:** 2025-10-24
> **Цель:** Пошаговые инструкции создания VM в vSphere UI

---

## 🎯 Обзор

Этот документ содержит **детальные пошаговые инструкции** для создания VM в vSphere UI, которая будет использоваться как Template для k3s кластера.

### ⚠️ Важно для оператора

- **Цель:** Создать минимальную Ubuntu VM для k3s Template
- **НЕ устанавливать:** kubeadm, kubelet, kubectl, containerd, Docker
- **Устанавливать:** Только Ubuntu 24.04 LTS (minimal) + базовые утилиты
- **Результат:** VM готовая к конвертации в Template

---

## 📋 Предварительные требования

### Доступ к vSphere

- **vCenter:** v8.0.3
- **Права:** Создание VM, клонирование, конвертация в Template
- **Сеть:** Доступ к NSX-T segment `k8s-zeon-dev-segment`

### Необходимые данные

- **Datastore:** Любой доступный (оператор выберет)
- **Network:** k8s-zeon-dev-segment (10.246.10.0/24)
- **ISO:** Ubuntu 24.04 LTS Server (minimal)
- **Время:** ~30 минут

---

## 🖥️ Создание VM в vSphere

### Шаг 1: Запуск мастера создания VM

1. **Откройте vSphere Client** (HTML5 или Desktop)
2. **Войдите в vCenter** с правами администратора
3. **Выберите Datacenter** где будет создана VM
4. **Правый клик** на Datacenter → **New Virtual Machine**
5. **Выберите:** "Create a new virtual machine"
6. **Нажмите:** "Next"

### Шаг 2: Настройка имени и папки

1. **Name:** `k3s-ubuntu2404-template-vm`
2. **Folder:** Оставьте по умолчанию (Datacenter)
3. **Нажмите:** "Next"

### Шаг 3: Выбор хоста или кластера

1. **Выберите:** Существующий кластер или хост
2. **Проверьте:** Совместимость с vSphere 8.0
3. **Нажмите:** "Next"

### Шаг 4: Выбор datastore

1. **Выберите:** Любой доступный datastore
2. **Тип:** Thin Provisioned (рекомендуется)
3. **Нажмите:** "Next"

### Шаг 5: Настройка совместимости

1. **VM Version:** ESXi 8.0 и более поздние версии
2. **Нажмите:** "Next"

### Шаг 6: Выбор гостевой ОС

1. **Guest OS Family:** Linux
2. **Guest OS Version:** Ubuntu Linux (64-bit)
3. **Нажмите:** "Next"

### Шаг 7: Настройка ресурсов

#### vCPU настройки

1. **Number of virtual processors:** 2
2. **Number of cores per socket:** 2
3. **Нажмите:** "Next"

#### RAM настройки

1. **Memory:** 4096 MB (4 GB)
2. **Нажмите:** "Next"

#### Диск настройки

1. **New Hard disk:** 40 GB
2. **Disk Provisioning:** Thin Provisioned
3. **Disk Mode:** Independent - Persistent
4. **Нажмите:** "Next"

#### Сеть настройки

1. **Network Adapter 1:**
   - **Network:** k8s-zeon-dev-segment
   - **Adapter Type:** VMXNET 3
   - **Нажмите:** "Next"

### Шаг 8: Дополнительные настройки

#### SCSI Controller

1. **SCSI Controller:** LSI Logic SAS
2. **Нажмите:** "Next"

#### CD/DVD Drive

1. **CD/DVD Drive 1:**
   - **Type:** Datastore ISO file
   - **Browse:** Выберите Ubuntu 24.04 LTS Server ISO
   - **Connect at power on:** ✅ (включено)
   - **Нажмите:** "Next"

### Шаг 9: Готовность к созданию

1. **Проверьте настройки:**
   - Name: k3s-ubuntu2404-template-vm
   - vCPU: 2
   - RAM: 4 GB
   - Disk: 40 GB (Thin)
   - Network: k8s-zeon-dev-segment
   - CD/DVD: Ubuntu 24.04 LTS ISO

2. **Нажмите:** "Finish"

---

## 🚀 Запуск и установка Ubuntu

### Шаг 10: Запуск VM

1. **Выберите созданную VM** в списке
2. **Правый клик** → **Power On**
3. **Дождитесь** загрузки до экрана установки Ubuntu
4. **Откройте Console** (правый клик → Open Console)

### Шаг 11: Установка Ubuntu 24.04 LTS

#### 11.1 Выбор языка и раскладки

1. **Language:** English (или Russian)
2. **Нажмите:** "Continue"

#### 11.2 Тип установки

1. **Installation type:** ✅ "Minimal installation"
2. **✅ НЕ выбирать:** "Install third-party software"
3. **✅ НЕ выбирать:** "Download updates while installing"
4. **Нажмите:** "Continue"

#### 11.3 Настройка диска

1. **Installation type:** "Erase disk and install Ubuntu"
2. **Нажмите:** "Install Now"
3. **Подтвердите:** "Continue" (в диалоге подтверждения)

#### 11.4 Настройка пользователя

1. **Your name:** k8s-admin
2. **Your computer's name:** k3s-template (временно)
3. **Pick a username:** k8s-admin
4. **Password:** admin
5. **Confirm password:** admin
6. **Login:** ✅ "Require my password to log in"
7. **Нажмите:** "Continue"

#### 11.5 Завершение установки

1. **Дождитесь** завершения установки (~10-15 минут)
2. **Нажмите:** "Restart Now"
3. **Дождитесь** перезагрузки

---

## 🔧 Первоначальная настройка ОС

### Шаг 12: Первый вход в систему

1. **Откройте Console** VM
2. **Войдите:** k8s-admin / admin
3. **Проверьте:** Система загрузилась корректно

### Шаг 13: Обновление системы

```bash
# Обновление пакетов
sudo apt update
sudo apt upgrade -y

# Перезагрузка (если требуется)
sudo reboot
```

### Шаг 14: Установка базовых пакетов

```bash
# Установка необходимых пакетов
sudo apt install -y \
    curl \
    wget \
    vim \
    net-tools \
    iputils-ping \
    dnsutils \
    htop \
    tree \
    cloud-init \
    cloud-initramfs-growroot \
    open-vm-tools \
    open-vm-tools-desktop \
    iproute2 \
    bridge-utils

# Проверка установки
which curl wget vim ping nslookup htop tree
```

### Шаг 15: Проверка SSH

```bash
# Проверка SSH статуса
sudo systemctl status ssh

# SSH должен быть уже запущен после установки Ubuntu
# Если SSH не запущен:
sudo systemctl enable ssh
sudo systemctl start ssh

# Проверка портов
sudo netstat -tlnp | grep :22
```

### Шаг 16: Настройка сети (временно)

```bash
# Проверка сетевого интерфейса
ip addr show

# Проверка подключения к интернету
ping -c 3 8.8.8.8

# Проверка DNS
nslookup google.com
```

---

## ✅ Проверки готовности

### Шаг 17: Валидация VM

Выполните следующие проверки:

```bash
# 1. Проверка ОС
cat /etc/os-release
# Должно показать: Ubuntu 24.04 LTS

# 2. Проверка ресурсов
free -h
# RAM: ~3.8 GB доступно

nproc
# vCPU: 2

df -h
# Disk: ~39 GB доступно

# 3. Проверка пакетов
dpkg -l | grep -E "(curl|wget|vim|cloud-init|open-vm-tools)"
# Все пакеты должны быть установлены

# 4. Проверка cloud-init
cloud-init --version
# Должна быть версия cloud-init

# 5. Проверка VMware Tools
vmware-toolbox-cmd --version
# Должна быть версия open-vm-tools

# 6. Проверка сети
ip route
# Должен быть default route

# 7. Проверка SSH
sudo systemctl is-active ssh
# Должен быть: active
```

### Шаг 18: Настройка cloud-init для VMware

```bash
# Настройка cloud-init для VMware vSphere
sudo tee /etc/cloud/cloud.cfg.d/98-datasource.cfg >/dev/null <<'YAML'
datasource_list: [ VMware, OVF, NoCloud, None ]
YAML

# Включение cloud-init сервисов
sudo systemctl unmask cloud-init cloud-init-local cloud-config cloud-final
sudo systemctl enable  cloud-init cloud-init-local cloud-config cloud-final

# Удаление кастомных netplan-файлов для генерации 50-cloud-init.yaml
sudo rm -f /etc/netplan/*.yaml

# Очистка состояния cloud-init для Template
sudo cloud-init clean --logs --machine
sudo rm -rf /var/lib/cloud

# Проверка настройки
cat /etc/cloud/cloud.cfg.d/98-datasource.cfg

# Удалить кастомные netplan-файлы, чтобы cloud-init сгенерировал 50-cloud-init.yaml
sudo rm -f /etc/netplan/*.yaml
```

### Шаг 19: Подготовка к скрипту

```bash
# Создание директории для скриптов
sudo mkdir -p /opt/k3s-setup
sudo chown k8s-admin:k8s-admin /opt/k3s-setup

# Проверка прав
ls -la /opt/k3s-setup
```

---

## 🎯 Следующие шаги

### Что готово:

- ✅ **VM создана** в vSphere
- ✅ **Ubuntu 24.04 LTS** установлен (minimal)
- ✅ **Базовые пакеты** установлены
- ✅ **SSH доступ** работает
- ✅ **Сеть** настроена (временно)

### Что дальше:

1. **Выполнить скрипт подготовки** (Этап 3)
2. **Конвертировать в Template** (Этап 5)
3. **Валидировать Template** (Этап 6)

---

## 🚨 Важные замечания

### ⚠️ НЕ устанавливать:

```bash
# НЕ устанавливать эти пакеты!
sudo apt install kubeadm kubelet kubectl  # ❌ НЕ НУЖНО!
sudo apt install containerd docker.io     # ❌ НЕ НУЖНО!
sudo apt install flannel calico cilium    # ❌ НЕ НУЖНО!
```

### ⚠️ НЕ настраивать:

```bash
# НЕ настраивать эти параметры!
echo 'net.bridge.bridge-nf-call-iptables = 1' >> /etc/sysctl.conf  # ❌ НЕ НУЖНО!
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf                # ❌ НЕ НУЖНО!
```

### ✅ Правильный подход:

- **Минимальная установка** Ubuntu
- **Только базовые пакеты** для работы
- **k3s установит** все необходимые компоненты сам

---

## 📞 Поддержка

### Если что-то пошло не так:

1. **VM не запускается:** Проверьте настройки vCPU/RAM
2. **Сеть не работает:** Проверьте подключение к NSX-T segment
3. **SSH недоступен:** Проверьте настройки firewall
4. **Пакеты не устанавливаются:** Проверьте подключение к интернету

### Команды диагностики:

```bash
# Проверка системы
sudo systemctl status
sudo journalctl -xe

# Проверка сети
ip addr show
ip route
ping 8.8.8.8

# Проверка пакетов
dpkg -l | grep [package-name]
```

---

**Создано:** 2025-10-24
**AI-агент:** VM Template Specialist
**Цель:** Готовая VM для конвертации в k3s Template
