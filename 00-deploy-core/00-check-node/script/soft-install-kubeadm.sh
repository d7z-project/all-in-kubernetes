#!/usr/bin/env bash
apt-get install -y apt-transport-https ca-certificates curl
# 导入公钥对
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
# 配置 APT
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
# 安装 kubeadm
sudo apt-get install -y kubelet kubeadm kubectl
# 锁定 kubernetes 版本
sudo apt-mark hold kubelet kubeadm kubectl
