# NSX-T Network Configuration for k3s Cluster

> **Статус:** ✅ ГОТОВО (Переиспользуем из k8s проекта)
> **Дата:** 2025-10-22
> **Источник:** Настроено для k8s, переиспользуется для k3s

---

## Обзор

Этот документ описывает **NSX-T сеть**, которая будет использоваться для k3s кластера.

**Решение:** ✅ **Переиспользуем существующий T1 Gateway + сегмент** из k8s проекта

---

## Segment Information

| Параметр | Значение | Примечания |
|----------|---------|-----------|
| **Segment Name** | `k8s-zeon-dev-segment` | Существующий сегмент в NSX-T |
| **Subnet (CIDR)** | `10.246.10.0/24` | 254 доступных IP |
| **Gateway IP** | `10.246.10.1/24` | LIF на T1-k8s-zeon-dev |
| **DHCP Enabled** | `No` | Статические IP через cloud-init |
| **Tier-1 Gateway** | `T1-k8s-zeon-dev` | Существующий T1 для k8s |
| **Tier-0 Gateway** | `TO-GW` | Существующий T0 |
| **Transport Zone** | `nsx-overlay-transportzone` | Overlay TZ |

---

## IP Allocation Plan для k3s

**Всего доступных IP:** `254`

### k3s Cluster IPs

| IP Address | Purpose | Status | Notes |
|------------|---------|--------|-------|
| `10.246.10.1` | Gateway (Tier-1) | Reserved | NSX-T автоматически |
| **k3s Nodes:** ||||
| `10.246.10.50` | k3s Server Node 1 | Reserved | API Server + etcd + workloads |
| `10.246.10.51` | k3s Agent Node 1 | Reserved | Worker node |
| `10.246.10.52` | k3s Agent Node 2 | Reserved | Worker node |
| `10.246.10.53-60` | Future k3s nodes | Available | Резерв для масштабирования |
| **Services:**||||
| `10.246.10.200-220` | ServiceLB IP Pool | Reserved | Для встроенного ServiceLB (21 IP) |

### Диапазоны (обзор)

| Range | Purpose | Count | Status |
|-------|---------|-------|--------|
| `10.246.10.1` | Gateway | 1 | Reserved |
| `10.246.10.10-12` | Reserved (k8s CP если нужно) | 3 | Reserved |
| `10.246.10.20-30` | Reserved (k8s Workers если нужно) | 11 | Reserved |
| `10.246.10.50-60` | **k3s Nodes** | 11 | **Active** |
| `10.246.10.100` | Reserved (kube-vip если нужно) | 1 | Reserved |
| `10.246.10.200-220` | **ServiceLB Pool** | 21 | **Active** |

**✅ IP-план для k3s зафиксирован!**

---

## Сравнение с k8s проектом

### k8s использовал:
- `10.246.10.10-12` — Control Plane ноды
- `10.246.10.20-30` — Worker ноды
- `10.246.10.100` — API VIP (kube-vip)

### k3s использует:
- `10.246.10.50` — Server нода (нет необходимости в VIP)
- `10.246.10.51-52` — Agent ноды
- `10.246.10.200-220` — ServiceLB Pool

**Изоляция:** Разные IP диапазоны, никаких конфликтов ✅

---

## NAT Configuration (из k8s проекта)

### Существующие NAT правила на T1-k8s-zeon-dev:

| Priority | Type | Source | Destination | Translated | Описание |
|----------|------|--------|-------------|------------|----------|
| 100 | SNAT | 10.246.10.0/24 | Any | 172.16.50.170 | Исходящий трафик из k3s |
| 200 | DNAT | 172.16.50.170 | 172.16.50.170:6443 | 10.246.10.50:6443 | k3s API (опционально) |
| - | - | - | - | - | Можно добавить при необходимости |

**Примечание:** Для k3s достаточно существующего SNAT правила. DNAT для API опционален (если нужен внешний доступ).

---

## Route Advertisement (из k8s проекта)

T1 Gateway `T1-k8s-zeon-dev` настроен для анонсирования:
- ✅ Connected Segments
- ✅ NAT IPs
- ✅ LB VIP (если используется)

