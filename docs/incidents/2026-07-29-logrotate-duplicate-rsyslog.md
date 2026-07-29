# Incident Report - Logrotate Duplicate Rsyslog Entries

- **Date detected:** 2026-07-29
- **Severity:** Low
- **Status:** Resolved
- **Area:** Linux operations, systemd, log rotation

---

## Summary

A Kubernetes control-plane node showed `systemctl` state as `degraded` because `logrotate.service` failed.

The failure was caused by duplicate logrotate entries for system logs. A custom logrotate file attempted to rotate the same rsyslog-managed log files that were already handled by the default `rsyslog` logrotate configuration.

---

## Impact

- Host systemd state changed from `running` to `degraded`.
- `logrotate.service` failed on the timer run.
- No Kubernetes workload outage was observed.
- The issue still required remediation because failed log rotation can create future disk pressure.

---

## Symptoms

Observed patterns:

```text
systemctl status -> State: degraded
systemctl --failed -> logrotate.service failed
logrotate -> duplicate log entry
```

Duplicate entries were reported for:

```text
/var/log/syslog
/var/log/kern.log
/var/log/auth.log
```

---

## Root Cause

Two logrotate configurations managed the same files:

- a custom `k3s-logs` logrotate file,
- the default `rsyslog` logrotate file.

The custom file rotated generic system logs, not k3s-specific logs. This duplicated the default rsyslog configuration and caused `logrotate.service` to exit with failure.

---

## Fix Applied

Disabled the duplicate custom logrotate file by renaming it with a `.disabled` suffix:

```bash
sudo mv /etc/logrotate.d/k3s-logs /etc/logrotate.d/k3s-logs.disabled
```

The default `rsyslog` configuration remained active because it includes the proper post-rotate handling for rsyslog.

---

## Validation

Validated with:

```bash
sudo /usr/sbin/logrotate -v /etc/logrotate.conf
sudo /bin/systemctl start logrotate.service
sudo /bin/systemctl reset-failed logrotate.service
/bin/systemctl --failed
/bin/systemctl status --no-pager
df -h
```

Expected recovery evidence:

```text
Ignoring k3s-logs.disabled
0 loaded units listed
State: running
Failed: 0 units
root filesystem below disk pressure threshold
```

---

## Lessons Learned

- Avoid custom logrotate rules for logs that are already managed by distribution packages.
- Prefer the packaged `rsyslog` logrotate rule for `/var/log/syslog`, `/var/log/kern.log`, and `/var/log/auth.log`.
- A `systemctl degraded` state should be treated as an operational signal even if Kubernetes workloads are still running.
- Always validate a logrotate change with `logrotate -d` or `logrotate -v` before clearing failed systemd state.
- Shell `PATH` issues can hide system binaries; use full paths such as `/bin/systemctl` and `/usr/sbin/logrotate` during recovery.

---

## Follow-Up

- Fix shell `PATH` if `systemctl` is not found in a new login session.
- Keep this incident as a Linux operations troubleshooting example.
- Do not publish raw hostnames, internal paths beyond generic system paths, or full terminal output in public docs.
