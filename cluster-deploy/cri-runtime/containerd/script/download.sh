#!/usr/bin/env bash
## https://github.com/containerd/containerd
containerd_version=1.6.8
## https://github.com/opencontainers/runc
runc_version=1.1.4
## https://github.com/containernetworking/plugins
cni_version=1.1.1
#https://github.com/containerd/nerdctl/
nerdctl_version=0.22.2
# https://github.com/kubernetes-sigs/cri-tools
crictl_version="v1.24.2"
# 配置系统架构
ARCH=amd64
# 工作目录
down_path="/tmp/containerd"

c-wget() {
    wget "$1" -c -O "$2" || exit 1
}

mkdir -p "$down_path"
c-wget https://github.com/containerd/containerd/releases/download/v$containerd_version/containerd-$containerd_version-linux-$ARCH.tar.gz $down_path/containerd.tgz
c-wget https://github.com/opencontainers/runc/releases/download/v$runc_version/runc.$ARCH $down_path/runc
c-wget https://github.com/containernetworking/plugins/releases/download/v$cni_version/cni-plugins-linux-$ARCH-v$cni_version.tgz $down_path/cni-plugin.tgz
c-wget https://github.com/containerd/nerdctl/releases/download/v$nerdctl_version/nerdctl-$nerdctl_version-linux-amd64.tar.gz $down_path/nerdctl.tgz
c-wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service $down_path/containerd.service
c-wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$crictl_version/crictl-$crictl_version-linux-$ARCH.tar.gz $down_path/cri-tools.tgz
tar -C "$down_path" -zxf $down_path/cri-tools.tgz
/bin/rm $down_path/cri-tools.tgz

cat <<"EOL" >$down_path/installer.sh
#!/bin/bash
PROJECT_HOME=$(
    cd $(dirname ${BASH_SOURCE[0]})
    pwd
)
tar zxf $PROJECT_HOME/containerd.tgz -C /usr/local
tar zxf $PROJECT_HOME/nerdctl.tgz -C /usr/local/bin
install -m 755 $PROJECT_HOME/crictl /usr/bin/crictl
mkdir /etc/containerd/
containerd config default >/etc/containerd/config.toml
sed -i 's|SystemdCgroup = false|SystemdCgroup = true|' /etc/containerd/config.toml
install -m 755 $PROJECT_HOME/runc /usr/local/sbin/runc
mkdir -p /opt/cni/bin
tar zxf $PROJECT_HOME/cni-plugin.tgz -C /opt/cni/bin
cp $PROJECT_HOME/containerd.service /etc/systemd/system/containerd.service
systemctl daemon-reload
systemctl enable --now containerd
cat <<EOF | tee /etc/crictl.yaml > /dev/null
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
EOF
cat <<EOF | tee /etc/modules-load.d/containerd.conf > /dev/null
br_netfilter
EOF
modprobe br_netfilter
cat <<EOF | tee /etc/sysctl.d/zz-containerd.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system
nerdctl completion bash > /etc/bash_completion.d/nerdctl
chmod 755 /etc/bash_completion.d/nerdctl
source /etc/bash_completion.d/nerdctl
ln -s /usr/local/bin/nerdctl /usr/local/bin/docker
EOL

containerd_path="$(
    # shellcheck disable=SC2086
    cd $down_path || exit 1
    # shellcheck disable=SC2046
    dirname $(pwd)
)/containerd.tgz"
(
    # shellcheck disable=SC2046
    cd $(dirname "$down_path") || exit
    # shellcheck disable=SC2046
    tar zcf "$containerd_path" $(basename "$down_path")
)
echo -e "container 压缩包已导出到 \"$containerd_path\",请上传解压后执行 bash install.sh"
