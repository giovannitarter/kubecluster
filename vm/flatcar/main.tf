

locals {

  hanodes = flatten([
    for k, val in var.nodes:
      contains(["cplane-master", "cplane"], val.type) ?
      [k]
      :
      []
    ]
  )

  hanodes_conf = [
    for k in local.hanodes:
    {
      name = k,
      ip = var.nodes[k].addr,
      port = 6443,
    }
  ]

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

  content      = file("./butane/00000_flatcar_specs.yml")
  strict       = true
  pretty_print = true

  snippets = flatten([

    templatefile(
      "./butane/0000_hostname.yml", {
        k8s_vip = var.k8s_vip,
        hostname = each.key,
      }
    ),

    templatefile(
      "./butane/0001_ssh_hostkeys.yml", {
        hostname = each.key,
      }
    ),

    file("./butane/0002_users.yml"),

    file("./butane/00_base-k8s-token.yml"),
    file("./butane/00_base-k8s.yml"),

    templatefile(
      "./butane/10_base-ha.yml", {
        k8s_vip = var.k8s_vip,
      }
    ),

    (
      contains(local.hanodes, each.key) ?
      [

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
            cpnodes = local.hanodes_conf
          }
        ),
      ]
      :
      []
    ),

    (
      each.value.type == "cplane-master" ?
      [
      templatefile(
        "./butane/30_cplane-master.yml", {
        }
      )
      ]
      : []
    ),

    (
      each.value.type == "cplane" ?
      [
      templatefile(
        "./butane/31_cpnode-join.yml", {
        }
      )
      ]
      : []
    ),

    (
      each.value.type == "worker" ?
      [
        templatefile(
          "./butane/32_worker-join.yml", {
          }
        )
      ]
      : []
    ),

  ])
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
    mac_address = each.value.mac
  }

  memory {
    dedicated = each.value.mem != null ? each.value.mem : 4096
  }


  initialization {

    dns {
      domain = ".lan"
      servers = ["192.168.2.1"]
    }

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
