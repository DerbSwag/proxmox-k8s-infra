# Incident Report — Proxmox apt update 401 Unauthorized

- **Date detected:** 2026-04-07
- **Severity:** Low (maintenance blocked, no service impact)
- **Status:** ✅ Resolved

---

## Summary

`apt-get update` บน Proxmox nodes (pve01, pve02) fail ด้วย **401 Unauthorized** จาก enterprise repository — เพราะไม่มี Proxmox subscription แต่ repo ยังชี้ไปที่ `enterprise.proxmox.com`

## Root Cause

Proxmox VE default install มาพร้อม enterprise repos (`pve-enterprise.sources`, `ceph.sources`) ที่ต้องมี valid subscription key ถ้าไม่มี subscription → apt return 401 ทุกครั้งที่ update

## Fix Applied

```bash
# ปิด enterprise repos
mv /etc/apt/sources.list.d/ceph.sources /etc/apt/sources.list.d/ceph.sources.disabled
mv /etc/apt/sources.list.d/pve-enterprise.sources /etc/apt/sources.list.d/pve-enterprise.sources.disabled

# ใช้ no-subscription repo แทน
# /etc/apt/sources.list.d/pve-no-subscription.list:
# deb http://download.proxmox.com/debian/pve trixie pve-no-subscription

apt-get update
```

ทำบนทั้ง pve01 (10.0.1.1) และ pve02 (10.0.1.2)

## Lessons Learned

- Proxmox fresh install ต้องปิด enterprise repos ทันทีถ้าไม่มี subscription
- เพิ่มขั้นตอนนี้ใน provisioning checklist / Ansible playbook สำหรับ Proxmox node ใหม่
- ไม่กระทบ service แต่ block security updates ถ้าไม่แก้
