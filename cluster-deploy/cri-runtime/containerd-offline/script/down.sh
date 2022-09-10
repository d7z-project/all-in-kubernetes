#!/usr/bin/env bash
set -e
## https://github.com/containerd/containerd
VERSION_CONTAINERD=1.6.8
## https://github.com/opencontainers/runc
VERSION_RUNC=1.1.4
## https://github.com/containernetworking/plugins
VERSION_CNI_PLUGIN=1.1.1
#https://github.com/containerd/nerdctl/
VERSION_NERDCTL=0.22.2

ARCH=amd64

WORK_PATH=/tmp/containerd
SRC_PATH=$WORK_PATH/src
DIST_PATH=$WORK_PATH/containerd-$VERSION_CONTAINERD
BUILD_ROOT=$DIST_PATH/rootfs
mkdir -p $SRC_PATH $DIST_PATH $BUILD_ROOT

# download
c_down() {
    if [ ! -f "$SRC_PATH/$2" ]; then
        wget "$1" -c -O "$SRC_PATH/$2.tmp" || exit 1
        mv "$SRC_PATH/$2.tmp" "$SRC_PATH/$2"
    fi
}

c_down https://github.com/containerd/containerd/releases/download/v$VERSION_CONTAINERD/containerd-$VERSION_CONTAINERD-linux-$ARCH.tar.gz containerd.tgz
c_down https://github.com/opencontainers/runc/releases/download/v$VERSION_RUNC/runc.$ARCH runc
c_down https://github.com/containernetworking/plugins/releases/download/v$VERSION_CNI_PLUGIN/cni-plugins-linux-$ARCH-v$VERSION_CNI_PLUGIN.tgz cni.tgz
c_down https://github.com/containerd/nerdctl/releases/download/v$VERSION_NERDCTL/nerdctl-$VERSION_NERDCTL-linux-amd64.tar.gz nerdctl.tgz
c_down https://raw.githubusercontent.com/containerd/containerd/main/containerd.service containerd.service
# build
rm -r $DIST_PATH
mkdir -p $BUILD_ROOT/usr/local/bin $BUILD_ROOT/usr/lib/systemd/system/ $BUILD_ROOT/etc/containerd/certs.d/ \
    $BUILD_ROOT/opt/cni/bin $BUILD_ROOT/etc/modules-load.d/ $BUILD_ROOT/etc/sysctl.d $BUILD_ROOT/usr/share/bash-completion/completions
tar zxf $SRC_PATH/containerd.tgz -C $BUILD_ROOT/usr/local
tar zxf $SRC_PATH/nerdctl.tgz -C $BUILD_ROOT/usr/local/bin
tar zxf $SRC_PATH/cni.tgz -C $BUILD_ROOT/opt/cni/bin
cp $SRC_PATH/runc $BUILD_ROOT/usr/local/bin
cp $SRC_PATH/containerd.service $BUILD_ROOT/usr/lib/systemd/system/containerd.service
$BUILD_ROOT/usr/local/bin/containerd config default |
    sed -e 's|SystemdCgroup = false|SystemdCgroup = true|' \
        -e 's|config_path = ""|config_path = "/etc/containerd/certs.d"|g' |
    tee $BUILD_ROOT/etc/containerd/config.toml >/dev/null
$BUILD_ROOT/usr/local/bin/nerdctl completion bash | tee $BUILD_ROOT/usr/share/bash-completion/completions/nerdctl >/dev/null
cat <<EOF | tee $BUILD_ROOT/etc/modules-load.d/containerd.conf >/dev/null
overlay
br_netfilter
EOF
cat <<EOF | tee $BUILD_ROOT/etc/sysctl.d/zz-containerd.conf >/dev/null
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
cat <<EOF | tee $BUILD_ROOT/etc/crictl.yaml >/dev/null
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
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
cd $PWD_PATH || exit 1
pre(){
    chown -Rv root:root $BUILD_ROOT_PATH
    chmod -Rv 755 $BUILD_ROOT_PATH/opt $BUILD_ROOT_PATH/usr
    chmod -Rv 644 $BUILD_ROOT_PATH/etc $BUILD_ROOT_PATH/usr/lib
}
copy(){
    cp -rvf $BUILD_ROOT_PATH/* $INSTALL_PATH
}
configure(){
    modprobe br_netfilter
    sysctl --system
    systemctl daemon-reload
    systemctl enable --now containerd
}
install(){
    pre
    copy
    configure
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
