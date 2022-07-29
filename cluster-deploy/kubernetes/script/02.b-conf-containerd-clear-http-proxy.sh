#!/usr/bin/env bash
rm /etc/systemd/system/containerd.service.d/http_proxy.conf ||:
systemctl daemon-reload
systemctl restart containerd.service
