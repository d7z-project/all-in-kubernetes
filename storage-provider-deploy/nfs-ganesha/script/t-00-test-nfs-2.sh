#!/usr/bin/env bash
# 验证创建结果
kubectl get deploy,pvc,pods -l mode=test,app=nfs-ganesha
# 测试结果
CLUSTER_IP=$(kubectl get services svc-test-nfs-ganesha -o jsonpath='{.spec.clusterIP}')
POD_NAME=$(kubectl get pod -l app=nfs-ganesha,role=busybox -o jsonpath='{.items[0].metadata.name}')
kubectl exec "$POD_NAME" -- wget -qO- http://"$CLUSTER_IP"
