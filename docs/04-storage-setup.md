# vSphere CSI Driver Setup для k3s

> **Статус:** ⏳ TODO
> **Ответственный:** AI-исполнитель + Оператор
> **Зависимости:** ✅ k3s кластер работает (Server + Agent)

---

## 🎯 Цель

Настроить **vSphere CSI Driver** для persistent storage в vSphere datastore. Это позволит создавать persistent volumes в vSphere для приложений.

---

## 📋 Процесс

### 1. Подготовка vSphere credentials

**Нужны:**
- vCenter URL
- vCenter username
- vCenter password
- Datacenter name
- Datastore name

### 2. Установка vSphere CSI Driver

**Манифесты** (в `manifests/vsphere-csi/`):
1. `vsphere-csi-secret.yaml` — credentials для vCenter
2. `vsphere-csi-driver.yaml` — CSI controller и node
3. `vsphere-storageclass.yaml` — StorageClass для использования

**Применение:**
```bash
kubectl apply -f manifests/vsphere-csi/vsphere-csi-secret.yaml
kubectl apply -f manifests/vsphere-csi/vsphere-csi-driver.yaml
kubectl apply -f manifests/vsphere-csi/vsphere-storageclass.yaml
```

### 3. Валидация

**Проверить CSI pods:**
```bash
kubectl get pods -n kube-system | grep vsphere-csi

# Должно быть:
# vsphere-csi-controller-xxx   5/5     Running
# vsphere-csi-node-xxx          3/3     Running (на каждой ноде)
```

**Проверить StorageClass:**
```bash
kubectl get storageclass

# Должно показать:
# vsphere-sc   csi.vsphere.vmware.com   ...
```

### 4. Тест PVC

**Создать тестовый PVC:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: vsphere-sc
  resources:
    requests:
      storage: 5Gi
```

**Проверить:**
```bash
kubectl apply -f test-pvc.yaml
kubectl get pvc

# Status должен быть: Bound
```

---

## 👉 Детальное задание для AI-агента

**AI-агент создаст:** `research/vsphere-csi-setup/AI-AGENT-TASK.md`

**Артефакты от AI-агента:**
1. vSphere CSI манифесты (secret, driver, storageclass)
2. Инструкции по настройке vCenter credentials
3. Процедуры установки CSI
4. Примеры PVC и Pod с volume
5. Troubleshooting guide

---

## ✅ Критерии завершения

- [ ] vSphere CSI Driver установлен
- [ ] CSI Controller pod работает
- [ ] CSI Node pods работают на всех нодах
- [ ] StorageClass создан
- [ ] Тестовый PVC создан и bound
- [ ] Тестовый Pod может монтировать volume
- [ ] Volume виден в vSphere datastore

---

## 🧪 Полный тест

**Pod с persistent volume:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: test-pvc
```

**Проверить:**
```bash
kubectl apply -f test-pod.yaml
kubectl exec test-pod -- df -h /data

# Должен показать смонтированный volume
```

---

**Следующий шаг:** [05-validation.md](./05-validation.md)
