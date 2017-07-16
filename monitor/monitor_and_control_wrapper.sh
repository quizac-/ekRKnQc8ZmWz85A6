#!/bin/bash

SELF_FQDN=`readlink -f "$0"`
SELF_DIR=`dirname "$SELF_FQDN"`


apt -y update

apt -y install python3 openssl ca-certificates snmp python3-dateutil

while :; do
    "$SELF_DIR/monitor_and_control.py" $@
    sleep 1
done
