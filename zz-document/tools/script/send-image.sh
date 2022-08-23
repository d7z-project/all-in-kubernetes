#!/usr/bin/env bash

if [ ! "$1" ] || [ ! "$2" ]; then
    echo "help"
    echo ""
    echo "send-image root@<ip>,root@<ip> image1,image2,res.yaml,res.yml"
    echo ""
    echo "Example: send-image root@10.0.0.1,root@10.0.0.2 busybox,nginx"
    exit 1
fi

# 取配置
IFS=',' read -r -a REMOTES <<<"$1"
IFS=',' read -r -a IMAGE_SOURCES <<<"$2"

FILES=()
IMAGES=()
for IMAGE_SOURCE in ${IMAGE_SOURCES[*]}; do
    # shellcheck disable=SC2086
    if [ -f $IMAGE_SOURCE ] && [[ $IMAGE_SOURCE =~ ^.*(yaml|yml)$ ]]; then
        # shellcheck disable=SC2002
        # shellcheck disable=SC2207
        IMAGES+=($(cat "$IMAGE_SOURCE" | grep "image:" | sed "s/image://g" | xargs echo))
    else
        # shellcheck disable=SC2206
        IMAGES+=($IMAGE_SOURCE)
    fi
done
for IMAGE_NAME in ${IMAGES[*]}; do
    SAVE_IMG_NAME=$(echo "$IMAGE_NAME" | sed -e s@/@-@g -e s/@/-/g)
    if [ "$DEBUG" ]; then
        docker pull "$IMAGE_NAME" || exit 1
    else
        docker pull "$IMAGE_NAME" 1>/dev/null || exit 1
    fi
    if [ ! -f /tmp/"$SAVE_IMG_NAME" ]; then
        docker save -o /tmp/"$SAVE_IMG_NAME" "$IMAGE_NAME" 1>/dev/null
    fi
    # shellcheck disable=SC2179
    FILES+=("/tmp/$SAVE_IMG_NAME")
done

SCRIPT_PATH=/tmp/import-script-"$USER"

rm -f "$SCRIPT_PATH" 1>/dev/null || :
echo "#!/bin/bash" >"$SCRIPT_PATH"
for LOCAL_FILE in ${FILES[*]}; do
    # shellcheck disable=SC2129
    echo "ctr -n=k8s.io image import $LOCAL_FILE" >>"$SCRIPT_PATH"
    echo "/bin/rm -f $LOCAL_FILE" >>"$SCRIPT_PATH"
done

for REMOTE_ADDRESS in ${REMOTES[*]}; do
    # shellcheck disable=SC2086
    if [ $DEBUG ]; then
        scp "$SCRIPT_PATH" ${FILES[*]} "$REMOTE_ADDRESS":/tmp/
        # shellcheck disable=SC2029
        ssh "$REMOTE_ADDRESS" "bash $SCRIPT_PATH"
    else
        scp $SCRIPT_PATH ${FILES[*]} "$REMOTE_ADDRESS":/tmp/ 1>/dev/null
        # shellcheck disable=SC2029
        ssh "$REMOTE_ADDRESS" "bash $SCRIPT_PATH" 1>/dev/null
    fi
done

/bin/rm ${FILES[*]}
