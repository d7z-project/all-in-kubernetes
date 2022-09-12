#!/usr/bin/env bash
sed -i 's@config_path = ""@config_path = "/etc/containerd/certs.d"@g' /etc/containerd/config.toml
ALIAS_LIST=(
    "docker.io"
    "registry.gitlab.com"
    "quay.io"
    "k8s.gcr.io"
    "registry.k8s.io"
)

mkdir -p /etc/containerd/certs.d/
cat << EOF | tee "/etc/containerd/certs.d/registry.internal.d7z.net.toml" >/dev/null
server = "https://$url"

[host."https://registry.internal.d7z.net"]
  capabilities = ["pull", "resolve"]
  skip_verify = true

EOF

for url in "${ALIAS_LIST[@]}"; do
    current_directory="/etc/containerd/certs.d/$url"
    current_config_path="$current_directory/hosts.toml"
    mkdir -p "$current_directory"
    cat <<EOF | tee "$current_config_path" >/dev/null
server = "https://$url"

[host."https://registry.internal.d7z.net"]
  capabilities = ["pull", "resolve"]
  skip_verify = true

EOF
done
systemctl restart containerd
