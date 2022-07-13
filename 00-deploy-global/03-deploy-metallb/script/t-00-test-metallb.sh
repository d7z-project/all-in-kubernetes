#!/usr/bin/env bash
kubectl get service,pods
# 查看LD 的 IP
kubectl get service -o jsonpath='{.items[*].status.loadBalancer.ingress[*].ip}'
ADDRESS=$(kubectl get service -o jsonpath='{.items[*].status.loadBalancer.ingress[*].ip}')
curl http://$ADDRESS/
