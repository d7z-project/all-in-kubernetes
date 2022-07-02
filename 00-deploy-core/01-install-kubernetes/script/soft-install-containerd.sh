#!/usr/bin/env bash
# 此脚本参考至 https://github.com/kubernetes/kubernetes/issues/106464#issuecomment-1142563656
# 配置运行时版本
## https://github.com/containerd/containerd
CONTAINERD_VERSION=1.6.6
## https://github.com/opencontainers/runc
RUNC_VERSION=1.1.3
## https://github.com/containernetworking/plugins
CNI_VERSION=1.1.1
# 配置系统架构
ARCH=amd64

apt-get autoremove --purge -y containerd containerd.io
# 部署 containerd
wget https://github.com/containerd/containerd/releases/download/v$CONTAINERD_VERSION/containerd-$CONTAINERD_VERSION-linux-$ARCH.tar.gz -c -O /tmp/containerd.tgz
tar Cxzvf /usr/local /tmp/containerd.tgz
mkdir /etc/containerd/
containerd config default >/etc/containerd/config.toml
# 备注：在 Debian Bullseye 下已经默认启用 cgroup v2
sed -i 's|SystemdCgroup = false|SystemdCgroup = true|' /etc/containerd/config.toml

# 部署 runc
wget https://github.com/opencontainers/runc/releases/download/v$RUNC_VERSION/runc.$ARCH -c -O /tmp/runc
install -m 755 /tmp/runc /usr/local/sbin/runc

# 部署 CNI
wget https://github.com/containernetworking/plugins/releases/download/v$CNI_VERSION/cni-plugins-linux-$ARCH-v$CNI_VERSION.tgz -c -O /tmp/cni-plugin.tgz
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin /tmp/cni-plugin.tgz

# 配置 Systemd 服务
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service --output-document=/etc/systemd/system/containerd.service
systemctl daemon-reload
systemctl enable --now containerd
