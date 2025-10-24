# Задание для AI-агента: Подготовка VM Template для k3s

> **Этап:** 0 - VM Template Preparation
> **Ответственный:** AI-агент + Оператор
> **Статус:** 🚀 В работе
> **Дата создания:** 2025-10-24

---

## 📋 Контекст

Ты AI-агент, работающий над проектом **k3s на VMware vSphere с NSX-T**.

### Что уже готово:
- ✅ **NSX-T инфраструктура:** Segment `k8s-zeon-dev-segment` (10.246.10.0/24)
- ✅ **T1 Gateway:** `T1-k8s-zeon-dev` с NAT и маршрутизацией
- ✅ **IP-план:** 10.246.10.50 (Server), 10.246.10.51-52 (Agents)
- ✅ **vSphere:** v8.0.3, доступ к vCenter есть
- ✅ **Документация проекта:** Полный план и архитектура

### Что НЕТ (твоя задача):
- ❌ **VM Template для k3s** — нужно создать с нуля!

---

## 🎯 Цель проекта

Создать **minimal VM Template** для развёртывания k3s кластера на VMware vSphere.

### ⚠️ КРИТИЧЕСКИ ВАЖНО: Отличие от Kubernetes Template

**НЕ используй подход из "полного" Kubernetes проекта!**

❌ **k8s Template содержал:**
- kubeadm, kubelet, kubectl (предустановлены)
- containerd (настроен заранее)
- sysctl настройки для K8s
- Swap отключен
- Модули ядра загружены

✅ **k3s Template должен содержать:**
- **ТОЛЬКО** Ubuntu 24.04 LTS (minimal install)
- Базовые утилиты (curl, wget, vim, net-tools)
- Cloud-init для автоконфигурации
- open-vm-tools для vSphere интеграции
- **БЕЗ** kubeadm, kubelet, kubectl
- **БЕЗ** containerd (k3s установит свой встроенный!)
- **БЕЗ** K8s-специфичных настроек

**Почему:** k3s — это единый бинарник, который устанавливается одной командой и содержит все необходимые компоненты (включая containerd). Предустановка K8s компонентов будет **конфликтовать** с k3s!

---

## 🔧 Твоя роль как AI-агента

Ты эксперт по подготовке VM Template для k3s. Твоя задача:

1. **Создать пошаговые инструкции** для оператора по созданию minimal Ubuntu VM в vSphere
2. **Написать скрипт подготовки VM** перед конвертацией в Template
3. **Создать cloud-init конфигурации** для автоматизации настройки k3s нод
4. **Подготовить процедуры валидации** Template
5. **Документировать troubleshooting** типичных проблем

**Важно:** Все инструкции и скрипты должны быть **готовы к использованию** без изменений!

---

## 📊 Исходные данные инфраструктуры

### vSphere Environment:
- **vSphere/vCenter:** v8.0.3
- **Datastore:** Любой (оператор разместит где нужно)
- **Network:** NSX-T Segment `k8s-zeon-dev-segment`

### Требования к VM Template:
```yaml
Name: k3s-ubuntu2404-minimal-template
OS: Ubuntu 24.04 LTS Server (minimal)
vCPU: 2
RAM: 4 GB (для Server node)
Disk: 40 GB (thin provisioned)
Network: 1 NIC (будет подключен к k8s-zeon-dev-segment)
```

### Network Configuration:
```yaml
DNS Server: 172.17.10.3
Gateway: 10.246.10.1
IP Range для k3s нод: 10.246.10.50-60
Domain: нет (пока)
```

### SSH Access:
```yaml
User: k8s-admin
Password: admin (для первоначальной настройки)
SSH: Будет доступен после создания VM
```

### Планируемые k3s ноды:
```yaml
Server Node:
  - IP: 10.246.10.50
  - Hostname: k3s-server-01
  - RAM: 4 GB, vCPU: 2

Agent Node 1:
  - IP: 10.246.10.51
  - Hostname: k3s-agent-01
  - RAM: 2 GB, vCPU: 2

Agent Node 2:
  - IP: 10.246.10.52
  - Hostname: k3s-agent-02
  - RAM: 2 GB, vCPU: 2
```

---

## 📝 Структура задания

Создай следующие артефакты **последовательно**, объясняя каждый шаг оператору.

### Этап 1: Документация требований к VM

**Создай:** `research/vm-template-prep/01-vm-requirements.md`

**Содержание:**
- Точные требования к VM (vCPU, RAM, Disk)
- Список необходимых пакетов для установки
- Список пакетов которые НЕ нужно устанавливать
- Требования к настройке Ubuntu

**Цель:** Оператор должен понимать что именно создавать в vSphere.

---

### Этап 2: Пошаговые инструкции создания VM

**Создай:** `research/vm-template-prep/02-create-vm-in-vsphere.md`

**Содержание:**
- Пошаговая инструкция создания VM в vSphere UI
- Настройки VM (vCPU, RAM, Disk, Network)
- Установка Ubuntu 24.04 LTS (minimal)
- Первоначальная настройка ОС после установки
- SSH подключение к VM

