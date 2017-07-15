#!/bin/bash

apt -y update

apt -y install python3 openssl ca-certificates snmp

while :; do
    /mnt/monitor_and_control.py --apc-pdu
    sleep 1
done
