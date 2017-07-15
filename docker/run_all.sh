#!/bin/bash

set -o nounset
set -o errexit

./run_grafana.sh
./run_graphite.sh
./run_monitor.sh

sudo docker ps