**Формат:** Скриншоты не нужны, но детальные текстовые инструкции с указанием каждого клика.

---

### Этап 3: Скрипт подготовки VM

**Создай:** `scripts/prepare-vm-template.sh`

**Содержание:**
- Обновление системы (apt update && apt upgrade)
- Установка необходимых пакетов (curl, wget, vim, net-tools, cloud-init, open-vm-tools)
- Настройка cloud-init
- Очистка системы (логи, history, SSH keys, machine-id)
- Подготовка к конвертации в Template

**Требования:**
- Скрипт должен быть **idempotent** (можно запускать несколько раз)
- Обработка ошибок (set -e)
- Логирование действий (echo с описанием)
- Проверки успешности команд
- Комментарии на русском языке

**Пример структуры:**
```bash
#!/bin/bash
# Скрипт подготовки VM Template для k3s
# Дата: 2025-10-24

set -e  # Выход при ошибке

echo "=== Начало подготовки VM Template для k3s ==="

# 1. Обновление системы
echo "[1/6] Обновление системы..."
sudo apt update && sudo apt upgrade -y

# 2. Установка пакетов
echo "[2/6] Установка необходимых пакетов..."
# ...

# и т.д.
```

---

### Этап 4: Cloud-init конфигурации

**Создай:** `manifests/cloud-init/`

Три файла cloud-init для каждой ноды:

#### 4.1. `manifests/cloud-init/server-node.yaml`
Cloud-init для Server ноды (10.246.10.50)

#### 4.2. `manifests/cloud-init/agent-node-01.yaml`
Cloud-init для Agent ноды 1 (10.246.10.51)

#### 4.3. `manifests/cloud-init/agent-node-02.yaml`
Cloud-init для Agent ноды 2 (10.246.10.52)

**Каждый cloud-init должен содержать:**
```yaml
#cloud-config
# Настройка [название ноды]

hostname: [hostname]
fqdn: [hostname]

# Пользователь
users:
  - name: k8s-admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: [хэш пароля 'admin']

# Статический IP
write_files:
  - path: /etc/netplan/01-static-ip.yaml
    content: |
      network:
        version: 2
        ethernets:
          ens192:
            addresses: [IP/24]
            routes:
              - to: default
                via: 10.246.10.1
            nameservers:
              addresses: [172.17.10.3]

# Команды после первого boot
runcmd:
  - netplan apply
  - systemctl restart systemd-networkd
```

**Важно:**
- Использовать `routes:` вместо устаревшего `gateway4:`
- Пароль должен быть хэширован (`mkpasswd --method=SHA-512`)
- Проверить синтаксис YAML

---

### Этап 5: Процедура конвертации в Template

**Создай:** `research/vm-template-prep/03-convert-to-template.md`

**Содержание:**
- Финальные проверки перед конвертацией
- Команды очистки (выполнить вручную или через скрипт)
- Пошаговая инструкция конвертации VM → Template в vSphere UI
- Проверка что Template создан корректно

---

### Этап 6: Валидация Template

**Создай:** `research/vm-template-prep/04-template-validation.md`

**Содержание:**
- Процедура клонирования тестовой VM из Template
- Проверки которые нужно выполнить:
  - Cloud-init отработал корректно
  - Статический IP настроен
  - DNS работает
  - Интернет доступен
  - SSH доступ работает
  - Hostname установлен правильно
- Список команд для валидации

**Команды валидации (примеры):**
```bash
# Проверка IP
ip addr show ens192

# Проверка маршрутов
ip route

# Проверка DNS
cat /etc/resolv.conf
nslookup google.com

# Проверка интернета
ping -c 3 8.8.8.8

# Проверка cloud-init
cloud-init status
cat /var/log/cloud-init.log
```

---

### Этап 7: Troubleshooting Guide

**Создай:** `research/vm-template-prep/05-troubleshooting.md`

**Содержание:**
- Типичные проблемы при создании Template
- Решения для каждой проблемы
- Команды диагностики

**Примеры проблем:**
1. Cloud-init не отрабатывает
2. Статический IP не применяется
3. DNS не работает
4. SSH недоступен после клонирования
5. Machine-id не уникальный

---

## 📦 Артефакты на выходе

После выполнения всех этапов должны быть созданы:

### Документация:
- [x] `research/vm-template-prep/01-vm-requirements.md`
- [x] `research/vm-template-prep/02-create-vm-in-vsphere.md`
- [x] `research/vm-template-prep/03-convert-to-template.md`
- [x] `research/vm-template-prep/04-template-validation.md`
- [x] `research/vm-template-prep/05-troubleshooting.md`

### Скрипты:
- [x] `scripts/prepare-vm-template.sh` — подготовка VM перед конвертацией

