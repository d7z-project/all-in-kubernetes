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
mkdir -p $SRC_PATH $DIST_PATH

# download
c-wget-src() {
    if [ ! -f "$SRC_PATH/$2" ]; then
        wget "$1" -c -O "$SRC_PATH/$2.tmp" || exit 1
        mv "$SRC_PATH/$2.tmp" "$SRC_PATH/$2"
    fi
}

c-wget-src https://github.com/containerd/containerd/releases/download/v$VERSION_CONTAINERD/containerd-$VERSION_CONTAINERD-linux-$ARCH.tar.gz containerd.tgz
c-wget-src https://github.com/opencontainers/runc/releases/download/v$VERSION_RUNC/runc.$ARCH runc
c-wget-src https://github.com/containernetworking/plugins/releases/download/v$VERSION_CNI_PLUGIN/cni-plugins-linux-$ARCH-v$VERSION_CNI_PLUGIN.tgz cni.tgz
c-wget-src https://github.com/containerd/nerdctl/releases/download/v$VERSION_NERDCTL/nerdctl-$VERSION_NERDCTL-linux-amd64.tar.gz nerdctl.tgz
c-wget-src https://raw.githubusercontent.com/containerd/containerd/main/containerd.service containerd.service
# build
rm -r $DIST_PATH
mkdir -p $DIST_PATH/usr/local/bin $DIST_PATH/usr/lib/systemd/system/ $DIST_PATH/etc/containerd/certs.d/ \
    $DIST_PATH/opt/cni/bin $DIST_PATH/etc/modules-load.d/ $DIST_PATH/etc/sysctl.d $DIST_PATH/usr/share/bash-completion/completions
tar zxf $SRC_PATH/containerd.tgz -C $DIST_PATH/usr/local
tar zxf $SRC_PATH/nerdctl.tgz -C $DIST_PATH/usr/local/bin
tar zxf $SRC_PATH/cni.tgz -C $DIST_PATH/opt/cni/bin
cp $SRC_PATH/runc $DIST_PATH/usr/local/bin
cp $SRC_PATH/containerd.service $DIST_PATH/usr/lib/systemd/system/containerd.service
$DIST_PATH/usr/local/bin/containerd config default |
    sed -e 's|SystemdCgroup = false|SystemdCgroup = true|' \
        -e 's|config_path = ""|config_path = "/etc/containerd/certs.d"|g' |
    tee $DIST_PATH/etc/containerd/config.toml >/dev/null
$DIST_PATH/usr/local/bin/nerdctl completion bash | tee $DIST_PATH/usr/share/bash-completion/completions/nerdctl >/dev/null
cat <<EOF | tee $DIST_PATH/etc/modules-load.d/containerd.conf >/dev/null
overlay
br_netfilter
EOF
cat <<EOF | tee $DIST_PATH/etc/sysctl.d/zz-containerd.conf >/dev/null
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
cat <<EOF | tee $DIST_PATH/etc/crictl.yaml >/dev/null
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
EOF
# =========================== package ===============================
cat <<"EOD" | tee $DIST_PATH/install.sh >/dev/null
#!/bin/bash
set -e
ROOT_PATH=${ROOT_PATH:-/}
PWD_PATH=$(
    cd $(dirname ${BASH_SOURCE[0]})
    pwd
)
cd $PWD_PATH || exit 1
pre(){
    chown -Rv root:root $PWD_PATH
    chmod -Rv 755 $PWD_PATH/opt $PWD_PATH/usr
    chmod -Rv 644 $PWD_PATH/etc $PWD_PATH/usr/lib
}
copy(){
    cp -rvf $PWD_PATH/* $ROOT_PATH
    rm /${BASH_SOURCE[0]}
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
