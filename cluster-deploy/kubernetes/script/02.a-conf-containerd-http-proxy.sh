#!/usr/bin/env bash
mkdir /etc/systemd/system/containerd.service.d ||:
cat << "EOF" > /etc/systemd/system/containerd.service.d/http_proxy.conf
[Service]
# 此处配置为可用的 HTTP 代理地址
Environment="HTTP_PROXY=http://10.0.0.2:8080"
# 此处配置为可用的 HTTP 代理地址
Environment="HTTPS_PROXY=http://10.0.0.2:8080"
# 此处配置为跳过代理的地址
Environment="NO_PROXY=localhost,127.0.0.1,10.0.0.20"
EOF
systemctl daemon-reload
systemctl restart containerd.service
