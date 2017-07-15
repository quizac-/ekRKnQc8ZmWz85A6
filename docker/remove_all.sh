#!/bin/bash

set -o nounset
set -o errexit

sudo docker ps -a --format '{{.ID}}' | while read ct_id; do
    sudo docker stop "$ct_id"
    sudo docker rm "$ct_id"
done

sudo docker images --format '{{.ID}}' | while read im_id; do
    sudo docker rmi "$im_id"
done

