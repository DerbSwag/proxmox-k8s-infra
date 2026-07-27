# Incident: linux-lab VM DNS (UDP 53) Blocked

**Date:** 2026-05-23
**Severity:** Medium
**Status:** Mitigated

## Summary

VM `linux-lab` (192.0.2.20) ไม่สามารถ resolve DNS ผ่าน UDP port 53 ได้อย่าง stable ทำให้ Docker pull image timeout

## Symptoms

- `ping 8.8.8.8` — 100% packet loss
- `ping 1.1.1.1` — OK
- `nslookup` ไป 1.1.1.1 — timeout 2 ครั้งก่อนได้ผล
- Docker build/pull timeout เพราะ DNS resolve ล้มเหลว
- `curl https://registry-1.docker.io/v2/` — OK (ใช้ cached DNS)

## Root Cause

Gateway/firewall appliance firewall อาจ:
1. Block ICMP/UDP ไป 8.8.8.8 จาก IP ใหม่ที่ไม่อยู่ใน allow list
2. Rate limit UDP 53 outbound
3. Policy ยังไม่ครอบคลุม 192.0.2.20

## Mitigation

```bash
# Disable systemd-resolved (override DNS)
sudo systemctl disable --now systemd-resolved
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf

# Docker daemon DNS
echo '{"dns": ["1.1.1.1"]}' | sudo tee /etc/docker/daemon.json
sudo systemctl restart docker
```

## TODO

- [ ] เพิ่ม 192.0.2.20 ใน firewall appliance allow policy สำหรับ DNS + HTTPS outbound
- [ ] ตั้ง local DNS server (BIND9 on k8s) เป็น forwarder แทน
