#!/usr/bin/env bash
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://mirrors.ustc.edu.cn/docker-ce/linux/debian $(lsb_release -cs) stable" |  tee /etc/apt/sources.list.d/containerd.list > /dev/null
sudo apt update
sudo apt install containerd -y
