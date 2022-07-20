#!/usr/bin/env bash
IMAGE_NAME=$1
REMOTE_ADDRESS=$2
SAVE_IMG_NAME=$(echo "$IMAGE_NAME" | sed s@/@-@g)
docker pull "$IMAGE_NAME" || exit 1
rm /tmp/export-image-"$USER".tar
docker save -o /tmp/"$SAVE_IMG_NAME" "$IMAGE_NAME"
scp /tmp/"$SAVE_IMG_NAME" "$REMOTE_ADDRESS":/tmp/"$SAVE_IMG_NAME"
# Containerd 需要指定命名空间
ssh "$REMOTE_ADDRESS" "ctr -n=k8s.io image import /tmp/$SAVE_IMG_NAME"
