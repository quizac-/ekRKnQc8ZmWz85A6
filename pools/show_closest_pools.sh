#!/bin/bash

awk '{ print $2}' biggest_pools.txt | sort -u | fping -f - -C1 2>&1 1>/dev/null | awk '$2==":" { print $3" "$1 }' | grep -v '^-' | sort -n | tee closest_pools.txt
