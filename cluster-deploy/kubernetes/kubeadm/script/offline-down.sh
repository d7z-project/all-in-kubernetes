#!/usr/bin/env bash
set -e
# https://github.com/kubernetes/kubernetes/releases
VERSION_KUBEADM="1.25.2"
# https://github.com/kubernetes-sigs/cri-tools/releases
VERSION_CRICTL="1.25.0"
VERSION_KUBEADM_CONF="0.4.0"
ARCH="amd64"

WORK_PATH=/tmp/kubernetes
SRC_PATH=$WORK_PATH/src
DIST_PATH=$WORK_PATH/kubernetes-$VERSION_KUBEADM
BUILD_ROOT=$DIST_PATH/rootfs
IMAGE_ROOT=$DIST_PATH/images
if [ -d $IMAGE_ROOT ]; then
    rm -r $IMAGE_ROOT || :
fi
mkdir -p $SRC_PATH $DIST_PATH $BUILD_ROOT $IMAGE_ROOT

#====== down
c_down() {
    if [ ! -f "$SRC_PATH/$2" ]; then
        wget "$1" -c -O "$SRC_PATH/$2.tmp" || exit 1
        mv "$SRC_PATH/$2.tmp" "$SRC_PATH/$2"
    fi
}

KUBERNETES_BIN_URL="https://storage.googleapis.com/kubernetes-release/release"
c_down $KUBERNETES_BIN_URL/v$VERSION_KUBEADM/bin/linux/$ARCH/kubeadm kubeadm
c_down $KUBERNETES_BIN_URL/v$VERSION_KUBEADM/bin/linux/$ARCH/kubelet kubelet
c_down $KUBERNETES_BIN_URL/v$VERSION_KUBEADM/bin/linux/$ARCH/kubectl kubectl
c_down https://github.com/kubernetes-sigs/cri-tools/releases/download/v${VERSION_CRICTL}/crictl-v${VERSION_CRICTL}-linux-${ARCH}.tar.gz crictl.tgz
c_down https://raw.githubusercontent.com/kubernetes/release/v${VERSION_KUBEADM_CONF}/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service kubelet.service
c_down https://raw.githubusercontent.com/kubernetes/release/v${VERSION_KUBEADM_CONF}/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf 10-kubeadm.conf

# down images
c_down_image() {
    IMAGE_NAME="$1"
    IMAGE_SAVE_NAME="$(echo "$IMAGE_NAME" | sed -e 's@/@-@g' -e 's@:@-@g' -e 's/@/-/g')"
    CURRENT_DOCKER_PATH=$IMAGE_ROOT/$IMAGE_SAVE_NAME
    if [ ! -f "$CURRENT_DOCKER_PATH" ]; then
        podman pull "$1"
        podman save "$1" -o "$CURRENT_DOCKER_PATH"
    fi
    echo "$IMAGE_NAME $IMAGE_SAVE_NAME" >>$DIST_PATH/images.txt
}
chmod +x $SRC_PATH/kubeadm
IFS=" " read -r -a LIST <<<"$(HTTP_PROXY=no HTTPS_PROXY=no $SRC_PATH/kubeadm config images list 2>/dev/null | xargs echo)"
# shellcheck disable=SC2128
for IMAGE in ${LIST[*]}; do
    c_down_image "$IMAGE"
done
# containerd 需要
c_down_image "k8s.gcr.io/pause:3.6"
# k8s cni 插件需要
c_down_image "docker.io/rancher/mirrored-flannelcni-flannel-cni-plugin:v1.1.0"
c_down_image "docker.io/rancher/mirrored-flannelcni-flannel:v0.19.1"

# ============ BUILD =========
rm -r $BUILD_ROOT
mkdir -p $BUILD_ROOT/usr/local/bin \
    $BUILD_ROOT/usr/lib/systemd/system \
    $BUILD_ROOT/etc/systemd/system/kubelet.service.d \
    $BUILD_ROOT/etc/modules-load.d/ \
    $BUILD_ROOT/etc/sysctl.d \
    $BUILD_ROOT/usr/share/bash-completion/completions
cp $SRC_PATH/kubeadm $SRC_PATH/kubelet $SRC_PATH/kubectl $BUILD_ROOT/usr/local/bin
tar Czxf $BUILD_ROOT/usr/local/bin $SRC_PATH/crictl.tgz
chmod -R +x $BUILD_ROOT/usr/local/bin/

sed -e "s|/usr/bin|/usr/local/bin|g" <$SRC_PATH/kubelet.service | tee $BUILD_ROOT/usr/lib/systemd/system/kubelet.service >/dev/null
sed -e "s|/usr/bin|/usr/local/bin|g" <$SRC_PATH/10-kubeadm.conf | tee $BUILD_ROOT/etc/systemd/system/kubelet.service.d/10-kubeadm.conf >/dev/null

$BUILD_ROOT/usr/local/bin/crictl completion bash | tee $BUILD_ROOT/usr/share/bash-completion/completions/crictl >/dev/null
$BUILD_ROOT/usr/local/bin/kubeadm completion bash | tee $BUILD_ROOT/usr/share/bash-completion/completions/kubeadm >/dev/null
$BUILD_ROOT/usr/local/bin/kubectl completion bash | tee $BUILD_ROOT/usr/share/bash-completion/completions/kubectl >/dev/null

cat <<EOF | tee $BUILD_ROOT/etc/modules-load.d/kubernetes.conf >/dev/null
overlay
br_netfilter
EOF
cat <<EOF | tee $BUILD_ROOT/etc/sysctl.d/zz-kubernetes.conf >/dev/null
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

# =========================== package ===============================
cat <<"EOD" | tee $DIST_PATH/install.sh >/dev/null
#!/bin/bash
set -e
INSTALL_PATH=${INSTALLED_PATH:-/}
PWD_PATH=$(
    cd $(dirname ${BASH_SOURCE[0]})
    pwd
)
BUILD_ROOT_PATH=$PWD_PATH/rootfs
IMAGES_PATH=$PWD_PATH/images
cd $PWD_PATH || exit 1
pre(){
    chown -Rv root:root $BUILD_ROOT_PATH ||:
    chmod -Rv 755 $BUILD_ROOT_PATH/usr ||:
    chmod -Rv 644 $BUILD_ROOT_PATH/etc $BUILD_ROOT_PATH/usr/lib ||:
}
copy(){
    cp -rvf $BUILD_ROOT_PATH/* $INSTALL_PATH
}
include-img(){
    LIST=$(
        cd $IMAGES_PATH || exit
        ls *
    )
    for IMAGE in ${LIST[*]}; do
        ctr -n=k8s.io image import $IMAGES_PATH/"$IMAGE" ||
        podman -n=k8s.io load --input $IMAGES_PATH/"$IMAGE"
    done

}
configure(){
    modprobe br_netfilter
    sysctl --system
    systemctl daemon-reload
    systemctl enable --now kubelet
}
install(){
    pre
    copy
    configure
    include-img
}
if [ ! "$1" ]; then
    install
fi
EOD

chmod +x $DIST_PATH/install.sh
(
    cd "$(dirname $DIST_PATH)" || exit 1
    tar zcvf "$(basename $DIST_PATH)".tgz "$(basename $DIST_PATH)"
)

echo "软件包准备完成，数据保存在 $(dirname $DIST_PATH)/$(basename $DIST_PATH).tgz"
exit 0