**Для k3s:** Конфигурация уже готова, изменений не требуется ✅

---

## Network Policies (Опционально для k3s)

### DFW Rules (из k8s проекта)

Существующие правила Distributed Firewall применяются ко всему сегменту.

**Для k3s:** Можно переиспользовать или создать отдельную группу для k3s нод.

**Минимальные требования:**
- Разрешить 6443 (API Server) между нодами
- Разрешить 10250 (Kubelet) между нодами
- Разрешить 8472 (Flannel VXLAN) между нодами
- Разрешить исходящий трафик для интернета (для установки пакетов)

---

## MTU Settings

**MTU в сегменте:** `1500` (стандартный)
**MTU для k3s:** Flannel использует default MTU

**Проверка после установки:**
```bash
# На любой k3s ноде
ip link show | grep mtu
# flannel.1 должен быть 1450 (или 1400 для safety)
```

**Если проблемы:** Flannel автоматически вычисляет MTU, обычно работает "из коробки"

---

## DNS Configuration

### Для k3s нод:

**DNS серверы** (указать в cloud-init):
- Primary: [Корпоративный DNS или 8.8.8.8]
- Secondary: [Корпоративный DNS или 8.8.4.4]

**DNS поиск:**
- `zeon.local` (корпоративный домен)
- `cluster.local` (внутренний k3s)

### Опциональные DNS записи:

| Hostname | IP | Type | Purpose |
|----------|-----|------|---------|
| `k3s-server.zeon.local` | `10.246.10.50` | A | Server нода |
| `k3s-api.zeon.local` | `10.246.10.50` | A | API endpoint (опционально) |

---

## Connectivity Validation

### После развёртывания k3s проверить:

```bash
# 1. Gateway доступен
ping 10.246.10.1

# 2. Интернет доступен
ping 8.8.8.8

# 3. DNS работает
nslookup google.com

# 4. Ноды видят друг друга
ping 10.246.10.50  # server
ping 10.246.10.51  # agent 1
ping 10.246.10.52  # agent 2

# 5. API Server доступен
curl -k https://10.246.10.50:6443/version
```

---

## Security Considerations

### Минимальная безопасность:

1. **Изоляция сегмента:** ✅ Отдельный T1 Gateway
2. **Firewall:** Существующие DFW правила применяются
3. **SNAT:** Скрывает внутренние IP при исходящем трафике
4. **TLS:** k3s использует TLS для всей коммуникации

### Для Production:

- [ ] Создать отдельную DFW группу для k3s
- [ ] Ограничить доступ к API (6443) только с разрешённых IP
- [ ] Настроить IDS/IPS на T1 Gateway
- [ ] Включить логирование трафика

---

## Troubleshooting

### Проблема: Ноды не могут подключиться к интернету

**Проверка:**
```bash
ping 8.8.8.8
traceroute 8.8.8.8
```

**Решение:**
- Проверить SNAT правило на T1
- Проверить Route Advertisement
- Проверить что T1 подключен к T0

### Проблема: Ноды не видят друг друга

**Проверка:**
```bash
ping [IP другой ноды]
tcpdump -i ens192 icmp
```

**Решение:**
- Проверить что все ноды в одном сегменте
- Проверить DFW правила
- Проверить что SpoofGuard не блокирует

### Проблема: API Server недоступен

**Проверка:**
```bash
curl -k https://10.246.10.50:6443/version
sudo systemctl status k3s
```

**Решение:**
- Проверить что k3s запущен
- Проверить firewall на server ноде
- Проверить что порт 6443 открыт в DFW

---

## Summary

**NSX-T конфигурация готова для k3s:**
- ✅ Segment: k8s-zeon-dev-segment (10.246.10.0/24)
- ✅ Gateway: 10.246.10.1
- ✅ IP-план: 10.246.10.50-52 для k3s нод
- ✅ NAT: SNAT для исходящего трафика
- ✅ Routing: Route Advertisement настроен
- ✅ Изоляция: Отдельный T1 Gateway

**Не требует изменений для k3s!** Можно сразу начинать развёртывание.

---

**Следующий шаг:** [docs/01-vm-template-prep.md](../docs/01-vm-template-prep.md)
