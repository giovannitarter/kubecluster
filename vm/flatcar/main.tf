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




resource "proxmox_virtual_environment_download_file" "flatcar_image" {
  
  for_each = var.nodes

  content_type = "import"
  datastore_id = "local"
  node_name = each.value.pvenode
  url          = "https://stable.release.flatcar-linux.net/amd64-usr/current/flatcar_production_proxmoxve_image.img"
  overwrite    = false
  file_name = "flatcar_stable.qcow2"
}


data "ct_config" "cplane-node" {
  
  for_each = var.nodes
  
  content      = file("./config_cplane/cplane.yml")
  strict       = true
  pretty_print = true

  snippets = [

    templatefile("./config_cplane/hostname.yml", {
      hostname = each.key
    }
    ),

    file("./config_cplane/users.yml"),
    file("./config_cplane/kubernetes.yml"),
    file("./config_cplane/cilium.yml"),
  ]
}


resource "proxmox_virtual_environment_file" "cplane_config" {
  
  for_each = var.nodes
  node_name = each.value.pvenode
  
  content_type = "snippets"
  datastore_id = "local"
  
  source_raw {
    data = data.ct_config.cplane-node[each.key].rendered
    file_name = "flatcar_config_${each.key}.yaml"
  }
}


resource "proxmox_virtual_environment_vm" "flatcar_vm" {
  
  for_each = var.nodes
  name      = each.key
  node_name = each.value.pvenode

  # should be true if qemu agent is not installed / enabled on the VM
  stop_on_destroy = true

  disk {
    datastore_id = "local-lvm"
    import_from  = proxmox_virtual_environment_download_file.flatcar_image[each.key].id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 20
  }
  
  agent {
    enabled = true
  }

  cpu {
    cores = 2
  }

  network_device {
    bridge = "vmbr0"
  }

  memory {
    dedicated = 4096
  }


  initialization {
    ip_config {
      ipv4 {
          address = each.value.addr
          gateway = "192.168.2.1"
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.cplane_config[each.key].id
  }
}


output "vms_ipv4_address" {
  value = {
    for k, val in proxmox_virtual_environment_vm.flatcar_vm: k => val.ipv4_addresses[1][0]
  }
}

