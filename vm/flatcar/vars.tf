

variable "pve_api_token" {
  description = "Proxmox API Token"
  type        = string
  sensitive   = true
}


variable "k8s_vip" {
  description = "Kubernetes Virtual IP"
  type = string
  default = "192.168.2.70"
}

variable "k8s_vip_cird" {
  description = "Kubernetes Virtual IP CIRD"
  type = string
  default = "24"
}


variable "nodes" {

  type = map(object({
    type = string
    pvenode = string
    addr = string
    cird = string
    priority = number
    mac = string
    mem = optional(number)
    }))

  default = {
    cplane1 = {
      type = "cplane-master",
      pvenode = "pve-7824af04dcdf",
      addr = "192.168.2.71",
      cird = "24",
      priority = 101
      mac = "bc:24:11:02:4d:01"
    },
    cplane2 = {
      type = "cplane",
      pvenode = "pve-382c4a0f7540",
      addr = "192.168.2.72",
      cird = "24",
      priority = 100
      mac = "bc:24:11:02:4d:02"
    },
    cplane3 = {
      type = "cplane",
      pvenode = "pve-7824af04dc40",
      addr = "192.168.2.73",
      cird = "24",
      priority = 99
      mac = "bc:24:11:02:4d:03"
    }
    worker4 = {
      type = "worker",
      pvenode = "pve-7824af04dcdf",
      addr = "192.168.2.74",
      cird = "24",
      priority = 91
      mac = "bc:24:11:02:4d:04"
      mem = 2048,
    },
    worker5 = {
      type = "worker",
      pvenode = "pve-382c4a0f7540",
      addr = "192.168.2.75",
      cird = "24",
      priority = 90
      mac = "bc:24:11:02:4d:05"
      mem = 2048,
    },
    worker6 = {
      type = "worker",
      pvenode = "pve-7824af04dc40",
      addr = "192.168.2.76",
      cird = "24",
      priority = 89
      mac = "bc:24:11:02:4d:06",
      mem = 2048,
    },
    worker7 = {
      type = "worker",
      pvenode = "pve-7824af04dcdf",
      addr = "192.168.2.77",
      cird = "24",
      priority = 88
      mac = "bc:24:11:02:4d:07",
      mem = 2048,
    },
    worker8 = {
      type = "worker",
      pvenode = "pve-382c4a0f7540",
      addr = "192.168.2.78",
      cird = "24",
      priority = 87
      mac = "bc:24:11:02:4d:08",
      mem = 2048,
    },
    worker9 = {
      type = "worker",
      pvenode = "pve-7824af04dc40",
      addr = "192.168.2.79",
      cird = "24",
      priority = 86
      mac = "bc:24:11:02:4d:09"
      mem = 2048,
    },
  }
}
