#!/bin/bash

set -o nounset
set -o errexit

# Pull Grafana image
sudo docker pull monitoringartist/grafana-xxl

# List images
# sudo docker images

[ ! -d '/data' ] && sudo mkdir '/data'
[ ! -d '/data/grafana' ] && sudo cp -fr 'volumes/grafana' '/data/'
sudo find /data -type f -name 'placeholder' -print0 | sudo xargs -0rn10 rm -f
