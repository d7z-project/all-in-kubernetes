#!/usr/bin/env bash
VERSION=1.24.1
ARCH=amd64
wget https://github.com/cri-o/cri-o/releases/download/v$VERSION/cri-o.$ARCH.v$VERSION.tar.gz -c -O /tmp/cri-o.tgz
tar zxf /tmp/cri-o.tgz -C /tmp
mv /tmp/cri-o/install /tmp/cri-o/install-official
cat <<"EOL" >/tmp/cri-o/install.sh
#!/bin/bash
PROJECT_HOME=$(
    cd $(dirname ${BASH_SOURCE[0]})
    pwd
)
cat <<EOF | tee /etc/modules-load.d/cri-o.conf > /dev/null
br_netfilter
EOF
modprobe br_netfilter
cat <<EOF | tee /etc/sysctl.d/zz-cri-o.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
fs.may_detach_mounts = 1
EOF
sysctl --system
chmod 755 $PROJECT_HOME/install-official
mkdir -p /opt/cni/bin \
    /etc/containers \
    /etc/cni/net.d \
    /etc/crio \
    /etc/crio/crio.conf.d \
    /usr/share/man \
    /usr/share/oci-umount/oci-umount.d \
    /usr/share/bash-completion/completions \
    /usr/share/fish/completions \
    /usr/share/zsh/site-functions
sed -i "s@/usr/local/bin@/usr/bin@g"  $PROJECT_HOME/contrib/crio.service
PREFIX=/usr $PROJECT_HOME/install-official
crictl completion bash > /usr/share/bash-completion/completions/crictl
chmod 755 /usr/share/bash-completion/completions/crictl
crictl completion zsh > /usr/share/zsh/site-functions/_crictl
chmod 755 /usr/share/zsh/site-functions/_crictl
crictl completion fish > /usr/share/fish/completions/crictl.fish
chmod 755 /usr/share/fish/completions/crictl.fish
systemctl daemon-reload
systemctl enable crio --now
EOL
dist_path=/tmp/cri-o
cri_o_path="$(
    # shellcheck disable=SC2086
    cd $dist_path || exit 1
    # shellcheck disable=SC2046
    dirname $(pwd)
)/cri-o-kubernetes.tgz"
(
    # shellcheck disable=SC2046
    cd $(dirname "$dist_path") || exit
    # shellcheck disable=SC2046
    tar zcf "$cri_o_path" $(basename "$dist_path")
)
echo -e "CRI-O 压缩包已导出到 \"$cri_o_path\",请上传解压后执行 bash install.sh"
