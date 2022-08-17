#!/usr/bin/env bash
# cni 插件 需要 wireguard 软件包，rook-nfs 需要 nfs-common 软件包 ,kubernetes 需要 conntrack 软件包
apt-get install -y wireguard wireguard-tools nfs-common conntrack lvm2 iptables
