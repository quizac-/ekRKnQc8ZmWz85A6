#!/bin/bash

set -o nounset
set -o errexit

# Pull Grafana image
sudo docker pull ubuntu

[ ! -d '/data/monitor' ] && sudo cp -fr 'volumes/monitor' '/data/'
sudo find /data -type f -name 'placeholder' -print0 | sudo xargs -0rn10 rm -f
