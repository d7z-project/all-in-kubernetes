#!/usr/bin/env bash
tar zxvf k8s.tgz
cd k8s || exit 1
bash -x install.sh
