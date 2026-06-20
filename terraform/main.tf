terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.78"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_url
  username = var.proxmox_user
  password = var.proxmox_password
  insecure = true
}

resource "proxmox_virtual_environment_vm" "k8s" {
  for_each = var.vms

  name      = each.value.name
  node_name = each.value.node
  vm_id     = each.value.vmid

  cpu {
    cores = each.value.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = "local-lvm"
    size         = each.value.disk
    interface    = "scsi0"
    iothread     = true
    file_format  = "raw"
  }

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
  }

  operating_system {
    type = "l26"
  }

  clone {
    vm_id = var.template_vmid
  }

  initialization {
    ip_config {
      ipv4 {
        address = each.value.ip
        gateway = var.gateway
      }
    }
    user_account {
      username = var.vm_user
      keys     = [file(var.ssh_public_key_path)]
    }
  }

  lifecycle {
    ignore_changes = [disk, network_device]
  }
}

output "vm_ips" {
  value = { for k, v in var.vms : k => v.ip }
}
