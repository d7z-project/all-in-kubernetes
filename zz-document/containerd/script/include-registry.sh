#!/usr/bin/env bash
sed -i 's@config_path = ""@config_path = "/etc/containerd/certs.d"@g' /etc/containerd/config.toml
ALIAS_LIST=(
    "docker.io"
    "registry.gitlab.com"
    "quay.io"
    "k8s.gcr.io"
    "registry.k8s.io"
    "ghcr.io"
)

replace_host="registry.internal.{{var.global.public.host}}"

mkdir -p /etc/containerd/certs.d/ /etc/containerd/certs.d/$replace_host
cat << EOF | tee "/etc/containerd/certs.d/$replace_host/hosts.toml" >/dev/null
server = "https://$url"

[host."https://$replace_host"]
  capabilities = ["pull", "resolve"]
  skip_verify = true

EOF

for url in "${ALIAS_LIST[@]}"; do
    current_directory="/etc/containerd/certs.d/$url"
    current_config_path="$current_directory/hosts.toml"
    mkdir -p "$current_directory"
    cat <<EOF | tee "$current_config_path" >/dev/null
server = "https://$url"

[host."https://$replace_host"]
  capabilities = ["pull", "resolve"]
  skip_verify = true

EOF
done
systemctl restart containerd
