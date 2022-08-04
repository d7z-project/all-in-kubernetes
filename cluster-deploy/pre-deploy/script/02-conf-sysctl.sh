#!/usr/bin/env bash
cat <<EOF | tee /etc/sysctl.d/zz-kubernetes.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system
