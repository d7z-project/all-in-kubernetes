#!/usr/bin/env bash
# 部署控制节点
kubeadm init \
    --upload-certs \
    --pod-network-cidr 10.254.0.0/16 \
    --node-name node-master  --kubernetes-version=v1.25.0 | tee ~/kubectl-installer.log
export KUBECONFIG=/etc/kubernetes/admin.conf
# 查看节点状态，有输出则表示成功
kubectl get nodes
