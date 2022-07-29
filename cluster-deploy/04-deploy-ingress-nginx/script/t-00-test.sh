#!/usr/bin/env bash
# 获取 Nginx 绑定的 loadBalancer ip
CLIENT_IP=$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[*].ip}') # <1>
# 查询路径一绑定的Service - Pod
curl http://$CLIENT_IP/first
# 查询路径二绑定的Service - Pod
curl http://$CLIENT_IP/second
