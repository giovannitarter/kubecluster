

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
    }))

  default = {
    cplane1 = {
      type = "cplane-master",
      pvenode = "pve-7824af04dcdf",
      addr = "192.168.2.71",
      cird = "24",
      priority = 101
    },
    cplane2 = {
      type = "cplane",
      pvenode = "pve-382c4a0f7540",
      addr = "192.168.2.72",
      cird = "24",
      priority = 100
    },
    cplane3 = {
      type = "cplane",
      pvenode = "pve-7824af04dc40",
      addr = "192.168.2.73",
      cird = "24",
      priority = 99
    }
  }
}
