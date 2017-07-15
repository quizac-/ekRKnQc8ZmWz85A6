#!/bin/bash

apt -y update

apt -y install python3 openssl ca-certificates snmp

while :; do
    /mnt/ethermine_to_graphite.py --ethermine --apc-pdu
    sleep 1
done
