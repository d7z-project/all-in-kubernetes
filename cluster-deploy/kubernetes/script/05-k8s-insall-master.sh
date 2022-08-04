#!/usr/bin/env bash
unset http_proxy
unset https_proxy
# 安装控制节点
kubeadm init \
    --upload-certs \
    --pod-network-cidr 10.254.0.0/16 \
    --node-name node-master  --kubernetes-version=v1.24.3 | tee /tmp/kubectl-installer.log
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> ~/.bashrc
source ~/.bashrc
sleep 5
# 查看节点状态，有输出则表示成功
kubectl get nodes
