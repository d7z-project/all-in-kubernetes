#!/usr/bin/env bash
REMOTE_ADDRESSES=$1
IMAGES_NAME=$2

if [ ! "$IMAGES_NAME" ] || [ ! "$REMOTE_ADDRESSES" ]; then
    echo "help"
    echo ""
    echo "send-image root@<ip>,root@<ip> image1,image2"
    echo ""
    echo "Example: send-image root@10.0.0.1,root@10.0.0.2 busybox,nginx"
    exit 1
fi

IFS=',' read -r -a IMAGES <<<"$IMAGES_NAME"
IFS=',' read -r -a REMOTES <<<"$REMOTE_ADDRESSES"

echo "开始导出镜像"
FILES=()
for IMAGE_NAME in ${IMAGES[*]}; do
    echo "导出 $IMAGE_NAME ."
    SAVE_IMG_NAME=$(echo "$IMAGE_NAME" | sed s@/@-@g)
    docker pull "$IMAGE_NAME" || exit 1
    if [ -f /tmp/"$SAVE_IMG_NAME" ]; then
        echo "文件 /tmp/$SAVE_IMG_NAME 已存在，跳过导出。"
    else
        docker save -o /tmp/"$SAVE_IMG_NAME" "$IMAGE_NAME"
    fi
    # shellcheck disable=SC2179
    FILES+=("/tmp/$SAVE_IMG_NAME")
    echo "导出 $IMAGE_NAME 完成."
done
rm -f /tmp/import-script-"$USER" || :
echo "#!/bin/bash" >/tmp/import-script-"$USER"
for LOCAL_FILE in ${FILES[*]}; do
    echo "ctr -n=k8s.io image import $LOCAL_FILE" >>/tmp/import-script-"$USER"
    echo "/bin/rm -f $LOCAL_FILE" >>/tmp/import-script-"$USER"
done

echo "开始传输文件"
for REMOTE_ADDRESS in ${REMOTES[*]}; do
    # shellcheck disable=SC2086
    scp /tmp/import-script-"$USER" ${FILES[*]} "$REMOTE_ADDRESS":/tmp/
    ssh "$REMOTE_ADDRESS" "bash /tmp/import-script-$USER"
done

/bin/rm ${FILES[*]}
