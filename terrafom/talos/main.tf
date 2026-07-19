



resource "proxmox_virtual_environment_vm" "talos_vms" {

  for_each = var.nodes
  name = each.key
  node_name = each.value.pvenode

  # should be true if qemu agent is not installed / enabled on the VM
  stop_on_destroy = true

  disk {
    datastore_id = "local-lvm"
    import_from  = proxmox_download_file.talos_image[each.value.pvenode].id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 10
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "virtio1"
    iothread     = true
    size         = 40
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

    # setting network device to solve vxlan packet drop
    # https://forum.proxmox.com/threads/kubernetes-overlay-networking-breaks-when-upgrading-from-pve-9-1-to-pve-9-2-3.183963/
    model = "e1000"

    firewall = false
    #link_down = false
  }

  memory {
    dedicated = each.value.mem
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
  talos_version = var.talos_version
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
  kube_version = var.kube_version
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


data "helm_template" "flux-operator" {
  name       = "flux"
  repository = "oci://ghcr.io/controlplaneio-fluxcd/charts/"
  chart      = "flux-operator"
  #version    = ""
  kube_version = var.kube_version
  namespace  = "flux-system"
  create_namespace = true
  set = []
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

    [
      file("${path.module}/files/disks.yaml"),
      file("${path.module}/files/prism.yaml"),
      file("${path.module}/files/drdb.yaml"),
    ],

    (
      each.value.type == "controlplane" ?
      [
        file("${path.module}/files/network.yaml"),
        file("${path.module}/files/cp-scheduling.yaml"),
        file("${path.module}/files/cni.yaml"),
        file("${path.module}/files/cilium-sa.yaml"),
        file("${path.module}/files/datastore.yaml"),

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


        yamlencode({
          cluster = {
            inlineManifests = [
              {
                name     = "flux-operator"
                contents = join("---\n", [
                  data.helm_template.flux-operator.manifest,
                  "",
                ])
              }
            ]
          }
        }),
        file("${path.module}/files/flux-github-secret.yaml"),
        file("${path.module}/files/flux-bootstrap.yaml"),


      ]
      : []
    ), # == "controlplane"

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
