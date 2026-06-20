# Sealed Secrets

Sealed Secrets ช่วยให้เก็บ Kubernetes Secrets ใน Git ได้อย่างปลอดภัย โดยเข้ารหัสด้วย public key ของ cluster

## วิธีใช้

### 1. สร้าง Secret แบบปกติ (dry-run)
```bash
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=my-password \
  --dry-run=client -o yaml > my-secret.yaml
```

### 2. Seal ด้วย kubeseal
```bash
kubeseal --kubeconfig /etc/rancher/k3s/k3s.yaml \
  --format yaml < my-secret.yaml > my-sealed-secret.yaml
```

### 3. Apply SealedSecret
```bash
kubectl apply -f my-sealed-secret.yaml
```

Controller จะ decrypt และสร้าง Secret จริงให้อัตโนมัติ

### 4. Commit SealedSecret ขึ้น Git ได้เลย
```bash
git add my-sealed-secret.yaml
git commit -m "feat: add sealed secret"
```

## หมายเหตุ
- ไฟล์ `my-secret.yaml` (plaintext) **ห้าม commit** ขึ้น Git
- ไฟล์ `my-sealed-secret.yaml` (encrypted) commit ได้ปลอดภัย
- SealedSecret ผูกกับ cluster — ย้ายไป cluster อื่นต้อง seal ใหม่
