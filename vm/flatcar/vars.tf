

variable "pve_api_token" {
  description = "Proxmox API Token"
  type        = string
  sensitive   = true
}


variable "nodes" {
  
  type = map(object({
    type = string
    pvenode = string
    addr = string
    }))
  
  default = {
    cplane1 = {
      pvenode = "pve-7824af04dcdf",
      addr = "192.168.2.71/24",
      type = "cplane",
    },
    cplane2 = {
      pvenode = "pve-382c4a0f7540",
      addr = "192.168.2.72/24",
      type = "cplane",
    },
    cplane3 = {
      pvenode = "pve-7824af04dc40",
      addr = "192.168.2.73/24",
      type = "cplane",
    }
  }
}
