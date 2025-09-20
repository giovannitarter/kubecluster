#!/usr/bin/env bash

set -e

# Set file paths
cert_dir="./certs"
output_yaml="butane/00_base-k8s-token.yaml"

# Create cert directory
mkdir -p "$cert_dir"

# Generate the token
token=$(echo "$(tr -dc 'a-z0-9' < /dev/urandom | head -c 6).$(tr -dc 'a-z0-9' < /dev/urandom | head -c 16)")
encoded_token=$(echo -n "$token" | base64)

# Generate Kubernetes CA (used for cluster signing)
openssl req -x509 -newkey rsa:2048 -keyout "$cert_dir/ca.key" -out "$cert_dir/ca.crt" -days 365 -nodes -subj "/CN=k8s-ca"

# Generate Front Proxy CA (used for API server aggregation)
openssl req -x509 -newkey rsa:2048 -keyout "$cert_dir/front-proxy-ca.key" -out "$cert_dir/front-proxy-ca.crt" -days 365 -nodes -subj "/CN=front-proxy-ca"

# Generate Service Account Signing Key
openssl genrsa -out "$cert_dir/sa.key" 2048
openssl rsa -in "$cert_dir/sa.key" -pubout -out "$cert_dir/sa.pub"

# Generate API server certificate (signed by Kubernetes CA)
openssl req -new -newkey rsa:2048 -keyout "$cert_dir/apiserver.key" -out "$cert_dir/apiserver.csr" -nodes -subj "/CN=kube-apiserver"
openssl x509 -req -in "$cert_dir/apiserver.csr" -CA "$cert_dir/ca.crt" -CAkey "$cert_dir/ca.key" -CAcreateserial -out "$cert_dir/apiserver.crt" -days 365

# Generate etcd CA (if using external etcd)
openssl req -x509 -newkey rsa:2048 -keyout "$cert_dir/etcd-ca.key" -out "$cert_dir/etcd-ca.crt" -days 365 -nodes -subj "/CN=etcd-ca"

indent="          "

# Encode certificates for YAML
ca_crt=$(sed "s/^/${indent}/" "$cert_dir/ca.crt")
ca_key=$(sed "s/^/${indent}/" "$cert_dir/ca.key")
front_proxy_ca_crt=$(sed "s/^/${indent}/" "$cert_dir/front-proxy-ca.crt")
front_proxy_ca_key=$(sed "s/^/${indent}/" "$cert_dir/front-proxy-ca.key")
sa_key=$(sed "s/^/${indent}/" "$cert_dir/sa.key")
sa_pub=$(sed "s/^/${indent}/" "$cert_dir/sa.pub")
etcd_ca_crt=$(sed "s/^/${indent}/" "$cert_dir/etcd-ca.crt")
etcd_ca_key=$(sed "s/^/${indent}/" "$cert_dir/etcd-ca.key")

# Compute CA hash
ca_hash="sha256:$(openssl x509 -pubkey -in "$cert_dir/ca.crt" | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')"
encoded_base64_ca_hash=$(echo -n "$ca_hash" | base64 -w 0)

# Write the header to the output YAML file
cat > "$output_yaml" <<-EOF
---
# This is generated using generate-k8s-certs.sh
variant: flatcar
version: 1.1.0
storage:
  files:
    - path: /etc/kubernetes/pki/ca.crt
      contents:
        inline: |
$ca_crt
    - path: /etc/kubernetes/pki/ca.key
      contents:
        inline: |
$ca_key
    - path: /etc/kubernetes/pki/front-proxy-ca.crt
      contents:
        inline: |
$front_proxy_ca_crt
    - path: /etc/kubernetes/pki/front-proxy-ca.key
      contents:
        inline: |
$front_proxy_ca_key
    - path: /etc/kubernetes/pki/sa.key
      contents:
        inline: |
$sa_key
    - path: /etc/kubernetes/pki/sa.pub
      contents:
        inline: |
$sa_pub
    - path: /etc/kubernetes/pki/etcd/ca.crt
      contents:
        inline: |
$etcd_ca_crt
    - path: /etc/kubernetes/pki/etcd/ca.key
      contents:
        inline: |
$etcd_ca_key
    - path: /etc/kubernetes/certs.conf
      contents:
        inline: |
            K8S_TOKEN='$token'
            K8S_HASH='$ca_hash'
EOF

echo "Kubernetes certificates have been generated successfully!"
echo "YAML file '$output_yaml' has been successfully overwritten!"
