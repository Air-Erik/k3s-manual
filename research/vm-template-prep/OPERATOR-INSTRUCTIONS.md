# Инструкции для оператора: VM Template Preparation

> **Статус:** 🚀 Готово к выполнению
> **Дата:** 2025-10-24
> **От:** Team Lead

---

## 📋 Что было сделано Team Lead

✅ **Создано задание для AI-агента:**
- Файл: `research/vm-template-prep/AI-AGENT-TASK.md`
- Задание содержит полное описание работы
- Все исходные данные включены

---

## 🎯 Ваша задача

Работать с AI-агентом для создания **minimal VM Template** для k3s кластера.

### ⚠️ ВАЖНО:
Это НЕ обычный Kubernetes Template!
- ❌ НЕ устанавливать kubeadm, kubelet, kubectl
- ❌ НЕ настраивать containerd
- ✅ Только minimal Ubuntu 24.04 + базовые пакеты

k3s установится сам одной командой!

---

## 📝 Пошаговая инструкция

### Шаг 1: Откройте новый чат с AI-агентом

Используйте любой AI (ChatGPT, Claude, Cursor AI, etc.)

### Шаг 2: Прикрепите файлы

Прикрепите к чату следующие файлы:
1. `README.md` — обзор проекта
2. `nsx-configs/segments.md` — сетевая конфигурация
3. `research/vm-template-prep/AI-AGENT-TASK.md` — задание для AI

### Шаг 3: Используйте этот промпт

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
- DNS: 172.17.10.3, 8.8.8.8
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

### Шаг 4: Работайте с AI итеративно

**AI создаст 8 артефактов:**

1. `research/vm-template-prep/01-vm-requirements.md`
2. `research/vm-template-prep/02-create-vm-in-vsphere.md`
3. `research/vm-template-prep/03-convert-to-template.md`
4. `research/vm-template-prep/04-template-validation.md`
5. `research/vm-template-prep/05-troubleshooting.md`
6. `scripts/prepare-vm-template.sh`
7. `manifests/cloud-init/server-node.yaml`
8. `manifests/cloud-init/agent-node-01.yaml`
9. `manifests/cloud-init/agent-node-02.yaml`

**Ваши действия:**
- AI создаёт артефакт → Вы копируете и сохраняете в репозиторий
- Переходите к следующему артефакту
- Задавайте уточняющие вопросы AI если что-то непонятно

### Шаг 5: Примените инструкции на vSphere

После получения всех артефактов:

1. **Создайте VM в vSphere** (следуя `02-create-vm-in-vsphere.md`)
2. **SSH к VM** и выполните `scripts/prepare-vm-template.sh`
3. **Конвертируйте VM в Template** (следуя `03-convert-to-template.md`)
4. **Валидация** (следуя `04-template-validation.md`)

### Шаг 6: Сообщите Team Lead о результатах

После завершения сообщите:
- ✅ Что выполнено успешно
- ⚠️ Какие проблемы возникли (если были)
- 📋 Готовность к следующему этапу

---

## ✅ Критерии успеха

Задание выполнено когда:

- [x] Все 9 артефактов созданы и сохранены
- [x] VM Template создан в vSphere: `k3s-ubuntu2404-minimal-template`
- [x] Тестовое клонирование прошло успешно
- [x] Cloud-init работает (static IP, hostname, DNS)
- [x] SSH доступ к клонированной VM работает

---

## ⏱️ Оценка времени

- AI создание артефактов: **~20 минут**
- Применение на vSphere: **~25 минут**
- **Итого: ~45 минут**

---

## 🆘 Если возникли проблемы

1. Используйте `05-troubleshooting.md` от AI-агента
2. Задайте вопрос AI-агенту в том же чате
3. Свяжитесь с Team Lead

---

## 📊 Что дальше

После успешного создания VM Template:
- Team Lead создаст задание для **Этапа 1: k3s Server Node Setup**
- Вы будете устанавливать k3s на первую ноду
- Оценка времени: ~15 минут

---

**Удачи! Создавайте отличный VM Template! 🚀**

**Team Lead ждёт ваших результатов.**
