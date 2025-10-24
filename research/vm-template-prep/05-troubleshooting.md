# Troubleshooting Guide для k3s Template

> **Этап:** 0 - VM Template Preparation
> **Статус:** ✅ ГОТОВО
> **Дата:** 2025-10-24
> **Цель:** Решение типичных проблем при создании Template

---

## 🎯 Обзор

Этот документ содержит **решения типичных проблем** при создании и использовании Template для k3s кластера.

### ⚠️ Важно для оператора

- **Цель:** Быстро решить проблемы без пересоздания Template
- **Подход:** От простых к сложным решениям
- **Время:** Зависит от проблемы (5-30 минут)

---

## 🚨 Типичные проблемы

### Проблема 1: Cloud-init не отрабатывает

#### Симптомы

- Статический IP не применяется
- Hostname не устанавливается
- SSH не настраивается
- Пользователь не создаётся

#### Диагностика

```bash
# Проверка статуса cloud-init
cloud-init status
# Должно быть: done

# Проверка логов cloud-init
cat /var/log/cloud-init.log
# Ищите ошибки в логах

# Проверка времени выполнения
cloud-init status --long
# Должно показать время выполнения

# Проверка конфигурации
cat /etc/cloud/cloud.cfg
# Проверьте настройки
```

#### Решения

**Решение 1: Настройка cloud-init для VMware**

```bash
# Настройка cloud-init для VMware vSphere
sudo tee /etc/cloud/cloud.cfg.d/98-datasource.cfg >/dev/null <<'YAML'
datasource_list: [ VMware, OVF, NoCloud, None ]
YAML

# Включение cloud-init сервисов
sudo systemctl unmask cloud-init cloud-init-local cloud-config cloud-final
sudo systemctl enable cloud-init cloud-init-local cloud-config cloud-final

# Удаление кастомных netplan-файлов для генерации 50-cloud-init.yaml
sudo rm -f /etc/netplan/*.yaml

# Очистка состояния cloud-init
sudo cloud-init clean --logs --machine
sudo rm -rf /var/lib/cloud

# Перезапуск cloud-init
sudo cloud-init init

# Проверка статуса
cloud-init status
```

**Решение 2: Проверка настроек в vSphere**

1. **Откройте vSphere Client**
2. **Выберите VM**
3. **Правый клик** → **Edit Settings**
4. **Проверьте настройки cloud-init:**
   - **User Data:** Должен содержать cloud-init конфигурацию
   - **Meta Data:** Должен содержать метаданные
   - **Network Data:** Должен содержать сетевые настройки

**Решение 3: Ручная настройка сети**

```bash
# Если cloud-init не применил сетевые настройки
sudo netplan apply

# Перезапуск сетевых сервисов
sudo systemctl restart systemd-networkd

# Проверка сетевых настроек
ip addr show ens192
```

**Решение 4: Ручная настройка пользователя**

```bash
# Если пользователь не создался
sudo useradd -m -s /bin/bash k8s-admin
sudo usermod -aG sudo k8s-admin
echo 'k8s-admin:admin' | sudo chpasswd

# Настройка SSH
sudo systemctl enable ssh
sudo systemctl start ssh
```

---

### Проблема 2: Сеть не работает

#### Симптомы

- IP не назначается
- Нет подключения к интернету
- Ноды не видят друг друга
- DNS не работает

#### Диагностика

```bash
# Проверка сетевых интерфейсов
ip addr show
# Должен быть интерфейс ens192

# Проверка маршрутов
ip route
# Должен быть default route

# Проверка DNS
cat /etc/resolv.conf
# Должны быть DNS серверы

# Проверка подключения к gateway
ping -c 3 10.246.10.1
# Должен быть успешный ping

# Проверка подключения к интернету
ping -c 3 8.8.8.8
# Должен быть успешный ping
```

#### Решения

**Решение 1: Применение сетевых настроек**

```bash
# Применение netplan
sudo netplan apply

# Перезапуск сетевых сервисов
sudo systemctl restart systemd-networkd

# Проверка статуса
sudo systemctl status systemd-networkd
```

**Решение 2: Ручная настройка сети**

```bash
# Создание файла netplan
sudo tee /etc/netplan/01-static-ip.yaml > /dev/null << 'EOF'
network:
  version: 2
  ethernets:
    ens192:
      addresses:
        - 10.246.10.50/24
      routes:
        - to: default
          via: 10.246.10.1
      nameservers:
        addresses:
          - 172.17.10.3
          - 8.8.8.8
      dhcp4: false
      dhcp6: false
EOF

# Применение настроек
sudo netplan apply
```

**Решение 3: Проверка NSX-T segment**

1. **Проверьте в vSphere UI:**
   - VM подключена к правильному segment
   - Segment настроен корректно
   - Gateway доступен

2. **Проверьте в NSX-T UI:**
   - T1 Gateway активен
   - Route Advertisement настроен
   - NAT правила работают

