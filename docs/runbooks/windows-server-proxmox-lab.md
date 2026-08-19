# Windows Server on Proxmox: Foundation Runbook

## Purpose

Reusable foundation procedure for a small Windows Server / Active Directory learning environment on Proxmox.

## Suggested lab baseline

| Resource | Domain controller candidate | Windows client |
| --- | ---: | ---: |
| vCPU | 2 | 2 |
| Memory | 6 GiB | 4 GiB |
| Disk | 60 GiB | 60 GiB |
| Disk bus | VirtIO SCSI | VirtIO SCSI |

Use thin provisioning only when the Proxmox thin pool is monitored. Keep backups off the same host/storage failure domain when possible.

## Install Windows with VirtIO

1. Attach the Windows Server ISO and a pinned VirtIO driver ISO.
2. Configure a Q35/UEFI VM with a VirtIO SCSI disk and VirtIO network adapter.
3. Boot the Windows installer.
4. At **Select location to install Windows Server**, choose **Load driver**.
5. Browse the driver ISO and select the SCSI driver matching the Windows Server release and architecture.
6. Continue only after the intended virtual disk appears.

## Install QEMU Guest Agent

Enable the Proxmox Guest Agent VM option, then run the dedicated MSI from the mounted VirtIO media:

```text
guest-agent\\qemu-ga-x86_64.msi
```

Validate in elevated PowerShell:

```powershell
Get-Service -Name QEMU-GA
```

Expected state: `Running`.

The Agent lets Proxmox discover the guest IP and request graceful shutdown/reboot. It does not enable RDP or make the guest faster.

## Enable RDP safely

```powershell
Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' `
  -Name fDenyTSConnections -Value 0

Get-NetFirewallRule -DisplayGroup 'Remote Desktop' |
  Set-NetFirewallRule -Enabled True
```

Test from an authorized workstation:

```powershell
Test-NetConnection <windows-server-ip> -Port 3389
```

Limit network access to TCP/3389 from a management subnet or, preferably, a named management workstation. Never publish RDP directly to the Internet.

## First-boot performance triage

High disk active time right after installation is commonly Windows Update, Defender, indexing, and component servicing. Before changing configuration:

1. Inspect the process using disk I/O in Task Manager.
2. Let initial updates complete and reboot once.
3. Confirm the VM is using VirtIO SCSI and that the host thin pool has free capacity.
4. Increase VM RAM only when sustained memory pressure is observed.

## AD DS prerequisites

Before domain promotion:

1. Rename the server and reboot.
2. Assign a stable address appropriate for the isolated lab network.
3. Set the server's own address as preferred DNS.
4. Install AD DS and DNS.
5. Use public DNS only as a DNS forwarder after AD DNS is running.
6. Create a client VM, join it to the domain, and validate DNS, logon, and Group Policy.
7. Back up and restore-test the domain controller VM.

## Evaluation lifecycle

Use evaluation media only for a time-boxed lab. Rebuild before it expires, or convert using a legitimate license before promoting the server to a domain controller. Microsoft documents that an evaluation domain controller cannot be converted in place to retail.
