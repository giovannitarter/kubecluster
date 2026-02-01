#!/usr/bin/env bash

set -e

# Set file paths
cert_dir="./certs"
output_yaml="butane/0001_ssh_hostkeys.yml"

# Create cert directory
mkdir -p "$cert_dir"
mkdir -p "$cert_dir/etc/ssh"
ssh-keygen -A -f "$cert_dir"


kread() {
    indent="          "
    sed "s/^/${indent}/" "$1"
}

# Encode certificates for YAML
key1="$(kread ./certs/etc/ssh/ssh_host_ed25519_key.pub)"
key2="$(kread ./certs/etc/ssh/ssh_host_ecdsa_key)"
key3="$(kread ./certs/etc/ssh/ssh_host_ecdsa_key.pub)"
key4="$(kread ./certs/etc/ssh/ssh_host_ed25519_key)"
key5="$(kread ./certs/etc/ssh/ssh_host_rsa_key.pub)"
key6="$(kread ./certs/etc/ssh/ssh_host_rsa_key)"


# Write the header to the output YAML file
cat > "$output_yaml" <<-EOF
---
# This is generated using generate-k8s-certs.sh
variant: flatcar
version: 1.1.0
storage:
  files:

    - path: /etc/ssh/ssh_host_ed25519_key.pub
      contents:
        inline: |
$key1
      mode: 0644
      user:
        id: 0
      group:
        id: 0


    - path: /etc/ssh/ssh_host_ed25519_key
      contents:
        inline: |
$key2
      mode: 0600
      user:
        id: 0
      group:
        id: 0


    - path: /etc/ssh/ssh_host_ecdsa_key.pub
      contents:
        inline: |
$key3
      mode: 0644
      user:
        id: 0
      group:
        id: 0


    - path: /etc/ssh/ssh_host_ecdsa_key
      contents:
        inline: |
$key4
      mode: 0600
      user:
        id: 0
      group:
        id: 0


    - path: /etc/ssh/ssh_host_rsa_key.pub
      contents:
        inline: |
$key5
      mode: 0644
      user:
        id: 0
      group:
        id: 0


    - path: /etc/ssh/ssh_host_rsa_key
      contents:
        inline: |
$key6
      mode: 0600
      user:
        id: 0
      group:
        id: 0
EOF

echo "flatcar ssh host key have benne generated successfully!"
echo "YAML file '$output_yaml' has been successfully overwritten!"
