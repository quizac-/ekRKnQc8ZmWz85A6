#!/bin/bash

set -o nounset
set -o errexit

mkdir -p /data/statsd /data/graphite/storage /data/graphite/conf

read ct_id ct_status bogus <<< `docker ps -a --filter 'name=graphite-statsd' --format '{{.ID}} {{.Status}}'`
echo "ct_id=$ct_id, ct_status=$ct_status"


if [ "$ct_status" = "" ]; then
    docker run \
        -d \
        -p 2003:2003 \
        -p 2004:2004 \
        -p 2023:2023 \
        -p 2024:2024 \
        -p 8080:80 \
        -p 8125:8125/udp \
        -p 8126:8126 \
        -v '/data/statsd:/opt/statsd' \
        -v '/data/graphite/storage:/opt/graphite/storage' \
        -v '/data/graphite/conf:/opt/graphite/conf' \
        --name=graphite-statsd \
        hopsoft/graphite-statsd:latest

elif [ "$ct_status" = "Exited" ]; then
    docker restart "$ct_id"
fi
