# 🚀 СТАРТ: Установка k3s Agent Nodes

> **От:** Team Lead
> **Дата:** 2025-10-24
> **Этап:** 1.2 - Agent Nodes Setup

---

## ✅ ПОЗДРАВЛЯЮ С ЗАВЕРШЕНИЕМ ЭТАПА 1.1!

**k3s Server Node работает!** 🎉

Теперь присоединяем **2 Agent ноды** для запуска workloads!

---

## 🎯 ЗАДАЧА ЭТАПА 1.2

**Присоединить 2 k3s Agent Nodes** к кластеру:
- **Agent-01:** 10.246.10.51 (k3s-agent-01)
- **Agent-02:** 10.246.10.52 (k3s-agent-02)

**Результат:** Кластер из 3 нод (1 Server + 2 Agent), все Ready.

**Время выполнения:** ~35 минут (12 мин AI + 23 мин применение)

---

## 📦 ЧТО ПОЛУЧИТЕ ОТ AI

AI создаст **8 артефактов:**

**Документация (6 файлов):**
1. `research/agent-nodes-setup/01-agent-overview.md`
2. `research/agent-nodes-setup/02-get-node-token.md`
3. `research/agent-nodes-setup/03-clone-vms-for-agents.md`
4. `research/agent-nodes-setup/04-installation-steps.md`
5. `research/agent-nodes-setup/05-validate-cluster.md`
6. `research/agent-nodes-setup/06-troubleshooting.md`

**Скрипты (2 файла):**
7. `scripts/install-k3s-agent.sh` — установка Agent
8. `scripts/validate-k3s-cluster.sh` — валидация кластера

---

## 🚀 КАК НАЧАТЬ

### Прикрепите файлы к AI:
- `README.md`
- `nsx-configs/segments.md`
- `research/agent-nodes-setup/AI-AGENT-TASK.md`

### Используйте промпт:
```
Привет! Ты AI-агент, работающий над проектом k3s на vSphere.

Я прикрепил:
1. README.md — обзор проекта
2. nsx-configs/segments.md — параметры сети
3. AI-AGENT-TASK.md — твоя задача

Твоя задача: Установить k3s Agent Nodes и присоединить к кластеру.

Контекст:
- Этап 0 (VM Template) завершён ✅
- Этап 1.1 (k3s Server) завершён ✅
- Server нода работает на 10.246.10.50
- kubectl работает
- node-token получен
- Сейчас присоединяем 2 Agent ноды

Инфраструктура:
- Server IP: 10.246.10.50 (работает)
- Agent-01 IP: 10.246.10.51
- Agent-02 IP: 10.246.10.52
- DNS: 172.17.10.3, 8.8.8.8
- Gateway: 10.246.10.1

k3s Agent = ПРОСТОЕ присоединение одной командой!
curl -sfL https://get.k3s.io | K3S_URL=... K3S_TOKEN=... sh -s - agent

Пожалуйста:
1. Прочитай AI-AGENT-TASK.md полностью
2. Создавай артефакты последовательно (Этапы 1-8)
3. Пиши готовые скрипты
4. Фокус на простоте k3s!

Начнём с Этапа 1: Обзор процесса присоединения Agent.
Готов?
```

---

## 📋 ПРОЦЕСС РАБОТЫ

### 1. AI создаёт артефакты (~12 мин)
   - Документы по присоединению Agent
   - Скрипты установки
   - Валидационные процедуры

### 2. Вы применяете (~23 мин)
   - Получаете node-token с Server (2 мин)
   - Клонируете 2 VM из Template (6 мин)
   - Применяете cloud-init для .51 и .52
   - Устанавливаете k3s agent на обеих (10 мин)
   - Валидация кластера (5 мин)

### 3. Результат
   - ✅ 3 ноды в кластере
   - ✅ Все ноды Ready
   - ✅ Pods распределяются по всем нодам
   - ✅ Базовый кластер полностью функционален

---

## ✅ КРИТЕРИИ УСПЕХА

Этап 1.2 завершён когда:

- [ ] 2 VM клонированы для Agent (10.246.10.51-52)
- [ ] k3s agent установлен на обеих нодах
- [ ] `systemctl status k3s-agent` = active на Agent
- [ ] `kubectl get nodes` показывает 3 Ready ноды
- [ ] Все системные pods Running
- [ ] Тестовый deployment успешен
- [ ] Pods запускаются на Agent нодах

---

## 📊 ЧТО ДАЛЬШЕ

После успешной установки Agent нод:
- **Этап 2:** vSphere CSI Driver (~25 мин)
- **Этап 3:** Validation & Testing (~15 мин)

**До полностью готового кластера:** ~40 минут!

---

## 📞 ОБРАТНАЯ СВЯЗЬ

После завершения сообщите Team Lead:

**✅ Если успешно:**
```
Team Lead, Этап 1.2 завершён!
- 2 Agent ноды присоединены (10.246.10.51-52)
- kubectl get nodes показывает 3 Ready ноды
- Все системные pods Running
- Тестовый deployment успешен
- Кластер полностью функционален
- Готов к Этапу 2 (vSphere CSI)
```

**⚠️ Если проблемы:**
```
Team Lead, проблема на Этапе 1.2:
- [Описание]
- [Логи]
```

---

## 💡 ПОЛЕЗНАЯ ИНФОРМАЦИЯ

### k3s Agent — это ПРОСТО!

**Установка Agent:**
```bash
# Получить token с Server
ssh k8s-admin@10.246.10.50
sudo cat /var/lib/rancher/k3s/server/node-token

# Установить Agent
ssh k8s-admin@10.246.10.51
curl -sfL https://get.k3s.io | \
  K3S_URL=https://10.246.10.50:6443 \
  K3S_TOKEN=xxx sh -s - agent \
  --node-ip 10.246.10.51 \
  --node-name k3s-agent-01
```

**Всё! За 2-3 минуты нода присоединена!**

### Проверка:
```bash
# С Server ноды
kubectl get nodes
# Должно показать 3 ноды в Ready
```

---

**Начинайте работу с AI-агентом! Удачи! 🚀**

**После этого этапа у вас будет полноценный 3-node кластер!**
