locals {
  factory_url = "https://factory.talos.dev"

  platform = "nocloud"
  arch     = "amd64"
  version  = var.talos_version
  schematic = file("${path.module}/image/schematic.yaml")

  schematic_id = jsondecode(data.http.schematic_id.response_body)["id"]
  image_id     = "${local.schematic_id}_${local.version}"
}


data "http" "schematic_id" {
  url          = "${local.factory_url}/schematics"
  method       = "POST"
  request_body = local.schematic
}


resource "proxmox_download_file" "talos_image" {

  #for_each = var.nodes
  for_each = toset(distinct([for k, v in var.nodes : "${v.pvenode}"]))
  node_name = each.value

  #for_each = var.nodes
  #node_name = each.value.pvenode

  content_type = "import"
  datastore_id = "local"
  url = "https://factory.talos.dev/image/${local.schematic_id}/${local.version}/${local.platform}-${local.arch}.qcow2"
  file_name = "talos-${local.schematic_id}-${local.version}-${local.platform}-${local.arch}.qcow2"
  overwrite = true
}
