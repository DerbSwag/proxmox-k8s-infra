# Incident: pve02 host hardware instability (flapping)

**Date:** 2026-06-17 → 2026-06-19 (ongoing — watch)
**Severity:** High (host-level; affects worker-02 + pve02 monitoring)
**Status:** OPEN — pve02 back up but unstable; physical hardware check needed

## Symptoms
pve02 (10.0.1.2) has gone down/up multiple times over 2+ days:
- 2026-06-17: host hang (ping/SSH/web 8006 all dead)
- 2026-06-18~19: flapping — ping OK but SSH(22)/web(8006)/zabbix(10050) dead, then full
  down (100% ping loss), then back
- 2026-06-19 ~16:30: recovered (uptime 1 min = power-cycled at the machine)

Each downtime takes with it: k8s-worker-02 (VM 210) → NotReady, pve02+worker-02 Zabbix
agents → down, Proxmox cluster loses quorum (Nodes 1/2).

## Impact
- k8s tolerated it — workloads ran on master+worker-01; Vault/Zabbix/Prometheus/Grafana/
  CoreDNS stayed up. Brief churn/alert burst on each transition (now readable thanks to
  the summary + inhibit alerts: SingleNodeDown/KubeNodeNotReady fire once then resolve).
- Proxmox cluster non-quorate while pve02 down → VM management blocked on pve01 until
  quorum returns. Workaround: `pvecm expected 1` on pve01.

## Likely cause
Pattern (ping-but-services-dead → full down → recurring across full power cycles) points
to **hardware**, not software: RAM errors, failing disk, PSU, or overheating.

## Action items (at the physical machine — cannot be done over network)
1. Check chassis LEDs / attach monitor — RAM/disk error LEDs, kernel panic, POST errors,
   fan/thermal warnings.
2. BIOS → hardware health (temps, voltages, fan RPM, memory status).
3. memtest86 (RAM) + SMART long test on disk(s).
4. Reseat RAM and power/data cables; clean dust / check cooling.
5. After a crash, check kernel log for hardware errors:
   `journalctl -k -b -1 | grep -iE "mce|hardware error|thermal|ECC|ATA|I/O error"`

## Interim mitigation
- If pve02 stays flaky: cordon worker-02 when it's down; keep critical/stateful pods off it.
- If pve02 must stay down: `pvecm expected 1` on pve01 to keep VM management working.
- VMs have `onboot=1` → worker-02 auto-starts when pve02 recovers.
- ⚠️ worker-02 VM (210) backups live on pve02 local disk — if the disk is the failing
  part, copy VM 210 backup to pve01 / external storage ASAP.

## Notes
- Separate from the netplan host-port issue (resolved 2026-06-17).

## Diagnostics gathered 2026-06-19 (while pve02 online)
Collected via SSH before any physical work:

| Check | Result | Verdict |
|-------|--------|---------|
| SMART `/dev/sda` (WDC WDS240G2G0A 240G SSD) | PASSED | disk OK |
| Thermal zones | 27 / 40 / 39 °C | cooling OK (not overheating) |
| Kernel log (this + prev boot) | no MCE / machine-check / I/O / ATA errors | no captured HW fault in-OS |
| Filesystem | no unexpected read-only mounts | no FS corruption |
| RAM | `EDAC ie31200: No ECC support` (non-ECC) | RAM errors CANNOT be seen by OS → needs memtest |
| `journalctl --list-boots` | **every boot starts at `2025-09-04 01:38:20`** | ⚠️ RTC/clock resets → likely **dead CMOS battery** |

### Interpretation
- Disk, thermal, FS ruled out (healthy).
- The repeated identical boot timestamp (`2025-09-04`) = the RTC is not keeping time →
  **CMOS coin-cell (CR2032) likely flat.** A flat CMOS battery can cause BIOS settings
  to reset and contribute to boot instability.
- RAM is non-ECC, so silent bit errors won't show in the OS — given the flapping,
  **RAM is still the #1 suspect** and must be tested with memtest86.

### Recommended physical actions (in order)
1. **Replace CMOS battery (CR2032)** — cheap/fast; fixes the wrong clock and often boot flakiness.
2. **Run memtest86 overnight** — non-ECC RAM + flapping → prime suspect.
3. **Swap/test PSU** if a spare is available — sudden full power-loss flaps are often PSU.
4. **Reseat RAM + power/SATA cables**; clear dust.

(After replacing CMOS battery, set correct time in BIOS and verify `timedatectl` /
that NTP is syncing on pve02.)
