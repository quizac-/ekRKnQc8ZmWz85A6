#!/bin/bash

set -o nounset
set -o errexit

# Pull Grafana image
docker pull monitoringartist/grafana-xxl

# List images
docker images
