
output "vms_ipv4_address" {
  value = {
    for k, val in proxmox_virtual_environment_vm.talos_vms: k => val.ipv4_addresses[7]
  }
}

output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}
