
resource "proxmox_download_file" "talos_image" {

  for_each = var.nodes
  node_name = each.value.pvenode

  content_type       = "import"
  datastore_id       = "local"
  file_name          = "metal-amd64.qcow2"
  url                = "https://factory.talos.dev/image/579da0b3ef926f44676438f6dc74ef3fb2588d561ad0377752e42a0bd4373657/v1.13.4/metal-amd64.qcow2"
  #checksum           = ""
  #checksum_algorithm = "sha512"
}



resource "proxmox_virtual_environment_vm" "talos_vms" {

  for_each = var.nodes
  name = each.key
  node_name = each.value.pvenode

  # should be true if qemu agent is not installed / enabled on the VM
  stop_on_destroy = false

  disk {
    datastore_id = "local-lvm"
    import_from  = proxmox_download_file.talos_image[each.key].id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 10
  }

  agent {
    enabled = true
  }

  cpu {
    cores = 2
    type         = "x86-64-v2-AES"
  }

  network_device {
    bridge = "vmbr0"
    mac_address = each.value.mac
  }

  memory {
    dedicated = 2048
    floating = 0
  }


  # initialization {

  #   #user_data_file_id = proxmox_virtual_environment_file.sat1_cloudconfig.id

  #   user_account {
  #     # do not use this in production, configure your own ssh key instead!
  #     username = "debian"
  #   }

  #   dns {
  #     domain = ".lan"
  #     servers = ["192.168.2.1"]
  #   }

  #   ip_config {
  #     ipv4 {
  #         address = "192.168.2.81/24"
  #         gateway = "192.168.2.1"
  #     }
  #   }
  # }
}

resource "talos_machine_secrets" "this" {
  talos_version = "v1.13.4"
}


data "talos_machine_configuration" "this" {

  for_each = var.nodes
  cluster_name     = var.cluster_name
  cluster_endpoint = var.cluster_endpoint
  machine_type     = each.value.type
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}


data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for k, v in var.nodes : v.addr if v.type == "controlplane"]
}


data "helm_template" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = "1.19.5"
  kube_version = "1.36.0"
  namespace  = "kube-system"

  set = [
    {
      name  = "ipam.mode"
      value = "kubernetes"
    },
    {
      name  = "kubeProxyReplacement"
      value = "true"
    },
    {
      name  = "securityContext.capabilities.ciliumAgent"
      value = "{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}"
    },
    {
      name  = "securityContext.capabilities.cleanCiliumState"
      value = "{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}"
    },
    {
      name  = "cgroup.autoMount.enabled"
      value = "false"
    },
    {
      name  = "cgroup.hostRoot"
      value = "/sys/fs/cgroup"
    },
    {
      name  = "k8sServiceHost"
      value = "localhost"
    },
    {
      name  = "k8sServicePort"
      value = "7445"
    }
  ]
}

resource "talos_machine_configuration_apply" "this" {
  depends_on = [proxmox_virtual_environment_vm.talos_vms]

  for_each                    = var.nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration
  node                        = each.value.addr

  config_patches = flatten(
  [

    templatefile("${path.module}/templates/install-disk-and-hostname.yaml.tmpl", {
      hostname     = each.key
      install_disk = "/dev/vda"
    }),

    (
      each.value.type == "controlplane" ?
      [
        file("${path.module}/files/cp-scheduling.yaml"),
        file("${path.module}/files/cni.yaml"),

        file("${path.module}/files/cilium-sa.yaml"),
        yamlencode({
          cluster = {
            inlineManifests = [
              {
                name     = "cilium"
                contents = join("---\n", [
                  data.helm_template.cilium.manifest,
                  "",
                ])
              }
            ]
          }
        }),

      ]
      : []
    ),
  ]
  )
}


resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = [for k, v in var.nodes : v.addr if v.type == "controlplane"][0]
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = [for k, v in var.nodes : v.addr if v.type == "controlplane"][0]
}
