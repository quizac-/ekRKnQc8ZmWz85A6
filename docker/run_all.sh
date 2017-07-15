#!/bin/bash

set -o nounset
set -o errexit

./run_grafana.sh
./run_graphite.sh
# ./install_monitor.sh

sudo docker ps
