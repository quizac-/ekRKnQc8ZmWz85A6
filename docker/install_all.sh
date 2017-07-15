#!/bin/bash

set -o nounset
set -o errexit

./install_docker.sh
./install_grafana.sh
./install_graphite.sh
./install_monitor.sh

