#!/usr/bin/env bash
IMAGE_NAME=$1
REMOTE_ADDRESS=$2
docker pull "$IMAGE_NAME" || exit 1
rm /tmp/export-image-"$USER".tar
docker save -o /tmp/export-image-"$USER".tar "$IMAGE_NAME"
scp /tmp/export-image-"$USER".tar "$REMOTE_ADDRESS":/tmp/export-image-"$USER".tar
ssh $REMOTE_ADDRESS "ctr image import /tmp/export-image-"$USER".tar"
