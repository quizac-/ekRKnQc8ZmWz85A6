#!/bin/bash

set -o nounset
set -o errexit

read ct_id ct_status bogus <<< `sudo docker ps -a --filter 'name=monitor' --format '{{.ID}} {{.Status}}'`
echo "ct_id=$ct_id, ct_status=$ct_status"


if [ "$ct_status" = "" ]; then
    sudo docker run \
        -td \
        -v '/data/monitor:/mnt' \
        --name=monitor \
        ubuntu:latest \
        /mnt/init.sh

elif [ "$ct_status" = "Exited" ]; then
    sudo docker restart "$ct_id"
fi
