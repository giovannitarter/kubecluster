terraform {
  required_providers {

    proxmox = {
      source = "bpg/proxmox"
      version = "0.83.0"
    }

    ct = {
      source  = "poseidon/ct"
      version = "0.13.0"
    }

  }
}

provider "proxmox" {

    endpoint = "https://pve1.lan:8006/"
    api_token = var.pve_api_token
    insecure = true

    ssh {
      username = "root"
      agent = false
      private_key = file("./secrets/id_terraform")
    }
}


provider "ct" {
}
