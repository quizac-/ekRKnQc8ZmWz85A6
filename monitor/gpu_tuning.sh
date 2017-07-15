#!/bin/bash

# cor 8a5ee8 1150 1150 1150 1150 1150 1150 1150 1150
# mem 8a5ee8 2100 2100 2100 2100 2100 2100 2100 2100
# pwr 8a5ee8 2    2    2    2    2    2    2    2
# fan 8a5ee8 65   65   65   65   65   65   65   65

# 40C:speed 0, 80C:speed 255(max)
# default:
# local fan 40C:0% 70C:100%
DEF_TEMP_MIN=40
DEF_FAN_MIN=0
DEF_TEMP_MAX=70
DEF_FAN_MAX=100

# Powertune from /sys/class/drm/card0/device/pp_dpm_sclk
# 0: 300Mhz
# 1: 751Mhz
# 2: 1048Mhz
# 3: 1150Mhz *
# 4: 1240Mhz
# 5: 1309Mhz
# 6: 1364Mhz
# 7: 1411Mhz


ETHOS_CONF='/home/ethos/local.conf'
MINER_LOG='/var/run/miner.output'

GPU_NUMBER_OF=`ls /sys/class/drm/card[0-9]/ -d | wc -l`
GPU_CORE_MHZ_DEFAULT=( `tail -n1 /sys/class/drm/card[0-9]/device/pp_dpm_sclk | grep -Poi "(?<=\d\: )(\d+)" | tr '\n' ' '` )
GPU_MEMORY_MHZ_DEFAULT=( `tail -n1 /sys/class/drm/card[0-9]/device/pp_dpm_mclk | grep -Poi "(?<=\d\: )(\d+)" | tr '\n' ' '` )
CONF_FAN_HWMON_DIRS=( `ls /sys/class/drm/card[0-9]/device/hwmon/* -d` )

read temp_min fan_min temp_max fan_max <<<`sed -rne 's/local\s+fan\s//gp' /home/ethos/local.conf | sed -r 's/[^0-9]+/ /g'`
if [ -z "$temp_min" -o -z "$fan_min" -o -z "$temp_max" -o -z "$fan_max" ]; then
    temp_min=$DEF_TEMP_MIN
    fan_min=$DEF_FAN_MIN
    temp_max=$DEF_TEMP_MAX
    fan_max=$DEF_FAN_MAX
fi

fan_min=$[fan_min*255/100]
fan_max=$[fan_max*255/100]

CONF_TEMP_TO_FAN_SPEED=()

for temp in `seq 0 120`; do
    if [ $temp -le $temp_min ]; then
        CONF_TEMP_TO_FAN_SPEED[$temp]=$fan_min
    elif [ $temp -ge $temp_max ]; then
        CONF_TEMP_TO_FAN_SPEED[$temp]=$fan_max
    else
        CONF_TEMP_TO_FAN_SPEED[$temp]=$[$[fan_max-fan_min] * $[100 * $[temp-temp_min] / $[temp_max-temp_min]] / 100]
    fi
    # echo "temp=$temp"

done


GPU_MEMORY_MHZ_CONF=( `awk '$1=="mem" {$1=$2=""; print $0}' "$ETHOS_CONF"` )
GPU_CORE_MHZ_CONF=( `awk '$1=="cor" {$1=$2=""; print $0}' "$ETHOS_CONF"` )
GPU_POWER_TUNE_CONF=( `awk '$1=="pwr" {$1=$2=""; print $0}' "$ETHOS_CONF"` )
GPU_VOLTAGE_CONF=( `awk '$1=="vlt" {$1=$2=""; print $0}' "$ETHOS_CONF"` )


MINER_LOG_TAIL=`tail -n10 "$MINER_LOG" | sed -r -e 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g' -e 's/\x0f//g'`
TOTAL_HASH_SPEED=`echo -e "$MINER_LOG_TAIL" | awk '/Total Speed:/ { print $5 }' | tail -n1`
GPU_TEMP_DEG_NOW=( `echo -e "$MINER_LOG_TAIL" | grep '^GPU0 t=' | tail -n1 | tr ' ' '\n' | sed -rne 's/^t=([0-9]+)C.*$/\1/gp' | tr '\n' ' '` )
GPU_FAN_PERCENT_NOW=( `echo -e "$MINER_LOG_TAIL" | grep '^GPU0 t=' | tail -n1 | tr ' ' '\n' | sed -rne 's/^fan=([0-9]+)%.*$/\1/gp' | tr '\n' ' '` )











declare | egrep -v '^(BASH|BASHOPTS|BASH_ALIASES|BASH_ARGC|BASH_ARGV|BASH_CMDS|BASH_LINENO|BASH_SOURCE|BASH_VERSINFO|BASH_VERSION|DIRSTACK|DISPLAY|EUID|GROUPS|HISTCONTROL|HOME|HOSTNAME|HOSTTYPE|IFS|LANG|LD_LIBRARY_PATH|LESSCLOSE|LESSOPEN|LOGNAME|LS_COLORS|MACHTYPE|MAIL|MC_SID|MC_TMPDIR|OPTERR|OPTIND|OSTYPE|PATH|PIPESTATUS|PPID|PS4|PWD|SHELL|SHELLOPTS|SHLVL|TERM|UID|USER|XDG_RUNTIME_DIR|XDG_SESSION_ID|_)='
