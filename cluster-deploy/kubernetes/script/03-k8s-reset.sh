#!/usr/bin/env bash
# 重置 kubeadm
yes | kubeadm reset
# 删除 CNI 插件残留
rm -rf /etc/cni/net.d/
