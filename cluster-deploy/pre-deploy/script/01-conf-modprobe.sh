#!/usr/bin/env bash
cat <<EOF | tee /etc/modules-load.d/kubernetes.conf
br_netfilter
EOF
modprobe br_netfilter
