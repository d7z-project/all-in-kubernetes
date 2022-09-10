#!/usr/bin/env bash
mkdir -p /etc/apt/trusted.gpg.d/
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/docker-bullseye.gpg
