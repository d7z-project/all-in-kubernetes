#!/bin/bash
tar Czxvf /tmp kubernetes-1.25.2.tgz
cd /tmp/kubernetes-1.25.2 || exit 1
bash -x install.sh