**Решение 4: Сброс сетевых настроек**

```bash
# Остановка сетевых сервисов
sudo systemctl stop systemd-networkd

# Очистка сетевых настроек
sudo rm -f /etc/netplan/*.yaml

# Перезапуск сетевых сервисов
sudo systemctl start systemd-networkd

# Настройка сети заново
sudo netplan apply
```

---

### Проблема 3: SSH недоступен

#### Симптомы

- Не удаётся подключиться по SSH
- Таймаут подключения
- Отказ в доступе
- Пароль не принимается

#### Диагностика

```bash
# Проверка статуса SSH
sudo systemctl status ssh
# Должен быть: active (running)

# Проверка портов
sudo netstat -tlnp | grep :22
# Должен слушать на порту 22

# Проверка firewall
sudo ufw status
# Должны быть правила для SSH

# Проверка пользователя
id k8s-admin
# Пользователь должен существовать

# Проверка пароля
sudo passwd -S k8s-admin
# Пароль должен быть установлен
```

#### Решения

**Решение 1: Запуск SSH**

```bash
# Включение SSH
sudo systemctl enable ssh
sudo systemctl start ssh

# Проверка статуса
sudo systemctl status ssh
```

**Решение 2: Настройка firewall**

```bash
# Разрешение SSH через firewall
sudo ufw allow ssh

# Проверка правил
sudo ufw status
```

**Решение 3: Сброс пароля**

```bash
# Установка пароля
echo 'k8s-admin:admin' | sudo chpasswd

# Проверка пароля
sudo passwd -S k8s-admin
```

**Решение 4: Проверка SSH конфигурации**

```bash
# Проверка SSH конфигурации
sudo cat /etc/ssh/sshd_config | grep -E "(PasswordAuthentication|PermitRootLogin|Port)"

# Должно быть:
# PasswordAuthentication yes
# PermitRootLogin no
# Port 22

# Перезапуск SSH
sudo systemctl restart ssh
```

**Решение 5: Cloud-init управление SSH**

```bash
# Cloud-init автоматически управляет SSH при клонировании
# Проверка что cloud-init настроен правильно
cat /etc/cloud/cloud.cfg.d/98-datasource.cfg

# Должно содержать:
# datasource_list: [ VMware, OVF, NoCloud, None ]

# При клонировании cloud-init:
# 1. Удалит старые SSH ключи хоста
# 2. Сгенерирует новые SSH ключи
# 3. Настроит пользователя k8s-admin
# 4. Настроит пароль admin
```

---

### Проблема 4: VMware Tools не работает

#### Симптомы

- VMware Tools не активен
- Нет интеграции с vSphere
- Проблемы с клонированием
- Ошибки в логах

#### Диагностика

```bash
# Проверка статуса VMware Tools
sudo systemctl status open-vm-tools
# Должен быть: active (running)

# Проверка версии
vmware-toolbox-cmd --version
# Должна быть версия

# Проверка логов
sudo journalctl -u open-vm-tools
# Ищите ошибки в логах

# Проверка установки
dpkg -l | grep open-vm-tools
# Пакеты должны быть установлены
```

#### Решения

**Решение 1: Переустановка VMware Tools**

```bash
# Удаление старых пакетов
sudo apt remove --purge open-vm-tools open-vm-tools-desktop

# Установка новых пакетов
sudo apt update
sudo apt install -y open-vm-tools open-vm-tools-desktop

# Запуск сервиса
sudo systemctl enable open-vm-tools
sudo systemctl start open-vm-tools
```

**Решение 2: Проверка конфигурации**

```bash
# Проверка конфигурации
sudo cat /etc/vmware-tools/tools.conf

# Должно содержать настройки для VMware
```

**Решение 3: Ручной запуск**

```bash
# Остановка сервиса
sudo systemctl stop open-vm-tools

# Ручной запуск
sudo /usr/bin/vmware-toolbox-cmd

# Запуск сервиса
sudo systemctl start open-vm-tools
```

---

### Проблема 5: Template не клонируется

#### Симптомы

- Ошибка при клонировании
- VM не запускается
- Cloud-init не отрабатывает в клонированной VM
- Проблемы с сетью

#### Диагностика

```bash
# Проверка состояния Template
# В vSphere UI: Template должен быть в разделе Templates

# Проверка настроек Template
# Правый клик → Edit Settings
# Проверьте все настройки
```

#### Решения

**Решение 1: Проверка Template**

1. **В vSphere UI:**
   - Template должен быть в разделе Templates
   - Настройки должны быть корректными
   - Нет ошибок в статусе

2. **Проверка настроек:**
   - vCPU: 2
   - RAM: 4 GB
   - Disk: 40 GB
   - Network: k8s-zeon-dev-segment

**Решение 2: Создание новой customization spec**

1. **В vSphere UI:**
   - **Home** → **Policies and Profiles** → **VM Customization**
   - **Create** → **New Customization Spec**
   - **Name:** `k3s-customization`
   - **Guest OS:** Linux
   - **Настройте cloud-init**

