#!/usr/bin/env bash
# 配置运行时版本
##
KUBEADM_RELEASE="v1.24.3"
##
KUBE_RELEASE_VERSION="v0.14.0"
# 配置系统架构
ARCH=amd64
# 下载地址
DOWNLOAD_PATH="/tmp/kubernetes-offline"
mkdir -p "$DOWNLOAD_PATH"
# 镜像地址
IMAGE_PATH=$DOWNLOAD_PATH/images
mkdir -p "$IMAGE_PATH"

down() {
    wget "$1" -c -O "$2" 2>/dev/null || exit 1
}

# 下载 kubernetes
KUBERNETES_BIN_URL="https://storage.googleapis.com/kubernetes-release/release"
down $KUBERNETES_BIN_URL/$KUBEADM_RELEASE/bin/linux/$ARCH/kubeadm $DOWNLOAD_PATH/kubeadm
down $KUBERNETES_BIN_URL/$KUBEADM_RELEASE/bin/linux/$ARCH/kubelet $DOWNLOAD_PATH/kubelet
down $KUBERNETES_BIN_URL/$KUBEADM_RELEASE/bin/linux/$ARCH/kubectl $DOWNLOAD_PATH/kubectl
down "https://raw.githubusercontent.com/kubernetes/release/$KUBE_RELEASE_VERSION/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service" $DOWNLOAD_PATH/kubelet.service
down "https://raw.githubusercontent.com/kubernetes/release/$KUBE_RELEASE_VERSION/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf" $DOWNLOAD_PATH/10-kubeadm.conf
chmod +x $DOWNLOAD_PATH/kubeadm

# 下载镜像函数
save_image() {
    # shellcheck disable=SC2001
    IMAGE_NAME="$1"
    IMAGE_SAVE_NAME="$(echo "$IMAGE_NAME" | sed -e 's@/@-@g' -e 's@:@-@g' -e 's/@/-/g')"
    CURRENT_DOCKER_PATH=$IMAGE_PATH/$IMAGE_SAVE_NAME
    if [ ! -f "$CURRENT_DOCKER_PATH" ]; then
        docker pull "$1"
        docker save -o "$CURRENT_DOCKER_PATH" "$1"
    fi
    echo "$IMAGE_NAME $IMAGE_SAVE_NAME" >>$DOWNLOAD_PATH/images.txt
}
rm -f $DOWNLOAD_PATH/images.txt
touch $DOWNLOAD_PATH/images.txt
# 下载预置镜像
IFS=" " read -r -a LIST <<<"$(HTTP_PROXY=no HTTPS_PROXY=no $DOWNLOAD_PATH/kubeadm config images list 2>/dev/null | xargs echo)"
# shellcheck disable=SC2128
for IMAGE in ${LIST[*]}; do
    save_image "$IMAGE"
done

# 导入自定义镜像
save_image "k8s.gcr.io/pause:3.6"
save_image "docker.io/rancher/mirrored-flannelcni-flannel-cni-plugin:v1.1.0"
save_image "docker.io/rancher/mirrored-flannelcni-flannel:v0.19.1"

INSTALL_SCRIPT=$DOWNLOAD_PATH/install.sh
touch $INSTALL_SCRIPT || :
chmod 755 $INSTALL_SCRIPT || exit 1
cat <<"EOD" | tee $INSTALL_SCRIPT >/dev/null
#!/bin/bash
PROJECT_HOME=$(
    cd $(dirname ${BASH_SOURCE[0]})
    pwd
)
# 配置系统环境
cat <<EOF | tee /etc/modules-load.d/kubernetes.conf > /dev/null
overlay
br_netfilter
EOF
modprobe br_netfilter
modprobe overlay
cat <<EOF | tee /etc/sysctl.d/zz-kubernetes.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system
install -m 755 $PROJECT_HOME/kubeadm /usr/bin/kubeadm
install -m 755 $PROJECT_HOME/kubelet /usr/bin/kubelet
install -m 755 $PROJECT_HOME/kubectl /usr/bin/kubectl
mkdir -p /etc/systemd/system/kubelet.service.d
install -m 644 $PROJECT_HOME/kubelet.service /etc/systemd/system/kubelet.service
install -m 644 $PROJECT_HOME/10-kubeadm.conf /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
# 启动
systemctl daemon-reload
systemctl enable --now kubelet
# 导入镜像
LIST=$(
    cd $PROJECT_HOME/images || exit
    ls *
)
for IMAGE in ${LIST[*]}; do
    ctr -n=k8s.io image import "$PROJECT_HOME"/images/"$IMAGE" ||
    docker -n=k8s.io load --input "$PROJECT_HOME"/images/"$IMAGE"
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
