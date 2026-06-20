variable "proxmox_url" {
  default = "https://10.0.1.95:8006"
}

variable "proxmox_user" {
  default = "root@pam"
}

variable "proxmox_password" {
  sensitive = true
}

variable "template_vmid" {
  description = "VM template ID to clone from"
  default     = 9000
}

variable "gateway" {
  default = "10.0.1.1"
}

variable "vm_user" {
  default = "devops"
}

variable "ssh_public_key_path" {
  default = "~/.ssh/id_ed25519.pub"
}

variable "vms" {
  type = map(object({
    name   = string
    node   = string
    vmid   = number
    cores  = number
    memory = number
    disk   = number
    ip     = string
  }))

  default = {
    master = {
      name   = "k8s-master"
      node   = "pve01"
      vmid   = 200
      cores  = 2
      memory = 4096
      disk   = 50
      ip     = "10.0.1.140/24"
    }
    worker-01 = {
      name   = "k8s-worker-01"
      node   = "pve01"
      vmid   = 201
      cores  = 2
      memory = 4096
      disk   = 50
      ip     = "10.0.1.141/24"
    }
    worker-02 = {
      name   = "k8s-worker-02"
      node   = "pve02"
      vmid   = 210
      cores  = 2
      memory = 4096
      disk   = 50
      ip     = "10.0.1.142/24"
    }
    linux-lab = {
      name   = "linux-lab"
      node   = "pve01"
      vmid   = 101
      cores  = 2
      memory = 2048
      disk   = 32
      ip     = "10.0.1.144/24"
    }
  }
}
