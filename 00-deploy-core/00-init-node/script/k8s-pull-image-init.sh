#!/usr/bin/env bash
# 获取kubernetes需要的镜像列表
LIST=$(kubeadm config images list)
for IMAGE in $LIST; do
    ctr i pull "$IMAGE"
done
# 验证镜像是否全部下载
ctr i list
