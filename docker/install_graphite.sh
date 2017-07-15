#!/bin/bash

set -o nounset
set -o errexit

# Pull Grafana image
docker pull hopsoft/graphite-statsd

# List images
docker images
