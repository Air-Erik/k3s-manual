# Клонирование VM для k3s Agent нод

> **Этап:** 1.2.3 - VM Cloning for Agent Nodes
> **Дата:** 2025-10-24
> **Статус:** 🖥️ Создание инфраструктуры

---

## 📋 Обзор

На этом этапе создаём **2 виртуальные машины** для k3s Agent нод путём клонирования из подготовленного Template.

### Что будем делать:
1. **Клонировать Agent Node 1** (k3s-agent-01) с IP 10.246.10.51
2. **Клонировать Agent Node 2** (k3s-agent-02) с IP 10.246.10.52
3. **Применить cloud-init конфигурации** для автоматической настройки
4. **Проверить готовность нод** к установке k3s

### Результат:
- 2 готовые VM с правильными IP адресами и hostname
- SSH доступ к обеим нодам
- Сетевое подключение к Server ноде (10.246.10.50)

---

## 📊 Спецификация Agent нод

### Общие параметры для обеих Agent нод:

```yaml
Template Source: k3s-ubuntu2404-minimal-template
OS: Ubuntu 24.04 LTS (minimal)
vCPU: 2 cores
RAM: 2 GB
Disk: 40 GB
Network: k8s-zeon-dev-segment (NSX-T)
```

### Специфичные параметры:

| Параметр | Agent Node 1 | Agent Node 2 |
|----------|--------------|--------------|
| **VM Name** | `k3s-agent-01` | `k3s-agent-02` |
| **Hostname** | `k3s-agent-01` | `k3s-agent-02` |
| **IP Address** | `10.246.10.51/24` | `10.246.10.52/24` |
| **Gateway** | `10.246.10.1` | `10.246.10.1` |
| **DNS** | `172.17.10.3, 8.8.8.8` | `172.17.10.3, 8.8.8.8` |
| **Cloud-init userdata** | `agent-node-01-userdata.yaml` | `agent-node-02-userdata.yaml` |
| **Cloud-init metadata** | `agent-node-01-metadata.yaml` | `agent-node-02-metadata.yaml` |

---

## 🗂️ Cloud-init конфигурации

### Расположение файлов:

```
manifests/cloud-init/
├── agent-node-01-userdata.yaml    # Основная конфигурация Agent-01
├── agent-node-01-metadata.yaml    # Метаданные сети Agent-01
├── agent-node-02-userdata.yaml    # Основная конфигурация Agent-02
├── agent-node-02-metadata.yaml    # Метаданные сети Agent-02
└── README.md                       # Инструкции по использованию
```

### Что настраивается через cloud-init:

```yaml
В userdata.yaml:
  ✅ Hostname (k3s-agent-01/02)
  ✅ SSH пользователь k8s-admin
  ✅ SSH ключи и пароли
  ✅ Установка необходимых пакетов
  ✅ Timezone и локаль
  ✅ Системные настройки

В metadata.yaml:
  ✅ Статический IP адрес
  ✅ Сетевая маска /24
  ✅ Gateway 10.246.10.1
  ✅ DNS серверы
  ✅ Имя сетевого интерфейса
```

**Примечание:** Cloud-init конфигурации уже подготовлены в проекте! Используйте готовые файлы.

---

## 🔧 Клонирование Agent Node 1 (k3s-agent-01)

### Шаг 1: Запуск мастера клонирования в vSphere

```
1. Открыть vSphere Client
2. Навигация: Datacenter → VMs and Templates
3. Найти: k3s-ubuntu2404-minimal-template
4. ПКМ → Clone → Clone to Virtual Machine...
```

### Шаг 2: Настройка основных параметров

**Select name and folder:**
```
VM Name: k3s-agent-01
Folder: [Ваша папка для k3s VMs]
```

**Select compute resource:**
```
Выбрать: [Целевой ESXi host или Cluster]
Совместимость: ESXi 8.0 and later
```

**Select storage:**
```
Storage Policy: [По умолчанию или ваш policy]
Datastore: [Выбрать подходящий datastore]
```

### Шаг 3: Настройка клонирования

**Select clone options:**
```
☑️ Customize the guest OS
☑️ Power on virtual machine after creation
```

### Шаг 4: Настройка Hardware (опционально)

**Если нужно изменить характеристики:**
```
CPU: 2 vCPU (по умолчанию из Template)
Memory: 2048 MB (по умолчанию из Template)
Hard Disk: 40 GB (по умолчанию из Template)
Network: k8s-zeon-dev-segment (проверить!)
```

### Шаг 5: Применение cloud-init конфигурации

**VM Options → Advanced → Configuration Parameters:**

Добавить следующие параметры:

