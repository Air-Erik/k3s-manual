# Верификация cloud-init после запуска VM

> **Этап:** 0 - VM Template Preparation
> **Статус:** ✅ ГОТОВО
> **Дата:** 2025-10-24
> **Цель:** Детальная проверка работы cloud-init на клонированных VM

---

## 🎯 Обзор

Этот документ содержит **пошаговую процедуру верификации** cloud-init после запуска VM из Template. Помогает убедиться что все настройки применились корректно.

### ⚠️ Важно для оператора

- **Цель:** Убедиться что cloud-init отработал полностью
- **Время:** ~10 минут на проверку
- **Результат:** VM готова к установке k3s

---

## 📋 Предварительные требования

### Состояние VM

- ✅ **VM клонирована** из Template
- ✅ **Cloud-init настроен** в vSphere UI
- ✅ **VM запущена** и загрузилась
- ✅ **SSH доступен** (k3s-admin:admin)

### Необходимые данные

- **IP адрес VM:** 10.246.10.50/51/52
- **Пользователь:** k3s-admin
- **Пароль:** admin
- **Время:** ~10 минут

---

## 🔧 Пошаговая верификация

### Шаг 1: Подключение к VM

```bash
# SSH подключение к VM
ssh k3s-admin@10.246.10.50
# Пароль: admin

# Проверка что подключение успешно
whoami
# Должно быть: k3s-admin

pwd
# Должно быть: /home/k3s-admin
```

### Шаг 2: Проверка статуса cloud-init

#### 2.1 Общий статус

```bash
# Проверка статуса cloud-init
cloud-init status
# Должно быть: done

# Если не done, проверьте детали
cloud-init status --long
# Должно показать время выполнения и статус каждого этапа
```

#### 2.2 Проверка логов cloud-init

```bash
# Основные логи cloud-init
sudo cat /var/log/cloud-init.log | tail -20
# Ищите сообщения об успешном завершении

# Логи каждого этапа
sudo cat /var/log/cloud-init-output.log | tail -20
# Должны быть сообщения о выполнении команд

# Детальные логи
sudo journalctl -u cloud-init
sudo journalctl -u cloud-init-local
sudo journalctl -u cloud-config
sudo journalctl -u cloud-final
```

### Шаг 3: Проверка сетевых настроек

#### 3.1 Проверка IP адреса

```bash
# Проверка сетевых интерфейсов
ip addr show
# Должен быть интерфейс с правильным IP

# Проверка конкретного IP
ip addr show | grep "10.246.10"
# Должен показать ваш IP (50, 51, или 52)

# Проверка netplan конфигурации
cat /etc/netplan/50-cloud-init.yaml
# Должен содержать настройки сети
```

#### 3.2 Проверка маршрутов

```bash
# Проверка маршрутов
ip route
# Должен быть default route через 10.246.10.1

# Проверка gateway
ping -c 3 10.246.10.1
# Должен быть успешный ping
```

#### 3.3 Проверка DNS

```bash
# Проверка DNS настроек
cat /etc/resolv.conf
# Должны быть: 172.17.10.3, 8.8.8.8

# Проверка DNS работы
nslookup google.com
# Должен вернуть IP адрес

# Проверка интернета
ping -c 3 8.8.8.8
# Должен быть успешный ping
```

### Шаг 4: Проверка hostname

```bash
# Проверка hostname
hostname
# Должно быть: k3s-server-01, k3s-agent-01, или k3s-agent-02

# Проверка файла hostname
cat /etc/hostname
# Должен содержать правильный hostname

# Проверка /etc/hosts
cat /etc/hosts
# Должен содержать запись с hostname и IP
```

### Шаг 5: Проверка пользователя

#### 5.1 Проверка создания пользователя

```bash
# Проверка что пользователь создан
id k3s-admin
# Должен показать информацию о пользователе

# Проверка групп пользователя
groups k3s-admin
# Должна быть группа sudo

# Проверка sudo прав
sudo -l
# Должно показать права sudo
```

#### 5.2 Проверка SSH ключей