### Конфигурации:
- [x] `manifests/cloud-init/server-node.yaml` — для 10.246.10.50
- [x] `manifests/cloud-init/agent-node-01.yaml` — для 10.246.10.51
- [x] `manifests/cloud-init/agent-node-02.yaml` — для 10.246.10.52

---

## ✅ Критерии успеха

Задание считается выполненным когда:

1. **Все артефакты созданы** и сохранены в правильных местах
2. **Инструкции понятны** оператору без технического бэкграунда
3. **Скрипты готовы к использованию** без изменений
4. **Cloud-init конфигурации валидны** (корректный YAML)
5. **Troubleshooting guide покрывает** основные проблемы

**Валидация успеха (выполнит оператор):**
- [ ] Minimal Ubuntu VM создана в vSphere
- [ ] Скрипт `prepare-vm-template.sh` успешно выполнен
- [ ] VM конвертирована в Template: `k3s-ubuntu2404-minimal-template`
- [ ] Тестовое клонирование прошло успешно
- [ ] Cloud-init отработал корректно (static IP, hostname, DNS)
- [ ] SSH доступ к клонированной VM работает

---

## 🎯 Порядок работы с оператором

### Для оператора:

**Шаг 1:** Прикрепи к AI-агенту следующие файлы:
- `README.md` — обзор проекта
- `nsx-configs/segments.md` — сетевая конфигурация
- `research/vm-template-prep/AI-AGENT-TASK.md` — это задание

**Шаг 2:** Используй промпт:
```
Привет! Ты AI-агент, работающий над проектом k3s на vSphere.

Я прикрепил:
1. README.md — обзор проекта
2. nsx-configs/segments.md — параметры сети
3. AI-AGENT-TASK.md — твоя задача

Твоя задача: Создать minimal VM Template для k3s кластера.

КРИТИЧЕСКИ ВАЖНО: Это НЕ обычный Kubernetes Template!
k3s — это единый бинарник, который сам устанавливает все компоненты.
НЕ нужно предустанавливать kubeadm, kubelet, kubectl, containerd!

Инфраструктура:
- vSphere: 8.0.3
- Network: k8s-zeon-dev-segment (10.246.10.0/24)
- DNS: 172.17.10.3
- Gateway: 10.246.10.1
- SSH: k8s-admin:admin

Пожалуйста:
1. Прочитай AI-AGENT-TASK.md полностью
2. Создавай артефакты последовательно (Этапы 1-7)
3. Объясняй каждое решение
4. Пиши готовые к использованию скрипты

Начнём с Этапа 1: Документация требований к VM.
Готов?
```

**Шаг 3:** Работай с AI-агентом итеративно:
- AI создаёт артефакт
- Ты сохраняешь в репозиторий
- Переходишь к следующему артефакту

**Шаг 4:** После получения всех артефактов:
- Применяй инструкции на vSphere
- Выполняй валидацию
- Сообщи Team Lead о результатах

---

## 📚 Полезные ссылки для AI-агента

**Официальная документация:**
- [Ubuntu 24.04 Cloud Images](https://cloud-images.ubuntu.com/releases/24.04/)
- [Cloud-init Documentation](https://cloudinit.readthedocs.io/)
- [k3s Documentation](https://docs.k3s.io/)
- [VMware Cloud-Init](https://docs.vmware.com/en/VMware-vSphere/8.0/vsphere-vm-administration/GUID-E63B6FAA-8D35-428D-B40C-744769845906.html)

**Важные замечания:**
- Ubuntu 24.04 использует **Netplan v2** для сетевых настроек
- В Netplan v2: `gateway4:` **deprecated**, используй `routes:` + `via:`
- Cloud-init должен быть настроен через `/etc/cloud/cloud.cfg.d/`
- vSphere распознаёт cloud-init через `guestinfo.*` properties

---

## ⏱️ Оценка времени

| Этап | AI создание | Оператор применение | Итого |
|------|-------------|---------------------|-------|
| Этапы 1-7 (документы + скрипты) | 20 мин | - | 20 мин |
| Создание VM в vSphere | - | 10 мин | 10 мин |
| Выполнение скрипта подготовки | - | 5 мин | 5 мин |
| Конвертация в Template | - | 2 мин | 2 мин |
| Валидация (клонирование + проверки) | - | 8 мин | 8 мин |
| **ИТОГО** | **20 мин** | **25 мин** | **~45 мин** |

---

## 🎉 Финальная проверка

Перед передачей результатов Team Lead, убедись что:

- ✅ Все 5 документов созданы
- ✅ Скрипт `prepare-vm-template.sh` готов и протестирован
- ✅ 3 cloud-init конфигурации созданы и валидны
- ✅ Инструкции понятны и детальны
- ✅ Troubleshooting guide покрывает основные проблемы
- ✅ VM Template создан в vSphere: `k3s-ubuntu2404-minimal-template`
- ✅ Тестовое клонирование успешно

---

**Удачи, AI-агент! Создавай отличный minimal VM Template для k3s! 🚀**

**Team Lead ждёт результатов для перехода к Этапу 1 (k3s Server installation).**
