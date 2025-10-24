# 🎯 НАЧАЛО РАБОТЫ: Создание VM Template для k3s

> **От:** Team Lead
> **Дата:** 2025-10-24
> **Этап:** 0 - VM Template Preparation

---

## ✅ ЧТО СДЕЛАНО

**Team Lead создал задание для AI-агента:**

```
research/vm-template-prep/
├── AI-AGENT-TASK.md           ✅ Детальное задание для AI (20 страниц)
└── OPERATOR-INSTRUCTIONS.md   ✅ Краткие инструкции для вас
```

**Обновлена документация:**
- ✅ `PROJECT-PLAN.md` — обновлён статус Этапа 0

---

## 🚀 ЧТО ДЕЛАТЬ ДАЛЬШЕ (ПРЯМО СЕЙЧАС)

### Вариант 1: Работа с AI-агентом в Cursor

Вы уже в Cursor, можете работать здесь:

1. **Прикрепите файлы** в Composer:
   - `README.md`
   - `nsx-configs/segments.md`
   - `research/vm-template-prep/AI-AGENT-TASK.md`

2. **Используйте промпт:**
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

### Вариант 2: Работа с ChatGPT/Claude

Откройте новый чат и следуйте тем же инструкциям.

---

## 📦 ЧТО ПОЛУЧИТЕ ОТ AI

AI создаст **9 артефактов:**

**Документация (5 файлов):**
1. `research/vm-template-prep/01-vm-requirements.md`
2. `research/vm-template-prep/02-create-vm-in-vsphere.md`
3. `research/vm-template-prep/03-convert-to-template.md`
4. `research/vm-template-prep/04-template-validation.md`
5. `research/vm-template-prep/05-troubleshooting.md`

**Скрипты (1 файл):**
6. `scripts/prepare-vm-template.sh`

**Cloud-init (3 файла):**
7. `manifests/cloud-init/server-node.yaml` (10.246.10.50)
8. `manifests/cloud-init/agent-node-01.yaml` (10.246.10.51)
9. `manifests/cloud-init/agent-node-02.yaml` (10.246.10.52)

---

## ⏱️ ВРЕМЯ ВЫПОЛНЕНИЯ

- **AI создаёт артефакты:** ~20 мин
- **Вы применяете на vSphere:** ~25 мин
- **ИТОГО:** ~45 мин

---

## 🎯 РЕЗУЛЬТАТ ЭТАПА 0

После выполнения у вас будет:
- ✅ VM Template: `k3s-ubuntu2404-minimal-template`
- ✅ Cloud-init конфигурации для 3 нод
- ✅ Скрипт подготовки VM
- ✅ Документация и troubleshooting

**Готовность к Этапу 1:** Установка k3s Server (~15 мин)

---

## 📞 ОБРАТНАЯ СВЯЗЬ

После завершения **сообщите мне (Team Lead):**
- ✅ Что выполнено
- ⚠️ Какие проблемы (если были)
- 🚀 Готовность к Этапу 1

---

**Удачи! Начинайте работу с AI-агентом! 🚀**
