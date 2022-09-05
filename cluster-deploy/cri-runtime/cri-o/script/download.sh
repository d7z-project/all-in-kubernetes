#!/usr/bin/env bash
VERSION=1.24.1
PODMAN_VERSION=4.2.0
ARCH=amd64
WORK_DIR=/tmp/cri-o
BUILD_ROOT=$WORK_DIR/buildroot
DIST_ROOT=$WORK_DIR/cri-o

############## start
rm -rf $BUILD_ROOT $DIST_ROOT
mkdir -p $WORK_DIR $WORK_DIR/src \
    $BUILD_ROOT \
    $BUILD_ROOT/etc/modules-load.d \
    $BUILD_ROOT/etc/sysctl.d \
    $BUILD_ROOT/etc/cni/net.d \
    $BUILD_ROOT/usr/lib/systemd/system \
    $DIST_ROOT

wget https://github.com/cri-o/cri-o/releases/download/v$VERSION/cri-o.$ARCH.v$VERSION.tar.gz -c -O $WORK_DIR/src/cri-o.tgz
wget https://github.com/mgoltzsche/podman-static/releases/download/v4.2.0/podman-linux-${ARCH}.tar.gz -c -O $WORK_DIR/src/podman.tgz
tar zxf $WORK_DIR/src/cri-o.tgz -C $WORK_DIR/src
tar zxf $WORK_DIR/src/podman.tgz -C $WORK_DIR/src
cp -rf $WORK_DIR/src/podman-linux-${ARCH}/* $BUILD_ROOT
rm $BUILD_ROOT/README.md
cat <<EOF | tee $BUILD_ROOT/etc/modules-load.d/cri-o.conf >/dev/null
br_netfilter
EOF
cat <<EOF | tee $BUILD_ROOT/etc/sysctl.d/zz-cri-o.conf >/dev/null
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
fs.may_detach_mounts = 1
EOF
cat <<EOF | tee $BUILD_ROOT/usr/lib/systemd/system/podman.service >/dev/null
[Unit]
Description=Podman API Service
Requires=podman.socket
After=podman.socket
StartLimitIntervalSec=0
[Service]
Delegate=true
Type=exec
KillMode=process
Environment=LOGGING="--log-level=info"
ExecStart=/usr/local/bin/podman $LOGGING system service
[Install]
WantedBy=default.target
EOF

cat <<EOF | tee $BUILD_ROOT/usr/lib/systemd/system/podman.socket >/dev/null
[Unit]
Description=Podman API Socket

[Socket]
ListenStream=%t/podman/podman.sock
SocketMode=0660

[Install]
WantedBy=sockets.target
EOF
(
    cd $WORK_DIR/src/cri-o/ || exit 1
    PREFIX=$BUILD_ROOT/usr/local ETCDIR=$BUILD_ROOT/etc OPT_CNI_BIN_DIR=$BUILD_ROOT/opt/cni/bin ./install
)
cat <<"EOL" >$WORK_DIR/install.sh
#!/bin/bash
PROJECT_HOME=$(
    cd $(dirname ${BASH_SOURCE[0]})
    pwd
)
cp -rfv $PROJECT_HOME/dist/* /
modprobe br_netfilter
sysctl --system
systemctl daemon-reload
systemctl enable crio --now
systemctl enable podman --now
ln -sf /usr/local/bin/podman /usr/local/bin/docker
EOL
dist_path="$WORK_DIR/cri-o-dist.tgz"
(
    # shellcheck disable=SC2046
    cd $(dirname "$DIST_ROOT") || exit
    # shellcheck disable=SC2046
    mv $BUILD_ROOT $DIST_ROOT/dist
    mv -f $WORK_DIR/install.sh $DIST_ROOT/install.sh
    tar zcf "$dist_path" "$(basename $DIST_ROOT)"
)
echo -e "CRI-O 压缩包已导出到 \"$dist_path\",请上传解压后执行 bash install.sh"
