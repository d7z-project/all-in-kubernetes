#!/usr/bin/env bash
kubectl get pods,pvc
echo; kubectl exec $(kubectl get pod -l app=nfs-demo,role=busybox -o jsonpath='{.items[0].metadata.name}') \
 -- wget -qO- http://$(kubectl get services nfs-web -o jsonpath='{.spec.clusterIP}'); echo
