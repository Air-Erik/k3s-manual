# 🚀 СТАРТ: Установка k3s Server Node

> **От:** Team Lead
> **Дата:** 2025-10-24
> **Этап:** 1.1 - Server Node Setup

---

## ✅ ПОЗДРАВЛЯЮ С ЗАВЕРШЕНИЕМ ЭТАПА 0!

**VM Template успешно создан!** 🎉

Теперь переходим к самому интересному — **установке k3s кластера**!

---

## 🎯 ЗАДАЧА ЭТАПА 1.1

**Установить k3s Server Node** — первую ноду кластера, которая включает:
- Kubernetes API Server
- etcd (база данных состояния)
- Встроенные компоненты (Traefik, ServiceLB, CoreDNS, Flannel)

**Время выполнения:** ~28 минут (15 мин AI + 13 мин применение)

---

## 📦 ЧТО ПОЛУЧИТЕ ОТ AI

AI создаст **8 артефактов:**

**Документация (6 файлов):**
1. `research/server-node-setup/01-installation-process.md`
2. `research/server-node-setup/02-clone-vm-for-server.md`
3. `research/server-node-setup/03-get-credentials.md`
4. `research/server-node-setup/04-validate-installation.md`
5. `research/server-node-setup/05-troubleshooting.md`
6. `research/server-node-setup/06-prepare-for-agents.md`

**Скрипты (2 файла):**
7. `scripts/install-k3s-server.sh` — установка k3s
8. `scripts/validate-k3s-server.sh` — валидация

---

## 🚀 КАК НАЧАТЬ

### Вариант 1: Работа в Cursor (рекомендуется)

1. **Прикрепите файлы:**
   - `README.md`
   - `nsx-configs/segments.md`
   - `research/server-node-setup/AI-AGENT-TASK.md`

2. **Используйте промпт:**
```
Привет! Ты AI-агент, работающий над проектом k3s на vSphere.

Я прикрепил:
1. README.md — обзор проекта
2. nsx-configs/segments.md — параметры сети
3. AI-AGENT-TASK.md — твоя задача

Твоя задача: Установить k3s Server Node.

Контекст:
- Этап 0 (VM Template) завершён успешно ✅
- VM Template готов к клонированию
- Cloud-init конфигурации созданы
- Сейчас устанавливаем первую k3s ноду (Server)

Инфраструктура:
- Server IP: 10.246.10.50
- DNS: 172.17.10.3, 8.8.8.8
- Gateway: 10.246.10.1
- Interface: ens192

k3s — это ПРОСТАЯ установка одной командой!
curl -sfL https://get.k3s.io | sh -s - server [параметры]

Пожалуйста:
1. Прочитай AI-AGENT-TASK.md полностью
2. Создавай артефакты последовательно (Этапы 1-7)
3. Пиши готовые к использованию скрипты
4. Фокус на простоте k3s!

Начнём с Этапа 1: Документация процесса установки.
Готов?
```

### Вариант 2: ChatGPT/Claude

Те же инструкции, просто откройте новый чат.

---

## 📋 ПРОЦЕСС РАБОТЫ

### 1. AI создаёт артефакты (~15 мин)
   - Документы по установке
   - Скрипты
   - Troubleshooting guide

### 2. Вы применяете на vSphere (~13 мин)
   - Клонируете VM из Template (3 мин)
   - Применяете cloud-init для 10.246.10.50
   - SSH к VM
   - Запускаете `install-k3s-server.sh` (5 мин)
   - Валидация (5 мин)

### 3. Результат
   - ✅ k3s Server работает
   - ✅ kubectl доступен
   - ✅ Системные pods Running
   - ✅ kubeconfig и node-token сохранены

---

## ✅ КРИТЕРИИ УСПЕХА

Этап 1.1 завершён когда:

- [ ] VM клонирована для Server (10.246.10.50)
- [ ] k3s установлен: `systemctl status k3s` = active
- [ ] kubectl работает: `kubectl get nodes` показывает 1 Ready node
- [ ] Все системные pods Running
- [ ] kubeconfig получен и работает
- [ ] node-token сохранён для Agent нод

---

## 📊 ЧТО ДАЛЬШЕ

После успешной установки Server:
- **Этап 1.2:** Установка Agent Nodes (~20 мин)
- **Этап 2:** vSphere CSI Driver (~25 мин)
- **Этап 3:** Validation (~15 мин)

**До работающего кластера:** ~1 час!

---

## 📞 ОБРАТНАЯ СВЯЗЬ

После завершения сообщите Team Lead:

**✅ Если успешно:**
```
Team Lead, Этап 1.1 завершён!
- k3s Server установлен
- kubectl работает
- Системные pods Running
- kubeconfig и node-token сохранены
- Готов к Этапу 1.2 (Agent nodes)
```

**⚠️ Если проблемы:**
```
Team Lead, проблема на Этапе 1.1:
- [Описание]
- [Логи]
```

---

## 💡 ПОЛЕЗНАЯ ИНФОРМАЦИЯ

### k3s — это ПРОСТО!

**vs "полный" Kubernetes:**
- kubeadm: 20+ команд, 2-4 часа
- k3s: 1 команда, 5-10 минут

**Установка k3s:**
```bash
curl -sfL https://get.k3s.io | sh -s - server \
  --node-ip 10.246.10.50 \
  --flannel-iface ens192
```

**Всё! Kubernetes готов к работе!**

---

**Начинайте работу с AI-агентом! Удачи! 🚀**
