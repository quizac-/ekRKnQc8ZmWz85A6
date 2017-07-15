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
        -p 80:3000 \
        --name=grafana-xxl \
        -v '/data/grafana/lib:/var/lib/grafana' \
        -v '/data/grafana/log:/var/log/grafana' \
        -e 'GF_SECURITY_ADMIN_PASSWORD=W6pFD4.C' \
        -e 'GF_SMTP_PASSWORD=haderah1' \
        -e 'GF_SMTP_FROM_ADDRESS=quizac.automation@gmail.com' \
        -e 'GF_SMTP_HOST=smtp.gmail.com:465' \
        -e 'GF_SMTP_USER=quizac.automation@gmail.com' \
        -e 'GF_SMTP_ENABLED=true' \
        monitoringartist/grafana-xxl:latest

elif [ "$ct_status" = "Exited" ]; then
    docker restart "$ct_id"
fi

