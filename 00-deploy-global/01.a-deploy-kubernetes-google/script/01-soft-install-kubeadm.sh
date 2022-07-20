#!/usr/bin/env bash
# Kubernetes 版本
KUBEADM_RELEASE="v1.24.3"
CRICTL_RELEASE="v1.24.2"
# 系统架构
ARCH="amd64"
# Kubernetes 下载目录
KUBERNETES_BIN_URL="https://storage.googleapis.com/kubernetes-release/release"
# Kubernetes 发布工具版本
KUBE_RELEASE_VERSION="v0.14.0"
#下载目录
DOWNLOAD_PATH=/tmp/kubernetes
mkdir -p $DOWNLOAD_PATH
IMAGE_PATH=$DOWNLOAD_PATH/images
mkdir -p $IMAGE_PATH

# 准备环境
wget $KUBERNETES_BIN_URL/$KUBEADM_RELEASE/bin/linux/$ARCH/kubeadm -c -O $DOWNLOAD_PATH/kubeadm
wget $KUBERNETES_BIN_URL/$KUBEADM_RELEASE/bin/linux/$ARCH/kubelet -c -O $DOWNLOAD_PATH/kubelet
wget $KUBERNETES_BIN_URL/$KUBEADM_RELEASE/bin/linux/$ARCH/kubectl -c -O $DOWNLOAD_PATH/kubectl
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$CRICTL_RELEASE/crictl-$CRICTL_RELEASE-linux-$ARCH.tar.gz -c -O $DOWNLOAD_PATH/cri-tools.tgz
wget "https://raw.githubusercontent.com/kubernetes/release/$KUBE_RELEASE_VERSION/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service" -c -O $DOWNLOAD_PATH/kubelet.service
wget "https://raw.githubusercontent.com/kubernetes/release/$KUBE_RELEASE_VERSION/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf" -c -O $DOWNLOAD_PATH/10-kubeadm.conf
chmod +x $DOWNLOAD_PATH/kubeadm
# 下载镜像
save_image() {
    docker pull "$1"
    # shellcheck disable=SC2001
    docker save -o $IMAGE_PATH/"$(echo "$1" | sed s@/@-@g)" "$1"
}
# 导入默认镜像
IFS=" " read -r -a LIST <<<"$(HTTP_PROXY=no HTTPS_PROXY=no $DOWNLOAD_PATH/kubeadm config images list 2>/dev/null | xargs echo)"
# shellcheck disable=SC2128
for IMAGE in ${LIST[*]}; do
    save_image "$IMAGE"
done

# 导入自定义镜像
save_image "k8s.gcr.io/pause:3.6"
save_image "rancher/mirrored-flannelcni-flannel-cni-plugin:v1.1.0"
save_image "rancher/mirrored-flannelcni-flannel:v0.18.1"

# 安装
tar -C $DOWNLOAD_PATH -zxf $DOWNLOAD_PATH/cri-tools.tgz
install -m 755 $DOWNLOAD_PATH/crictl /usr/bin/crictl
install -m 755 $DOWNLOAD_PATH/kubeadm /usr/bin/kubeadm
install -m 755 $DOWNLOAD_PATH/kubelet /usr/bin/kubelet
install -m 755 $DOWNLOAD_PATH/kubectl /usr/bin/kubectl
sudo mkdir -p /etc/systemd/system/kubelet.service.d
install -m 644 $DOWNLOAD_PATH/kubelet.service /etc/systemd/system/kubelet.service
install -m 644 $DOWNLOAD_PATH/10-kubeadm.conf /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

# 启动
systemctl daemon-reload
systemctl enable --now kubelet

# 配置 cri
cat <<EOF | tee /etc/crictl.yaml
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
EOF

# 导入镜像
# shellcheck disable=SC2178
LIST=$(
    cd $IMAGE_PATH || exit
    # shellcheck disable=SC2035
    ls *
)
for IMAGE in ${LIST[*]}; do
    # Containerd 需要指定命名空间
    ctr -n=k8s.io image import $IMAGE_PATH/$IMAGE
done

# 注意，如果安装失败可能是 pause  镜像问题，导入 3.6 版本镜像即可。
