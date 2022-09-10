#!/usr/bin/env bash
cat <<EOF | tee /etc/apt/sources.list.d/docker.list >/dev/null
deb [arch=amd64] https://download.docker.com/linux/debian bullseye stable
# 如第一个地址无法使用，则可以使用国内镜像地址
# deb [arch=amd64] https://mirrors.ustc.edu.cn/docker-ce/linux/debian bullseye stable
EOF
apt-get update
