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

# 准备环境
wget $KUBERNETES_BIN_URL/$KUBEADM_RELEASE/bin/linux/$ARCH/kubeadm -c -O $DOWNLOAD_PATH/kubeadm
wget $KUBERNETES_BIN_URL/$KUBEADM_RELEASE/bin/linux/$ARCH/kubelet -c -O $DOWNLOAD_PATH/kubelet
wget $KUBERNETES_BIN_URL/$KUBEADM_RELEASE/bin/linux/$ARCH/kubectl -c -O $DOWNLOAD_PATH/kubectl
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$CRICTL_RELEASE/crictl-$CRICTL_RELEASE-linux-$ARCH.tar.gz -c -O $DOWNLOAD_PATH/cri-tools.tgz
wget "https://raw.githubusercontent.com/kubernetes/release/$KUBE_RELEASE_VERSION/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service" -c -O $DOWNLOAD_PATH/kubelet.service
wget "https://raw.githubusercontent.com/kubernetes/release/$KUBE_RELEASE_VERSION/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf" -c -O $DOWNLOAD_PATH/10-kubeadm.conf
chmod +x $DOWNLOAD_PATH/kubeadm
# 下载镜像
IFS=" " read -r -a LIST <<<"$(HTTP_PROXY=no HTTPS_PROXY=no $DOWNLOAD_PATH/kubeadm config images list 2>/dev/null | xargs echo)"
# shellcheck disable=SC2128
for IMAGE in ${LIST[*]}; do
    docker pull "$IMAGE"
    # shellcheck disable=SC2001
    docker save -o $DOWNLOAD_PATH/"$(echo "$IMAGE" | sed s@/@-@g)" "$IMAGE"
done

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

# 导入镜像
IFS=" " read -r -a LIST <<<"$(HTTP_PROXY=no HTTPS_PROXY=no /usr/bin/kubeadm config images list 2>/dev/null | xargs echo)"
for IMAGE in ${LIST[*]}; do
    ctr image import $DOWNLOAD_PATH/"$(echo "$IMAGE" | sed s@/@-@g)"
done