**Решение 3: Проверка cloud-init в клонированной VM**

```bash
# Подключение к клонированной VM
# Проверка cloud-init
cloud-init status

# Если cloud-init не отработал:
sudo cloud-init clean --logs
sudo cloud-init init
```

---

### Проблема 6: Запрещённые пакеты установлены

#### Симптомы

- В Template установлены kubeadm, kubelet, kubectl
- Установлен containerd или Docker
- Установлены CNI плагины
- Template не подходит для k3s

#### Диагностика

```bash
# Проверка установленных пакетов
dpkg -l | grep -E "(kubeadm|kubelet|kubectl|containerd|docker|flannel|calico|cilium)"

# Должно быть пусто
```

#### Решения

**Решение 1: Удаление запрещённых пакетов**

```bash
# Удаление K8s компонентов
sudo apt remove --purge kubeadm kubelet kubectl kubernetes-cni

# Удаление container runtime
sudo apt remove --purge containerd docker.io docker-ce cri-o

# Удаление CNI плагинов
sudo apt remove --purge flannel calico cilium

# Удаление Ingress контроллеров
sudo apt remove --purge nginx-ingress traefik

# Удаление LoadBalancer
sudo apt remove --purge metallb kube-vip

# Очистка системы
sudo apt autoremove -y
sudo apt autoclean
```

**Решение 2: Пересоздание Template**

Если запрещённые пакеты не удаляются:

1. **Удалите текущий Template**
2. **Создайте новую VM** по инструкции
3. **Выполните скрипт** `prepare-vm-template.sh`
4. **Конвертируйте в Template**

---

### Проблема 7: Система не очищена

#### Симптомы

- Логи не очищены
- History команд не очищен
- SSH keys не удалены
- Machine-id не сброшен

#### Диагностика

```bash
# Проверка логов
sudo journalctl --disk-usage
# Должно быть минимальное использование

# Проверка history
history | wc -l
# Должно быть мало команд

# Проверка SSH keys
ls -la /etc/ssh/ssh_host_*
# Должно быть пусто

# Проверка machine-id
cat /etc/machine-id
# Должен быть уникальный
```

#### Решения

**Решение 1: Ручная очистка**

```bash
# Очистка логов
sudo journalctl --vacuum-time=1d
sudo find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;

# Очистка history
history -c
rm -f ~/.bash_history

# Очистка SSH keys
sudo rm -f /etc/ssh/ssh_host_*

# Сброс machine-id
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
sudo systemd-machine-id-setup

# Очистка cloud-init
sudo cloud-init clean --logs
```

**Решение 2: Повторный запуск скрипта**

```bash
# Запуск скрипта очистки
sudo /opt/k3s-setup/prepare-vm-template.sh

# Или выполнение только очистки
sudo /opt/k3s-setup/prepare-vm-template.sh --cleanup-only
```

---

## 🔧 Команды диагностики

### Общие команды

```bash
# Проверка системы
uname -a
cat /etc/os-release
free -h
df -h

# Проверка сети
ip addr show
ip route
cat /etc/resolv.conf
ping -c 3 8.8.8.8

# Проверка сервисов
sudo systemctl status ssh
sudo systemctl status open-vm-tools
sudo systemctl status systemd-networkd

# Проверка cloud-init
cloud-init status
cat /var/log/cloud-init.log
```

### Специфичные команды

```bash
# Проверка пакетов
dpkg -l | grep -E "(curl|wget|vim|cloud-init|open-vm-tools)"
dpkg -l | grep -E "(kubeadm|kubelet|kubectl|containerd|docker)"

# Проверка firewall
sudo ufw status
sudo netstat -tlnp

# Проверка пользователей
id k8s-admin
sudo passwd -S k8s-admin

# Проверка логов
sudo journalctl -xe
sudo journalctl -u ssh
sudo journalctl -u open-vm-tools
```

---

## 📋 Чек-лист решения проблем

### Перед началом

- [ ] Определите проблему
- [ ] Соберите информацию (логи, статусы)
- [ ] Попробуйте простые решения
- [ ] Документируйте действия

### После решения

- [ ] Проверьте что проблема решена
- [ ] Протестируйте функциональность
- [ ] Обновите документацию
- [ ] Сообщите о результатах

---

## 🎯 Профилактика проблем

### Рекомендации

1. **Следуйте инструкциям** точно
2. **Проверяйте каждый шаг** перед переходом к следующему
3. **Документируйте изменения** в системе
4. **Тестируйте Template** перед использованием
5. **Создавайте резервные копии** важных конфигураций

### Мониторинг

```bash
# Регулярные проверки
sudo systemctl status ssh
sudo systemctl status open-vm-tools
cloud-init status
sudo ufw status
```

---

**Создано:** 2025-10-24
**AI-агент:** VM Template Specialist
**Цель:** Быстрое решение проблем с Template
