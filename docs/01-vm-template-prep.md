# VM Template Preparation для k3s

> **Статус:** ⏳ TODO
> **Ответственный:** AI-исполнитель + Оператор
> **Зависимости:** ✅ NSX-T segment готов

---

## 🎯 Цель

Создать **minimal VM Template** для k3s кластера. В отличие от "полного" Kubernetes, k3s НЕ требует предустановки компонентов!

## ⚠️ Важно: Отличие от k8s Template

**k8s Template (НЕ использовать!):**
- ❌ kubeadm, kubelet, kubectl предустановлены
- ❌ containerd настроен
- ❌ sysctl для K8s настроены

**k3s Template (нужен новый!):**
- ✅ Только Ubuntu 24.04 LTS (minimal)
- ✅ Базовые утилиты
- ✅ Cloud-init
- ❌ **БЕЗ** K8s компонентов — k3s установит всё сам!

---

## 📋 Требования к Template

### Операционная система:
- **OS:** Ubuntu 24.04 LTS Server (minimal install)
- **Disk:** 40-50 ГБ (thin provisioned)
- **RAM:** 4 ГБ (для Server), 2 ГБ (для Agent)
- **vCPU:** 2 (для Server), 2 (для Agent)

### Установленные пакеты:
```bash
- curl, wget
- vim или nano
- net-tools
- cloud-init
- open-vm-tools
```

### НЕ устанавливать:
- ❌ kubeadm, kubelet, kubectl
- ❌ containerd (k3s использует встроенный)
- ❌ Docker
- ❌ Kubernetes-специфичные настройки

---

## 👉 Детальное задание для AI-агента

**AI-агент создаст:** `research/vm-template-prep/AI-AGENT-TASK.md`

**Артефакты от AI-агента:**
1. Пошаговые инструкции создания minimal Ubuntu VM
2. Список необходимых пакетов
3. Cloud-init конфигурации для k3s
4. Скрипт `scripts/prepare-minimal-vm.sh`
5. Процедуры валидации Template

---

## 🔧 Cloud-init для k3s

**Cloud-init должен настроить:**
- Hostname
- Static IP address
- DNS servers
- SSH keys
- Timezone

**Пример структуры:**
```yaml
#cloud-config
hostname: k3s-server-01
fqdn: k3s-server-01.zeon.local

users:
  - name: k8s-admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - [SSH_KEY]

write_files:
  - path: /etc/netplan/01-static-ip.yaml
    content: |
      network:
        version: 2
        ethernets:
          ens192:
            addresses: [10.246.10.50/24]
            gateway4: 10.246.10.1
            nameservers:
              addresses: [DNS_SERVERS]

runcmd:
  - netplan apply
```

---

## ✅ Критерии завершения

- [ ] Minimal Ubuntu 24.04 VM создана в vSphere
- [ ] Базовые пакеты установлены
- [ ] Cloud-init настроен и протестирован
- [ ] VM Template создан: `k3s-ubuntu2404-minimal-template`
- [ ] Тестовое клонирование прошло успешно
- [ ] Static IP через cloud-init работает

---

**Следующий шаг:** [02-server-node-setup.md](./02-server-node-setup.md)
