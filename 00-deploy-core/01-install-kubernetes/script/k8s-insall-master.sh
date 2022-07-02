#!/usr/bin/env bash
# 安装控制节点
kubeadm init \
    --upload-certs \
    --pod-network-cidr 10.254.0.0/16 \
    --node-name node-master
