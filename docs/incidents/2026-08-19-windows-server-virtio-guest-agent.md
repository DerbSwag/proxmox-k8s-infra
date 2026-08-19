# Windows Server foundation: VirtIO driver and Guest Agent validation

## Summary

A Windows Server evaluation VM was prepared on a third Proxmox cluster node as the foundation for an isolated Active Directory lab. Windows Setup initially did not list the virtual disk, and Proxmox later reported that the Guest Agent was not running.

## Root Cause

Windows installation media does not include VirtIO SCSI drivers. The QEMU Guest Agent is also a separate Windows component: mounting the VirtIO ISO or launching a broad tools installer is not evidence that the agent service is installed.

## Resolution

1. Mounted a Windows Server ISO and a current, known-good VirtIO driver ISO.
2. At the disk-selection screen, loaded the VirtIO SCSI driver appropriate for the Windows Server release.
3. Installed the QEMU Guest Agent using the dedicated MSI from the VirtIO ISO.
4. Enabled RDP and validated reachability from the approved management network.
5. Increased memory after observing normal first-boot servicing pressure.

## Verification

```powershell
Get-Service -Name QEMU-GA
```

Expected result: the `QEMU-GA` service is running. Then refresh the Proxmox VM summary and confirm the Guest Agent warning has cleared.

## Lessons

- A missing disk during Windows setup often indicates a storage-driver gap, not a missing virtual disk.
- Verify a Windows service by name after installation rather than relying on an installer window alone.
- Windows update and Defender activity can temporarily create high disk active time; distinguish I/O activity from storage capacity pressure.
- Guest Agent supports IP reporting and graceful lifecycle operations; it is not a remote-access or performance feature.

## Public-safety note

This incident intentionally omits VM IDs, addresses, hostnames, credentials, network layout, and screenshots.
