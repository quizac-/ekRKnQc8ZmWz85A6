#!/bin/bash

ETHOS_CONF='/home/ethos/local.conf'

GPU_NUMBER_OF=`ls /sys/class/drm/card[0-9]/ -d | wc -l`
CONF_FAN_HWMON_DIRS=( `ls /sys/class/drm/card[0-9]/device/hwmon/* -d` )
GPU_FAN_LAST=()
GPU_FAN_DELAY=()

generate_fan_steps() {

    CONF_TEMP_TO_FAN_SPEED=()

    for temp in `seq 0 120`; do
        if [ $temp -le 30 ]; then
            CONF_TEMP_TO_FAN_SPEED[$temp]=0
        elif [ $temp -ge 70 ]; then
            CONF_TEMP_TO_FAN_SPEED[$temp]=255
        else
            # fan_speed=`echo "136*s(3.1415*($temp+55)/52.5)+128" | bc -l`
            fan_speed=`echo "135*s(3.1415*($temp+55)/50)+120" | bc -l`
            fan_speed=`printf '%.0f' $fan_speed`
            echo "fan_speed=$fan_speed"
            CONF_TEMP_TO_FAN_SPEED[$temp]=$fan_speed
        fi
        # echo "temp=$temp"

    done

    return 0
}

generate_fan_steps

for I in `seq 0 $[GPU_NUMBER_OF-1]`; do
    HWMON=${CONF_FAN_HWMON_DIRS[$I]}
    #echo "HWMON=$HWMON"
    GPU_FAN_LAST[$I]=0
    GPU_FAN_DELAY[$I]=0
    echo 1 > "$HWMON/pwm1_enable"
done

while :; do
    out=''
    date +%s
    for I in `seq 0 $[GPU_NUMBER_OF-1]`; do
        HWMON=${CONF_FAN_HWMON_DIRS[$I]}
        #echo "HWMON=$HWMON"
        temp_raw=`cat $HWMON/temp1_input`
        [ -z $temp_raw ] && temp_raw=65000
        temp=$[temp_raw/1000]
        # temp=`ohgodatool -i $I --show-temp | tr -d 'C'`
        fan_speed=${CONF_TEMP_TO_FAN_SPEED[$temp]}
        #echo "HWMON=$HWMON, temp=$temp, fan_speed=$fan_speed($[fan_speed*100/255]%)"
        #ohgodatool -i $I --set-fanspeed $[fan_speed*100/255]
        if [ ${GPU_FAN_LAST[$I]} -ne $fan_speed ]; then
            if [ ${GPU_FAN_LAST[$I]} -gt $fan_speed ]; then
                GPU_FAN_DELAY[$I]=$[GPU_FAN_DELAY[$I]+1]
                if [ ${GPU_FAN_DELAY[$I]} -lt 10 ]; then
                    out="${out}GPU$I: ${temp}C/$[GPU_FAN_LAST[$I]*100/255]% "
                    continue
                fi
            fi

            GPU_FAN_DELAY[$I]=0
            echo "$fan_speed" > "$HWMON/pwm1"
            GPU_FAN_LAST[$I]=$fan_speed
        fi
        out="${out}GPU$I: ${temp}C/$[fan_speed*100/255]% "
    done
    date +%s
    echo $out
    sleep 3
done


#declare | egrep -v '^(BASH|BASHOPTS|BASH_ALIASES|BASH_ARGC|BASH_ARGV|BASH_CMDS|BASH_LINENO|BASH_SOURCE|BASH_VERSINFO|BASH_VERSION|DIRSTACK|DISPLAY|EUID|GROUPS|HISTCONTROL|HOME|HOSTNAME|HOSTTYPE|IFS|LANG|LD_LIBRARY_PATH|LESSCLOSE|LESSOPEN|LOGNAME|LS_COLORS|MACHTYPE|MAIL|MC_SID|MC_TMPDIR|OPTERR|OPTIND|OSTYPE|PATH|PIPESTATUS|PPID|PS4|PWD|SHELL|SHELLOPTS|SHLVL|TERM|UID|USER|XDG_RUNTIME_DIR|XDG_SESSION_ID|_)='


