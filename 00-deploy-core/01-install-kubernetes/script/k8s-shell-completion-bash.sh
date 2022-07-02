#!/usr/bin/env bash
# 针对 bash 添加代码补全功能
mkdir -p /etc/bash_completion.d ||:
# 导入 kubectl
kubectl completion bash | tee /etc/bash_completion.d/kubectl > /dev/null
# 导入 kubeadm
kubeadm completion bash | tee /etc/bash_completion.d/kubeadm > /dev/null
# 导入 cri-tools
crictl completion bash | tee /etc/bash_completion.d/kubeadm > /dev/null
source /usr/share/bash-completion/bash_completion