```
Key: guestinfo.userdata
Value: [содержимое manifests/cloud-init/agent-node-01-userdata.yaml]

Key: guestinfo.userdata.encoding
Value: base64

Key: guestinfo.metadata
Value: [содержимое manifests/cloud-init/agent-node-01-metadata.yaml]

Key: guestinfo.metadata.encoding
Value: base64
```

**Как получить base64 содержимое:**
```bash
# На локальной машине
base64 -w 0 manifests/cloud-init/agent-node-01-userdata.yaml > userdata.b64
base64 -w 0 manifests/cloud-init/agent-node-01-metadata.yaml > metadata.b64

# Скопировать содержимое файлов .b64 в соответствующие поля
```

### Шаг 6: Завершение клонирования

```
1. Нажать "Finish"
2. Дождаться завершения клонирования (~2-3 минуты)
3. VM автоматически запустится (если выбран Power On)
4. Cloud-init применит конфигурацию (~2-3 минуты)
```

### Шаг 7: Первая проверка Agent Node 1

```bash
# Проверить что VM запущена в vSphere
# Status: Powered On

# Попробовать SSH через 3-4 минуты после запуска
ssh k8s-admin@10.246.10.51

# При успешном подключении проверить:
hostname
# Ожидается: k3s-agent-01

ip addr show ens192
# Ожидается: inet 10.246.10.51/24

ping 10.246.10.1
# Ожидается: gateway доступен

ping 10.246.10.50
# Ожидается: Server нода доступна

exit
```

---

## 🔧 Клонирование Agent Node 2 (k3s-agent-02)

### Процесс аналогичный Agent Node 1

**Отличия для Agent Node 2:**

```
VM Name: k3s-agent-02
Cloud-init userdata: agent-node-02-userdata.yaml
Cloud-init metadata: agent-node-02-metadata.yaml
Ожидаемый IP: 10.246.10.52
Ожидаемый hostname: k3s-agent-02
```

### Быстрая инструкция:

```bash
1. ПКМ на Template → Clone → Clone to Virtual Machine
2. Name: k3s-agent-02
3. Select compute/storage resources
4. ☑️ Customize guest OS + ☑️ Power on
5. VM Options → Configuration Parameters:
   - guestinfo.userdata = base64(agent-node-02-userdata.yaml)
   - guestinfo.metadata = base64(agent-node-02-metadata.yaml)
6. Finish
7. Ждать 5-6 минут
8. SSH test: ssh k8s-admin@10.246.10.52
```

### Проверка Agent Node 2:

```bash
ssh k8s-admin@10.246.10.52

# Проверки
hostname          # → k3s-agent-02
ip addr show ens192  # → 10.246.10.52/24
ping 10.246.10.1     # → gateway OK
ping 10.246.10.50    # → server OK

exit
```

---

## ✅ Проверка готовности обеих Agent нод

### Сетевая связность

```bash
# Проверить доступность обеих Agent нод
ping 10.246.10.51    # Agent-01
ping 10.246.10.52    # Agent-02

# SSH доступ к обеим нодам
ssh k8s-admin@10.246.10.51 "hostname && ip addr show ens192 | grep inet"
ssh k8s-admin@10.246.10.52 "hostname && ip addr show ens192 | grep inet"

# Ожидаемый вывод:
# k3s-agent-01
# inet 10.246.10.51/24 brd 10.246.10.255 scope global ens192
#
# k3s-agent-02
# inet 10.246.10.52/24 brd 10.246.10.255 scope global ens192
```

### Подключение к Server ноде

```bash
# С каждой Agent ноды проверить доступность Server
ssh k8s-admin@10.246.10.51 "curl -k -s --connect-timeout 5 https://10.246.10.50:6443/version | head -3"
ssh k8s-admin@10.246.10.52 "curl -k -s --connect-timeout 5 https://10.246.10.50:6443/version | head -3"

# Ожидается JSON ответ с версией k3s
# {
#   "major": "1",
#   "minor": "30+",
```

### Системные требования

```bash
# Проверить ресурсы на Agent нодах
ssh k8s-admin@10.246.10.51 "free -h && df -h /"
ssh k8s-admin@10.246.10.52 "free -h && df -h /"

# Ожидается:
# RAM: ~2GB total
# Disk: ~40GB total, >85% free
```

### Пакеты и готовность к k3s

```bash
# Проверить что необходимые пакеты установлены
ssh k8s-admin@10.246.10.51 "which curl && which systemctl && systemctl is-system-running"
ssh k8s-admin@10.246.10.52 "which curl && which systemctl && systemctl is-system-running"

# Ожидается:
# /usr/bin/curl
# /usr/bin/systemctl
# running (или degraded - это нормально)
```

---

## 🚨 Troubleshooting клонирования

### Проблема 1: VM не запускается после клонирования

**Симптомы:**
- VM в состоянии "Powered Off"
- Или зависает на boot screen

