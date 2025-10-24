# Cluster Validation

> **Статус:** ⏳ TODO
> **Ответственный:** AI-исполнитель + Оператор
> **Зависимости:** ✅ k3s кластер + vSphere CSI установлены

---

## 🎯 Цель

Комплексная проверка что k3s кластер полностью работоспособен и готов к использованию.

---

## ✅ Чек-лист валидации

### 1. Базовый кластер

```bash
# Все ноды Ready
kubectl get nodes
# Должно быть: 3 ноды, все Ready

# Системные поды работают
kubectl get pods -A
# Все поды в состоянии Running
```

### 2. Встроенные компоненты k3s

**Traefik Ingress:**
```bash
kubectl get pods -n kube-system | grep traefik
# traefik-xxx   Running
```

**CoreDNS:**
```bash
kubectl get pods -n kube-system | grep coredns
# coredns-xxx   Running
```

**ServiceLB:**
```bash
kubectl get pods -n kube-system | grep svclb
# Будут созданы при создании LoadBalancer service
```

### 3. vSphere CSI

```bash
# CSI pods
kubectl get pods -n kube-system | grep vsphere-csi

# StorageClass
kubectl get sc
```

### 4. Тестовое приложение

**Deployment:**
```bash
kubectl create namespace test
kubectl create deployment nginx --image=nginx --replicas=3 -n test
kubectl get pods -n test -o wide
```

**Service (LoadBalancer):**
```bash
kubectl expose deployment nginx --port=80 --type=LoadBalancer -n test
kubectl get svc -n test

# Должен получить EXTERNAL-IP
```

**Ingress:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-ingress
  namespace: test
spec:
  rules:
  - host: test.k3s.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx
            port:
              number: 80
```

```bash
kubectl apply -f test-ingress.yaml
kubectl get ingress -n test
```

### 5. Persistent Storage

**PVC:**
```bash
kubectl apply -f manifests/examples/test-pvc.yaml
kubectl get pvc -n test
# Status: Bound
```

**Pod с PVC:**
```bash
kubectl apply -f manifests/examples/test-pod-with-pvc.yaml
kubectl exec -n test test-pod -- df -h /data
```

---

## 👉 Детальное задание для AI-агента

**AI-агент создаст:** `research/validation/AI-AGENT-TASK.md`

**Артефакты от AI-агента:**
1. Скрипт `scripts/validate-cluster.sh` — автоматическая валидация
2. Примеры приложений в `manifests/examples/`
3. Подробный troubleshooting guide
4. Процедуры тестирования каждого компонента
5. Финальная документация кластера

---

## 🔧 Автоматическая валидация

**Скрипт `validate-cluster.sh` должен проверять:**
- Все ноды Ready
- Все системные поды Running
- Traefik работает
- ServiceLB работает
- vSphere CSI работает
- Можно создать Deployment
- Можно создать LoadBalancer service
- Можно создать Ingress
- Можно создать PVC и смонтировать в Pod

**Запуск:**
```bash
./scripts/validate-cluster.sh
```

---

## ✅ Критерии завершения

- [ ] Все ноды в состоянии Ready
- [ ] Все системные поды работают
- [ ] Traefik принимает ingress трафик
- [ ] ServiceLB раздаёт LoadBalancer IPs
- [ ] vSphere CSI создаёт persistent volumes
- [ ] Тестовое приложение развёрнуто и доступно
- [ ] Troubleshooting guide создан
- [ ] Скрипт валидации работает

---

## 🎉 Успех!

**Если все критерии выполнены:**

✅ **k3s кластер полностью работоспособен!**

**Можно:**
- Развёртывать приложения
- Использовать persistent storage
- Использовать ingress для HTTP routing
- Использовать LoadBalancer services

**Время от начала:** ~1.5 часа (vs 4+ часов для полного k8s)

---

**Следующие шаги:**
- Развёртывание реальных приложений
- Настройка мониторинга (optional)
- Настройка backup (optional)
- Планирование production кластера (3 server ноды для HA)