```bash
# Проверка SSH ключей пользователя
ls -la ~/.ssh/
# Должны быть authorized_keys (если настроены)

# Проверка SSH ключей хоста
sudo ls -la /etc/ssh/ssh_host_*
# Должны быть новые SSH ключи (rsa, ecdsa, ed25519)
```

### Шаг 6: Проверка выполненных команд

#### 6.1 Проверка директорий

```bash
# Проверка создания директории k3s-setup
ls -la /opt/k3s-setup
# Должна существовать и принадлежать k3s-admin

# Проверка прав на директорию
ls -la /opt/ | grep k3s-setup
# Должно быть: drwxr-xr-x k3s-admin k3s-admin
```

#### 6.2 Проверка firewall

```bash
# Проверка статуса firewall
sudo ufw status
# Должны быть правила для SSH и k3s портов

# Проверка конкретных правил
sudo ufw status | grep -E "(ssh|6443|10250|8472)"
# Должны быть активные правила
```

### Шаг 7: Проверка времени и локали

#### 7.1 Проверка времени

```bash
# Проверка текущего времени
date
# Должно быть правильное время

# Проверка часового пояса
timedatectl
# Должно быть: UTC

# Проверка NTP
sudo systemctl status systemd-timesyncd
# Должен быть активен
```

#### 7.2 Проверка локали

```bash
# Проверка локали
locale
# Должно быть: en_US.UTF-8

# Проверка доступных локалей
locale -a | grep en_US
# Должна быть en_US.UTF-8
```

---

## 🚨 Troubleshooting проблем

### Проблема 1: Cloud-init отключён (status: disabled)

#### Симптомы:
- `cloud-init status` показывает "disabled"
- Сетевой интерфейс в состоянии DOWN
- Нет маршрутов (ip route пустой)
- Нет IP адреса

#### Диагностика:
```bash
# Проверка статуса
cloud-init status
# Должно быть: done (не disabled)

# Проверка сетевых интерфейсов
ip addr show
# Должен быть интерфейс в состоянии UP

# Проверка маршрутов
ip route
# Должны быть маршруты
```

#### Решение 1: Автоматическое исправление
```bash
# Запуск скрипта исправления
./scripts/fix-cloud-init-vmware.sh
```

#### Решение 2: Ручное исправление
```bash
# КРИТИЧЕСКИ ВАЖНО: Включение cloud-init для VMware
# Добавление настройки в cloud.cfg
echo "disable_vmware_customization: false" | sudo tee -a /etc/cloud/cloud.cfg

# Проверка добавления
grep "disable_vmware_customization" /etc/cloud/cloud.cfg
# Должно быть: disable_vmware_customization: false

# Включение cloud-init
sudo systemctl unmask cloud-init cloud-init-local cloud-config cloud-final
sudo systemctl enable cloud-init cloud-init-local cloud-config cloud-final
sudo systemctl start cloud-init

# Настройка для VMware
sudo tee /etc/cloud/cloud.cfg.d/99-vmware.cfg > /dev/null << 'EOF'
disable_vmware_customization: false
datasource:
  VMware:
    metadata_urls: ['http://169.254.169.254']
    max_wait: 10
    timeout: 5
network:
  config: enabled
EOF

# Исправление сети
sudo rm -f /etc/netplan/*.yaml
sudo netplan apply
sudo systemctl restart systemd-networkd

# Перезапуск cloud-init
sudo cloud-init clean --logs --machine
sudo rm -rf /var/lib/cloud
sudo cloud-init init
```

### Проблема 2: Сеть не настроена

#### Симптомы:
- IP адрес не назначен
- Нет подключения к интернету
- DNS не работает

#### Диагностика:
```bash
# Проверка netplan
sudo netplan status
sudo netplan try

# Проверка сетевых интерфейсов
ip addr show
ip route
```

#### Решение:
```bash
# Применение сетевых настроек
sudo netplan apply
sudo systemctl restart systemd-networkd

# Проверка результата
ip addr show
ping -c 3 8.8.8.8
```

### Проблема 3: Пользователь не создан

#### Симптомы:
- Не удаётся войти как k3s-admin
- Пароль не принимается
- Нет sudo прав

