# Клонирование VM для k3s Server Node

> **Этап:** 1.1 - Server Node Setup
> **Цель:** Создание VM для k3s Server из Template
> **Дата:** 2025-10-24

---

## 🎯 Цель этапа

Клонировать VM для k3s Server ноды из готового Template с правильной конфигурацией:
- **IP:** 10.246.10.50
- **Hostname:** k3s-server-01
- **SSH доступ:** готов к работе
- **Firewall:** настроен для k3s

---

## 📋 Требования

**Готовые компоненты:**
- ✅ VM Template: `k3s-ubuntu2404-minimal-template`
- ✅ Cloud-init конфигурации в `manifests/cloud-init/`
- ✅ NSX-T сегмент: `k8s-zeon-dev-segment`

**Параметры Server ноды:**
```yaml
Name: k3s-server-01
IP: 10.246.10.50/24
Gateway: 10.246.10.1
DNS: 172.17.10.3, 8.8.8.8
vCPU: 2
RAM: 4 GB
Disk: 40 GB
Interface: ens192
```

---

## 🔧 Пошаговая инструкция

### Шаг 1: Подготовка cloud-init конфигураций

**1.1. Откройте файлы cloud-init:**
```bash
# На локальной машине
code manifests/cloud-init/server-node-metadata.yaml
code manifests/cloud-init/server-node-userdata.yaml
```

**1.2. Проверьте конфигурацию сети в metadata:**
```yaml
# server-node-metadata.yaml
hostname: k3s-server-01
network:
  version: 2
  ethernets:
    nic0:
      addresses:
        - 10.246.10.50/24  # ← Проверьте IP
      routes:
        - to: default
          via: 10.246.10.1  # ← Проверьте Gateway
      nameservers:
        addresses: [172.17.10.3, 8.8.8.8]  # ← Проверьте DNS
```

**1.3. Проверьте SSH ключ в userdata:**
```yaml
# server-node-userdata.yaml
users:
  - name: k3s-admin
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3NN...  # ← Замените на свой SSH ключ!
```

### Шаг 2: Клонирование VM в vSphere

**2.1. Откройте vSphere Client**
1. Подключитесь к vCenter
2. Перейдите в **Inventory** → **VMs and Templates**
3. Найдите Template: `k3s-ubuntu2404-minimal-template`

**2.2. Запустите клонирование**
1. **Правый клик** на Template → **Clone** → **Clone to Virtual Machine**
2. **Name:** `k3s-server-01`
3. **Folder:** Выберите папку для k3s кластера
4. **Compute Resource:** Выберите кластер/хост
5. **Storage:** Выберите datastore
6. **Next** →

**2.3. Настройка Customization**
1. **Clone options:** ✅ **Customize the guest OS**
2. **Customization method:** **Use the vSphere Client to enter specification**
3. **Next** →

### Шаг 3: Настройка vSphere Customization

**3.1. General Options**
- **Computer name:** `k3s-server-01`
- **Domain:** `zeon.local` (или оставьте пустым)
- **Time zone:** `UTC`

**3.2. Network Configuration**
- **Network adapter 1:**
  - **IP assignment:** **Use static IP address**
  - **IP address:** `10.246.10.50`
  - **Subnet mask:** `255.255.255.0` (/24)
  - **Default gateway:** `10.246.10.1`
  - **Primary DNS:** `172.17.10.3`
  - **Secondary DNS:** `8.8.8.8`

**3.3. Cloud-init Configuration**
⚠️ **Важно:** В vSphere 8.0+ есть отдельные поля для cloud-init

**Cloud-init metadata (скопируйте содержимое server-node-metadata.yaml):**
```yaml
hostname: k3s-server-01
fqdn: k3s-server-01
manage_etc_hosts: true

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

timezone: UTC
ntp:
  enabled: true
  servers:
    - 0.pool.ntp.org
    - 1.pool.ntp.org
```

**Cloud-init user data (скопируйте содержимое server-node-userdata.yaml):**
```yaml
#cloud-config
users:
  - name: k3s-admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    ssh_authorized_keys:
      - ssh-ed25519 [ваш SSH ключ]

ssh_pwauth: true
chpasswd:
  list: |
    k3s-admin:admin
  expire: false
  encrypted: false

runcmd:
  - mkdir -p /opt/k3s-setup
  - chown k3s-admin:k3s-admin /opt/k3s-setup
  - ufw allow ssh
  - ufw allow 6443/tcp comment 'k3s API Server'
  - ufw allow 10250/tcp comment 'kubelet'
  - ufw allow 8472/udp comment 'Flannel VXLAN'
  - ufw --force enable

package_update: false
package_upgrade: false
```

