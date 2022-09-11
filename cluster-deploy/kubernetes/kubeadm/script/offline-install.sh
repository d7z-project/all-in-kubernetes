#!/bin/bash
tar Czxvf /tmp kubernetes-1.25.0.tgz
cd /tmp/kubernetes-1.25.0 || exit 1
bash -x install.sh