#### Диагностика:
```bash
# Проверка пользователя
id k3s-admin
sudo passwd -S k3s-admin

# Проверка групп
groups k3s-admin
```

#### Решение:
```bash
# Ручное создание пользователя
sudo useradd -m -s /bin/bash k3s-admin
sudo usermod -aG sudo k3s-admin
echo 'k3s-admin:admin' | sudo chpasswd

# Проверка
id k3s-admin
```

### Проблема 4: SSH недоступен

#### Симптомы:
- Не удаётся подключиться по SSH
- Таймаут подключения
- Отказ в доступе

#### Диагностика:
```bash
# Проверка SSH статуса
sudo systemctl status ssh
sudo netstat -tlnp | grep :22
```

#### Решение:
```bash
# Запуск SSH
sudo systemctl enable ssh
sudo systemctl start ssh

# Проверка firewall
sudo ufw status
sudo ufw allow ssh
```

---

## ✅ Чек-лист верификации

### Обязательные проверки:

- [ ] **Cloud-init статус:** `done`
- [ ] **Сеть:** IP адрес назначен правильно
- [ ] **Маршруты:** Default route через 10.246.10.1
- [ ] **DNS:** Работает (nslookup google.com)
- [ ] **Интернет:** Доступен (ping 8.8.8.8)
- [ ] **Hostname:** Установлен правильно
- [ ] **Пользователь:** k3s-admin создан
- [ ] **SSH:** Доступен (k3s-admin:admin)
- [ ] **Sudo:** Права настроены
- [ ] **Директории:** /opt/k3s-setup создана
- [ ] **Firewall:** Правила настроены
- [ ] **Время:** UTC, NTP работает
- [ ] **Локаль:** en_US.UTF-8

### Дополнительные проверки:

- [ ] **SSH ключи:** Новые ключи хоста сгенерированы
- [ ] **Логи:** Нет ошибок в cloud-init логах
- [ ] **Сервисы:** Все необходимые сервисы активны
- [ ] **Права:** Правильные права на файлы и директории

---

## 🎯 Критерии успеха

### VM считается готовой когда:

1. **Все обязательные проверки пройдены** ✅
2. **Cloud-init отработал полностью** ✅
3. **Сеть настроена корректно** ✅
4. **Пользователь k3s-admin доступен** ✅
5. **SSH работает** ✅
6. **Нет ошибок в логах** ✅

### Следующие шаги:

1. **Установка k3s** на Server ноду
2. **Присоединение Agent нод** к кластеру
3. **Настройка vSphere CSI**
4. **Валидация кластера**

---

## 📊 Отчёт о верификации

### Создание отчёта:

```bash
# Создание отчёта о верификации
cat > /tmp/cloud-init-verification-report.txt << 'EOF'
# Отчёт о верификации cloud-init
# Дата: $(date)
# VM: $(hostname)
# IP: $(ip route get 8.8.8.8 | awk '{print $7}')

## Результаты проверок

### Cloud-init статус
- Статус: $(cloud-init status)
- Время выполнения: $(cloud-init status --long | grep "finished")

### Сеть
- IP адрес: $(ip addr show | grep "10.246.10" | awk '{print $2}')
- Gateway: $(ip route | grep default | awk '{print $3}')
- DNS: $(cat /etc/resolv.conf | grep nameserver | wc -l) серверов

### Пользователь
- Пользователь: $(whoami)
- Sudo права: $(sudo -l | wc -l) правил
- SSH доступ: $(systemctl is-active ssh)

### Система
- Hostname: $(hostname)
- Время: $(date)
- Локаль: $(locale | grep LANG)

### Результат
- Cloud-init: [успешно/ошибка]
- Сеть: [работает/не работает]
- Пользователь: [создан/не создан]
- SSH: [доступен/недоступен]
- Готовность: [готова/не готова]
EOF

echo "Отчёт создан: /tmp/cloud-init-verification-report.txt"
```

---

**Создано:** 2025-10-24
**AI-агент:** VM Template Specialist
**Цель:** Детальная верификация cloud-init