### Шаг 4: Завершение клонирования

**4.1. Проверка конфигурации**
- Просмотрите все настройки
- Убедитесь что IP, DNS, hostname правильные
- **Finish** → запустится процесс клонирования

**4.2. Ожидание завершения**
- Процесс займёт 2-5 минут
- VM появится в inventory как `k3s-server-01`

### Шаг 5: Первый запуск и проверка

**5.1. Запуск VM**
1. **Правый клик** на `k3s-server-01` → **Power On**
2. Откройте **Console** для мониторинга загрузки

**5.2. Проверка cloud-init (в Console)**
```bash
# Первая загрузка займёт 2-3 минуты
# Следите за сообщениями cloud-init в консоли

# В конце должно появиться:
Cloud-init v. XX.X.X finished at [дата/время]. Datasource DataSourceVMware.
```

**5.3. SSH подключение**
Попробуйте подключиться через SSH:
```bash
# С вашей локальной машины
ssh k3s-admin@10.246.10.50

# Или с паролем (если SSH ключ не работает)
ssh k3s-admin@10.246.10.50
# Пароль: admin
```

### Шаг 6: Валидация VM

**6.1. Проверка сети**
```bash
# Внутри VM
ip addr show ens192
# Должен показать: 10.246.10.50/24

ping 10.246.10.1  # Gateway
ping 8.8.8.8      # Internet
nslookup google.com  # DNS
```

**6.2. Проверка hostname**
```bash
hostname
# Должен показать: k3s-server-01

cat /etc/hosts
# Должен содержать: 127.0.0.1 k3s-server-01
```

**6.3. Проверка cloud-init**
```bash
# Проверка статуса cloud-init
sudo cloud-init status
# Должен показать: status: done

# Логи cloud-init (если нужно)
sudo cat /var/log/cloud-init.log
```

**6.4. Проверка firewall**
```bash
sudo ufw status
# Должен показать открытые порты:
# 22/tcp (SSH)
# 6443/tcp (k3s API)
# 10250/tcp (kubelet)
# 8472/udp (Flannel)
```

**6.5. Проверка готовности к k3s**
```bash
# Директория для k3s
ls -la /opt/k3s-setup/
# Должна существовать и принадлежать k3s-admin

# Свободное место
df -h
# Должно быть ~35GB свободно
```

---

## ✅ Критерии успеха

VM готова к установке k3s если:
- ✅ SSH подключение работает
- ✅ IP адрес: 10.246.10.50
- ✅ Hostname: k3s-server-01
- ✅ Ping gateway и internet работает
- ✅ DNS резолюция работает
- ✅ Firewall настроен правильно
- ✅ cloud-init завершился успешно

---

## 🚨 Troubleshooting

### Проблема: SSH не работает

**Решение 1 - SSH ключ:**
```bash
# Проверьте что ваш SSH ключ добавлен в userdata.yaml
ssh-keygen -y -f ~/.ssh/id_ed25519  # Получите публичный ключ
```

**Решение 2 - Пароль:**
```bash
ssh k3s-admin@10.246.10.50
# Пароль: admin
```

### Проблема: IP не назначился

**Диагностика:**
```bash
# В vSphere Console
ip addr show
# Проверьте есть ли IP на ens192
```

**Решение:**
1. Проверьте правильность настроек сети в customization
2. Перезапустите сеть: `sudo netplan apply`
3. Или пересоздайте VM с правильной конфигурацией

### Проблема: cloud-init не отработал

**Диагностика:**
```bash
sudo cloud-init status --long
sudo cat /var/log/cloud-init.log
```

**Решение:**
```bash
# Принудительный запуск cloud-init
sudo cloud-init clean
sudo cloud-init init --local
sudo cloud-init init
sudo cloud-init modules --mode=config
sudo cloud-init modules --mode=final
```

---

## 🎯 Следующий шаг

После успешной валидации VM переходим к:
**Этап 3:** Установка k3s Server → `install-k3s-server.sh`

**Команда для установки:**
```bash
# Скачайте и запустите скрипт установки
curl -o install-k3s-server.sh [URL скрипта]
chmod +x install-k3s-server.sh
./install-k3s-server.sh
```

---

**Создано:** 2025-10-24
**AI-агент:** Server Node Setup Specialist
**Для:** k3s на vSphere проект 🚀
