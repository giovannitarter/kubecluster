

resource "proxmox_virtual_environment_download_file" "flatcar_image" {

  for_each = var.nodes

  content_type = "import"
  datastore_id = "local"
  node_name = each.value.pvenode
  url          = "https://stable.release.flatcar-linux.net/amd64-usr/current/flatcar_production_proxmoxve_image.img"
  overwrite    = false
  file_name = "flatcar_stable.qcow2"
}


# 00000_flatcar_specs.yml
# 0000_hostname.yml
# 0000_users.yml
# 00_base-k8s-token.yaml
# 00_base-k8s.yml
# 10_base-ha.yml
# 20_keepalived.yml
# 21_haproxy.yml
# 30_start-k8s.yml


data "ct_config" "cplane-node" {

  for_each = var.nodes

  content      = file("./butane/00000_flatcar_specs.yml")
  strict       = true
  pretty_print = true

  snippets = [

    templatefile(
      "./butane/0000_hostname.yml", {
        k8s_vip = var.k8s_vip,
        hostname = each.key,
      }
    ),

    file("./butane/0000_users.yml"),
    file("./butane/00_base-k8s-token.yml"),
    file("./butane/00_base-k8s.yml"),

    templatefile(
      "./butane/10_base-ha.yml", {
        k8s_vip = var.k8s_vip,
      }
    ),
    templatefile(
      "./butane/20_keepalived.yml", {
        k8s_vip = "${var.k8s_vip}/${var.k8s_vip_cird}",
        vrrp_state = "MASTER",
        priority = each.value.priority
      }
    ),
    templatefile(
      "./butane/21_haproxy.yml", {
        k8s_vip = var.k8s_vip,
        cpnodes = [ for k, val in var.nodes:
          {
            name = k,
            ip = val.addr,
            port = 6443,
          }
        ]
      }
    ),

    (
      each.value.priority == 101 ?
      templatefile(
        "./butane/30_start-k8s.yml", {
          k8s_vip = var.k8s_vip,
          perform_init = "true",
        }
      ) 
      : 
      templatefile(
        "./butane/31_cpnode-join.yml", {
        }
      )
    ),
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
          address = "${each.value.addr}/${each.value.cird}"
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
