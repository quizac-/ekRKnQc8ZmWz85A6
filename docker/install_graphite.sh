#!/bin/bash

set -o nounset
set -o errexit

# Pull Grafana image
sudo docker pull hopsoft/graphite-statsd

[ ! -d '/data' ] && sudo mkdir '/data'
[ ! -d '/data/graphite' ] && sudo cp -fr 'volumes/graphite' '/data/'
# [ ! -d '/data/statsd' ] && sudo cp -fr 'volumes/statsd' '/data/'
sudo find /data -type f -name 'placeholder' -print0 | sudo xargs -0rn10 rm -f
