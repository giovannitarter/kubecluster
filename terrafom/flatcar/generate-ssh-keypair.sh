#!/usr/bin/env bash

set -e

# Set file paths
out_dir="./ssh"
output_yaml="butane/61_github_keypair.yml"

# Create cert directory
mkdir -p "$out_dir"

pushd "$out_dir"
ssh-keygen -t ed25519 -f github -N ""
popd


kread() {
    indent="          "
    sed "s/^/${indent}/" "$1"
}

# Encode certificates for YAML
key1="$(kread ${out_dir}/github)"
key2="$(kread ${out_dir}/github.pub)"


# Write the header to the output YAML file
cat > "$output_yaml" <<-EOF
---
# This is generated using $(basename "$0")
variant: flatcar
version: 1.1.0
storage:
  files:

    - path: /home/core/.ssh/id_github
      contents:
        inline: |
$key1
      mode: 0600
      user:
        id: 500
      group:
        id: 500


    - path: /home/core/.ssh/id_github.pub
      contents:
        inline: |
$key2
      mode: 0600
      user:
        id: 500
      group:
        id: 500
EOF

echo "flatcar ssh github keypair has been generated successfully!"
echo "YAML file '$output_yaml' has been successfully overwritten!"
