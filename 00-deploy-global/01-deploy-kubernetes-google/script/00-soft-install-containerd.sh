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

# 下载地址
DOWNLOAD_PATH=/tmp/kubernetes
mkdir -p $DOWNLOAD_PATH

# 准备软件

wget https://github.com/containerd/containerd/releases/download/v$CONTAINERD_VERSION/containerd-$CONTAINERD_VERSION-linux-$ARCH.tar.gz -c -O $DOWNLOAD_PATH/containerd.tgz
wget https://github.com/opencontainers/runc/releases/download/v$RUNC_VERSION/runc.$ARCH -c -O $DOWNLOAD_PATH/runc
wget https://github.com/containernetworking/plugins/releases/download/v$CNI_VERSION/cni-plugins-linux-$ARCH-v$CNI_VERSION.tgz -c -O $DOWNLOAD_PATH/cni-plugin.tgz
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -O $DOWNLOAD_PATH/containerd.service

# 开始安装

# 部署 Containerd
tar Cxzvf /usr/local $DOWNLOAD_PATH/containerd.tgz
mkdir /etc/containerd/
containerd config default >/etc/containerd/config.toml
# 备注：在 Debian Bullseye 下已经默认启用 cgroup v2
sed -i 's|SystemdCgroup = false|SystemdCgroup = true|' /etc/containerd/config.toml

# 部署 runc
install -m 755 $DOWNLOAD_PATH/runc /usr/local/sbin/runc

# 部署 CNI
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin $DOWNLOAD_PATH/cni-plugin.tgz

# 配置 Systemd 服务
cp $DOWNLOAD_PATH/containerd.service /etc/systemd/system/containerd.service
systemctl daemon-reload
systemctl enable --now containerd
