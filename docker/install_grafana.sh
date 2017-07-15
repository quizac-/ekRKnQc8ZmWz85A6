#!/bin/bash

set -o nounset
set -o errexit

# Pull Grafana image
docker pull monitoringartist/grafana-xxl

# List images
docker images

mkdir -p /data/grafana/log /data/grafana/lib

# All options defined in conf/grafana.ini can be overriden using environment variables by using the syntax GF__. For example:
docker run \
    -d \
    -p 3000:3000 \
    --name=grafana-xxl \
    -v '/data/grafana/lib:/var/lib/grafana' \
    -v '/data/grafana/log:/var/log/grafana' \
    -e 'GF_SECURITY_ADMIN_PASSWORD=W6pFD4.C' \
    monitoringartist/grafana-xxl:latest
