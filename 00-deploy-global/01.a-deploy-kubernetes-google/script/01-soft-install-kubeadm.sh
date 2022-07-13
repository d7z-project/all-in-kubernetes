#!/usr/bin/env bash
apt-get install -y apt-transport-https ca-certificates curl
# 导入公钥对
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
# 配置 APT
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://mirrors.ustc.edu.cn/kubernetes/apt/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
# 安装 kubeadm
apt-get install -y kubelet kubeadm kubectl cri-tools
# 锁定 kubernetes 版本
apt-mark hold kubelet kubeadm kubectl cri-tools
# 配置 cri-tools
cat << EOF | tee /etc/crictl.yaml
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
EOF
