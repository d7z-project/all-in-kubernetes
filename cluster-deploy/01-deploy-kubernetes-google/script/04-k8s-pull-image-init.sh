#!/usr/bin/env bash
# 获取kubernetes需要的镜像列表
LIST=$(kubeadm config images list)
for IMAGE in $LIST; do
    # 注意：环境变量 HTTP_PROXY 不会生效，详情可查看 https://github.com/kubernetes-sigs/cri-tools/issues/336
    crictl pull "$IMAGE"
done
# 验证镜像是否全部下载
crictl images
