#!/usr/bin/env bash
# 配置运行时版本
## https://github.com/containerd/containerd
CONTAINERD_VERSION=1.6.6
## https://github.com/opencontainers/runc
RUNC_VERSION=1.1.3
## https://github.com/containernetworking/plugins
CNI_VERSION=1.1.1
##
KUBEADM_RELEASE="v1.24.3"
##
CRICTL_RELEASE="v1.24.2"
##
KUBE_RELEASE_VERSION="v0.14.0"
# 配置系统架构
ARCH=amd64
# 下载地址
DOWNLOAD_PATH="$HOME/kubernetes-offline"
mkdir -p "$DOWNLOAD_PATH"
# 镜像地址
IMAGE_PATH=$DOWNLOAD_PATH/images
mkdir -p "$IMAGE_PATH"

down() {
    wget "$1" -c -O "$2" 2>/dev/null || exit 1
}

# 准备 containerd 软件
down https://github.com/containerd/containerd/releases/download/v$CONTAINERD_VERSION/containerd-$CONTAINERD_VERSION-linux-$ARCH.tar.gz $DOWNLOAD_PATH/containerd.tgz
down https://github.com/opencontainers/runc/releases/download/v$RUNC_VERSION/runc.$ARCH $DOWNLOAD_PATH/runc
down https://github.com/containernetworking/plugins/releases/download/v$CNI_VERSION/cni-plugins-linux-$ARCH-v$CNI_VERSION.tgz $DOWNLOAD_PATH/cni-plugin.tgz
down https://raw.githubusercontent.com/containerd/containerd/main/containerd.service $DOWNLOAD_PATH/containerd.service

# 下载 kubernetes
KUBERNETES_BIN_URL="https://storage.googleapis.com/kubernetes-release/release"
down $KUBERNETES_BIN_URL/$KUBEADM_RELEASE/bin/linux/$ARCH/kubeadm $DOWNLOAD_PATH/kubeadm
down $KUBERNETES_BIN_URL/$KUBEADM_RELEASE/bin/linux/$ARCH/kubelet $DOWNLOAD_PATH/kubelet
down $KUBERNETES_BIN_URL/$KUBEADM_RELEASE/bin/linux/$ARCH/kubectl $DOWNLOAD_PATH/kubectl
if [ ! -f "$DOWNLOAD_PATH/crictl" ]; then
    down https://github.com/kubernetes-sigs/cri-tools/releases/download/$CRICTL_RELEASE/crictl-$CRICTL_RELEASE-linux-$ARCH.tar.gz $DOWNLOAD_PATH/cri-tools.tgz
    tar -C "$DOWNLOAD_PATH" -zxf $DOWNLOAD_PATH/cri-tools.tgz
    rm $DOWNLOAD_PATH/cri-tools.tgz
fi
down "https://raw.githubusercontent.com/kubernetes/release/$KUBE_RELEASE_VERSION/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service" $DOWNLOAD_PATH/kubelet.service
down "https://raw.githubusercontent.com/kubernetes/release/$KUBE_RELEASE_VERSION/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf" $DOWNLOAD_PATH/10-kubeadm.conf
chmod +x $DOWNLOAD_PATH/kubeadm

# 下载镜像函数
save_image() {
    # shellcheck disable=SC2001
    CURRENT_DOCKER_PATH=$IMAGE_PATH/"$(echo "$1" | sed s@/@-@g)"
    if [ ! -f "$CURRENT_DOCKER_PATH" ]; then
        docker pull "$1"
        docker save -o "$CURRENT_DOCKER_PATH" "$1"
    fi
}
# 下载预置镜像
IFS=" " read -r -a LIST <<<"$(HTTP_PROXY=no HTTPS_PROXY=no $DOWNLOAD_PATH/kubeadm config images list 2>/dev/null | xargs echo)"
# shellcheck disable=SC2128
for IMAGE in ${LIST[*]}; do
    save_image "$IMAGE"
done

# 导入自定义镜像
save_image "k8s.gcr.io/pause:3.6"
save_image "rancher/mirrored-flannelcni-flannel-cni-plugin:v1.1.0"
save_image "docker.io/rancher/mirrored-flannelcni-flannel:v0.19.1"

INSTALL_SCRIPT=$DOWNLOAD_PATH/install.sh
touch $INSTALL_SCRIPT ||:
chmod 755 $INSTALL_SCRIPT || exit 1
cat <<"EOD" | tee $INSTALL_SCRIPT >/dev/null
#!/bin/bash
PROJECT_HOME=$(
    cd $(dirname ${BASH_SOURCE[0]})
    pwd
)
# 配置系统环境
cat <<EOF | tee /etc/modules-load.d/kubernetes.conf > /dev/null
br_netfilter
EOF
modprobe br_netfilter
cat <<EOF | tee /etc/sysctl.d/zz-kubernetes.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system
# 解包软件包
tar Cxzvf /usr/local $PROJECT_HOME/containerd.tgz
mkdir /etc/containerd/
containerd config default >/etc/containerd/config.toml
# 备注：在 Debian Bullseye 下已经默认启用 cgroup v2 , 使用 SystemdCgroup
sed -i 's|SystemdCgroup = false|SystemdCgroup = true|' /etc/containerd/config.toml
# 部署 runc
install -m 755 $PROJECT_HOME/runc /usr/local/sbin/runc
# 部署 CNI
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin $PROJECT_HOME/cni-plugin.tgz
# 配置 Systemd 服务
cp $PROJECT_HOME/containerd.service /etc/systemd/system/containerd.service
systemctl daemon-reload
systemctl enable --now containerd
install -m 755 $PROJECT_HOME/crictl /usr/bin/crictl
install -m 755 $PROJECT_HOME/kubeadm /usr/bin/kubeadm
install -m 755 $PROJECT_HOME/kubelet /usr/bin/kubelet
install -m 755 $PROJECT_HOME/kubectl /usr/bin/kubectl
mkdir -p /etc/systemd/system/kubelet.service.d
install -m 644 $PROJECT_HOME/kubelet.service /etc/systemd/system/kubelet.service
install -m 644 $PROJECT_HOME/10-kubeadm.conf /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
# 启动
systemctl daemon-reload
systemctl enable --now kubelet
# 配置 cri
cat <<EOF | tee /etc/crictl.yaml
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
EOF
# 导入镜像
LIST=$(
    cd $PROJECT_HOME/images || exit
    ls *
)
for IMAGE in ${LIST[*]}; do
    # Containerd 需要指定命名空间
    ctr -n=k8s.io image import "$PROJECT_HOME"/images/"$IMAGE"
done
EOD

# 压缩软件包
TGZ_PATH="$(
    # shellcheck disable=SC2086
    cd $DOWNLOAD_PATH || exit 1
    # shellcheck disable=SC2046
    dirname $(pwd)
)/k8s.tgz"
(
    # shellcheck disable=SC2046
    cd $(dirname "$DOWNLOAD_PATH") || exit
    # shellcheck disable=SC2046
    tar zcf "$TGZ_PATH" $(basename "$DOWNLOAD_PATH")
)
echo "导出压缩文件位置：$TGZ_PATH."