**Решение:**
```bash
1. В vSphere: VM → Actions → Edit Settings
2. Проверить:
   - Hardware Compatibility = ESXi 8.0+
   - Boot Options → Firmware = BIOS (не UEFI)
   - Network Adapter подключён к правильному сегменту
3. Power On заново
```

### Проблема 2: Cloud-init не применяется

**Симптомы:**
- VM запускается но hostname не изменился
- IP остался как в Template (DHCP)
- SSH не работает на новом IP

**Решение:**
```bash
1. Проверить guestinfo параметры в VM settings
2. Убедиться что userdata/metadata в base64
3. Проверить логи cloud-init на VM:
   ssh [old-ip] "sudo cloud-init status"
   ssh [old-ip] "sudo journalctl -u cloud-init"
4. Пересоздать VM с правильными параметрами
```

### Проблема 3: Неправильный IP адрес

**Симптомы:**
- VM получает IP через DHCP вместо статического
- IP не соответствует ожидаемому (.51 или .52)

**Решение:**
```bash
1. SSH к VM по DHCP IP (найти в vSphere console)
2. Проверить cloud-init metadata:
   sudo cat /var/lib/cloud/instance/cloud-config.txt
3. Если metadata неправильная - пересоздать VM
4. Если правильная - применить вручную:
   sudo netplan apply
```

### Проблема 4: SSH подключение отклоняется

**Симптомы:**
```bash
ssh k8s-admin@10.246.10.51
# ssh: connect to host 10.246.10.51 port 22: Connection refused
```

**Решение:**
```bash
1. Проверить VM доступен:
   ping 10.246.10.51

2. Подключиться через vSphere console
3. Проверить SSH service:
   sudo systemctl status ssh
   sudo systemctl start ssh

4. Проверить firewall:
   sudo ufw status
   sudo ufw allow ssh
```

### Проблема 5: Template не найден

**Симптомы:**
- Template `k3s-ubuntu2404-minimal-template` отсутствует в vSphere

**Решение:**
```bash
1. Убедиться что Этап 0 (VM Template preparation) выполнен
2. Проверить в другой папке vSphere
3. Если Template отсутствует - выполнить подготовку Template сначала
4. Использовать альтернативный Ubuntu 24.04 template если есть
```

---

## 📋 Чек-лист готовности Agent нод

После клонирования обе Agent ноды должны соответствовать:

### Agent Node 1 (k3s-agent-01):
- [ ] VM создана и запущена в vSphere
- [ ] Hostname = k3s-agent-01
- [ ] IP адрес = 10.246.10.51/24
- [ ] SSH доступ работает: `ssh k8s-admin@10.246.10.51`
- [ ] Gateway доступен: `ping 10.246.10.1`
- [ ] Server нода доступна: `ping 10.246.10.50`
- [ ] k3s API доступен: `curl -k https://10.246.10.50:6443/version`

### Agent Node 2 (k3s-agent-02):
- [ ] VM создана и запущена в vSphere
- [ ] Hostname = k3s-agent-02
- [ ] IP адрес = 10.246.10.52/24
- [ ] SSH доступ работает: `ssh k8s-admin@10.246.10.52`
- [ ] Gateway доступен: `ping 10.246.10.1`
- [ ] Server нода доступна: `ping 10.246.10.50`
- [ ] k3s API доступен: `curl -k https://10.246.10.50:6443/version`

### Общие требования:
- [ ] Обе ноды видят друг друга: взаимный ping между .51 и .52
- [ ] На обеих нодах установлены curl, systemctl, базовые пакеты
- [ ] Достаточно свободного места: >30GB на диске
- [ ] Достаточно RAM: ~2GB доступной памяти
- [ ] Интернет доступен: `ping 8.8.8.8`

---

## 📊 Время выполнения

| Операция | Agent Node 1 | Agent Node 2 | Итого |
|----------|--------------|--------------|-------|
| Подготовка cloud-init | 2 мин | 1 мин | 3 мин |
| Клонирование VM | 3 мин | 3 мин | 6 мин |
| Boot + cloud-init | 4 мин | 4 мин | 8 мин |
| Валидация готовности | 2 мин | 1 мин | 3 мин |
| **ИТОГО** | **11 мин** | **9 мин** | **~20 мин** |

---

## ➡️ Следующий шаг

**✅ VM для Agent нод готовы!**

**Имеем:**
- k3s-server-01 (10.246.10.50) — работает ✅
- k3s-agent-01 (10.246.10.51) — готов к установке k3s ✅
- k3s-agent-02 (10.246.10.52) — готов к установке k3s ✅
- Node-token получен ✅

**Далее:** [04-installation-steps.md](./04-installation-steps.md) — установка k3s agent на обеих нодах

---

**Инфраструктура готова! Теперь присоединяем Agent ноды к кластеру! 🚀**
