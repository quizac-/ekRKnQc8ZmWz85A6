#!/bin/bash

set -o nounset
set -o errexit

read ct_id ct_status bogus <<< `sudo docker ps -a --filter 'name=grafana' --format '{{.ID}} {{.Status}}'`
echo "ct_id=$ct_id, ct_status=$ct_status"


if [ "$ct_status" = "" ]; then
    # All options defined in conf/grafana.ini can be overriden using environment variables by using the syntax GF__. For example:
    sudo docker run \
        -d \
        -p 80:3000 \
        --name=grafana \
        -v '/data/grafana/lib:/var/lib/grafana' \
        -v '/data/grafana/log:/var/log/grafana' \
        -v '/data/grafana/conf:/etc/grafana' \
        monitoringartist/grafana-xxl:latest

elif [ "$ct_status" = "Exited" ]; then
    sudo docker restart "$ct_id"
fi

