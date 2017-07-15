#!/bin/bash

rfkill block bluetooth
cp -f /root/tuning/mawi-blacklist.conf /etc/modprobe.d/mawi-blacklist.conf

echo 'powersave' > /sys/module/pcie_aspm/parameters/policy
echo 'powersave' > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null


echo 1 > /sys/devices/system/cpu/cpu0/online
echo 1 > /sys/devices/system/cpu/cpu1/online

I=2
while [ -f "/sys/devices/system/cpu/cpu$I/online" ]; do
    echo 0 > /sys/devices/system/cpu/cpu$I/online
    I=$[I+1]
done


while [ -f "/sys/class/scsi_host/host$I/link_power_management_policy" ]; do
    echo min_power > /sys/class/scsi_host/host$I/link_power_management_policy
    I=$[I+1]
done
