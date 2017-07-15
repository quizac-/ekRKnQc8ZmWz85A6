#!/bin/bash

set -o nounset
set -o errexit

mkdir -p /data/grafana/log /data/grafana/lib

read ct_id ct_status bogus <<< `docker ps -a --filter 'name=grafana-xxl' --format '{{.ID}} {{.Status}}'`
echo "ct_id=$ct_id, ct_status=$ct_status"


if [ "$ct_status" = "" ]; then
    # All options defined in conf/grafana.ini can be overriden using environment variables by using the syntax GF__. For example:
    docker run \
        -d \
        -p 3000:3000 \
        --name=grafana-xxl \
        -v '/data/grafana/lib:/var/lib/grafana' \
        -v '/data/grafana/log:/var/log/grafana' \
        -e 'GF_SECURITY_ADMIN_PASSWORD=W6pFD4.C' \
        monitoringartist/grafana-xxl:latest

elif [ "$ct_status" = "Exited" ]; then
    docker restart "$ct_id"
fi
