#!/usr/bin/env bash
E_FILE='/tmp/kubernetes-offline/images.txt'
readarray -t arr2 <$E_FILE
for data in "${arr2[@]}"; do
    # shellcheck disable=SC2206
    ITEMS=($data)
    echo "${ITEMS[0]}"
    echo "${ITEMS[1]}"
done
