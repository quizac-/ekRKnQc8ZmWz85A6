#!/bin/bash

MINER_LOG='/var/run/miner.output'
ALLOW_FILE='/opt/ethos/etc/allow.file'
HOSTNAME_SHORT=`hostname -s`
MINER='claymore'
PRODUCT='ETH'

# GPU #0: Ellesmere, 8148 MB available, 36 compute units
# GPU #1: Ellesmere, 8148 MB available, 36 compute units
# GPU #2: Ellesmere, 8148 MB available, 36 compute units
# GPU #3: Ellesmere, 8148 MB available, 36 compute units
# GPU #4: Ellesmere, 8148 MB available, 36 compute units
# GPU #5: Ellesmere, 8148 MB available, 36 compute units
# ETH - Total Speed: 168.232 Mh/s, Total Shares: 77(7+15+9+16+20+12), Rejected: 0, Time: 00:33
# ETH: GPU0 28.056 Mh/s, GPU1 28.096 Mh/s, GPU2 28.091 Mh/s, GPU3 28.082 Mh/s, GPU4 27.831 Mh/s, GPU5 28.077 Mh/s
# Incorrect ETH shares: none
# Pool switches: ETH - 0, DCR - 0
# Current ETH share target: 0x0000000112e0be82 (diff: 4000MH), epoch #133
# GPU0 t=50C fan=61%, GPU1 t=49C fan=60%, GPU2 t=52C fan=67%, GPU3 t=48C fan=54%, GPU4 t=47C fan=51%, GPU5 t=46C fan=48%

# /sys/kernel/debug/dri/0/amdgpu_pm_info
# [  mclk  ]: 2100 MHz
# [  sclk  ]: 1145 MHz
# [GPU load]: 100%
#

add_to_graphite() {
    local metrics="$1"

    [ -z "$EPOCH" ] && EPOCH=`date '+%s'`

    GRAPHITE_OUT="${GRAPHITE_OUT}mining.${HOSTNAME_SHORT}.${metrics} $EPOCH\n"

    return 0
}


send_to_graphite() {
    local graphite_host='10.0.0.244'
    local graphite_port='32003'

    # echo -e "Sending: $GRAPHITE_OUT"
    [ -n "$GRAPHITE_OUT" ] && echo -e "$GRAPHITE_OUT" | nc -4 -n -w2 "$graphite_host" "$graphite_port"
    GRAPHITE_OUT=''

    return 0
}

new_mining() {
    GPU_HASH_SPEED_MAX=()
    GPU_SLOWDOWN_EPOCHS=()
    MINER_LOG_SIZE_LAST=0

    add_to_graphite "new 1"
    send_to_graphite
}


restart_miner() {

    add_to_graphite "restart 1"
    new_mining
    minestop
    minestart

    return 0
}


new_mining

while :; do
    GRAPHITE_OUT=''
    EPOCH=`date '+%s'`

    UPTIME=`cat /proc/uptime | cut -d' ' -f1`
    add_to_graphite "uptime $UPTIME"

    MINING_ALLOWED=`cat "$ALLOW_FILE" 2>/dev/null`
    [ -z "$MINING_ALLOWED" ] && MINING_ALLOWED=0
    add_to_graphite "allowed $MINING_ALLOWED"

    for NO_LOG_TIMOUT in `seq 299 -1 0`; do
        [ -f "$MINER_LOG" ] && break
        echo "Waiting $NO_LOG_TIMOUT seconds for miner log to appear"
        sleep 1
    done

    if [ $NO_LOG_TIMOUT -eq 0 ]; then
        add_to_graphite "log 0"
        send_to_graphite

        if [ "$MINING_ALLOWED" = "1" ]; then
            echo "MINING_ALLOWED=$MINING_ALLOWED, no miner log present. Starting miner"
            restart_miner
            continue
        else
            echo "MINING_ALLOWED=$MINING_ALLOWED, no miner log present. Waiting"
            continue
        fi
    fi
    add_to_graphite "log 1"

    MINER_LOG_SIZE=`stat -c '%s' "$MINER_LOG"`
    [ -z "$MINER_LOG_SIZE" ] && MINER_LOG_SIZE=0


    EPOCH_MINER_LOG_MTIME=`stat -c '%Y' "$MINER_LOG"`
    [ -z "$EPOCH_MINER_LOG_MTIME" ] && EPOCH_MINER_LOG_MTIME=0
    DELTA=$[EPOCH-EPOCH_MINER_LOG_MTIME]

    if [ $DELTA -ge 60 ]; then
        echo "Miner log not updated within $DELTA seconds. Restarting miner"
        restart_miner
        sleep 10
        continue
    fi


    MINER_LOG_TAIL=`tail -n30 "$MINER_LOG" | sed -r -e 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g' -e 's/\x0f//g' | tr -d '\r'`

    #GPU_FAN_PERCENT=( `echo -e "$MINER_LOG_TAIL" | grep '^GPU0 t=' | tail -n1 | tr ' ' '\n' | sed -rne 's/^fan=([0-9]+)%.*$/\1/gp' | tr '\n' ' '` )
    GPU_HASH_SPEED=( `echo -e "$MINER_LOG_TAIL" | grep '^ETH:' | grep -F 'Mh/s' | tail -n1 | tr ' ' '\n' | sed -rne 's/^([0-9\.]+)$/\1/gp' | tr '\n' ' '` )
    GPU_SHARES=( `echo -e "$MINER_LOG_TAIL" | grep '^ETH' | grep -F 'Total Shares:' | tail -n1 | sed -r 's/^.*\(([0-9\+]+)\).*$/\1/g' | tr '+' '\n'` )
    # GPU_TEMP_DEG=( `echo -e "$MINER_LOG_TAIL" | grep '^GPU0 t=' | tail -n1 | tr ' ' '\n' | sed -rne 's/^t=([0-9]+)C.*$/\1/gp' | tr '\n' ' '` )
    REJECTED_SHARES=`echo -e "$MINER_LOG_TAIL" | egrep -o 'Rejected: [0-9]+' | tail -n1 | awk '{ print $2 }'`
    TOTAL_HASH_SPEED=`echo -e "$MINER_LOG_TAIL" | awk '/Total Speed:/ { print $5 }' | tail -n1`

    for I in `seq 0 $[${#GPU_SHARES[@]}-1]`; do
        GPU_MCLK[$I]=`awk '/mclk/ { print $4 }' /sys/kernel/debug/dri/$I/amdgpu_pm_info`
        GPU_SCLK[$I]=`awk '/sclk/ { print $4 }' /sys/kernel/debug/dri/$I/amdgpu_pm_info`
        GPU_LOAD[$I]=`awk '/GPU load/ { print $3 }' /sys/kernel/debug/dri/$I/amdgpu_pm_info | tr -d '%'`

        add_to_graphite "GPU.$I.load ${GPU_LOAD[$I]}"
        add_to_graphite "GPU.$I.sclk ${GPU_SCLK[$I]}"
        add_to_graphite "GPU.$I.mclk ${GPU_MCLK[$I]}"
        # add_to_graphite "GPU.$I.temp ${GPU_TEMP_DEG[$I]}"
        # add_to_graphite "GPU.$I.fan ${GPU_FAN_PERCENT[$I]}"
        add_to_graphite "GPU.$I.ETH.hashrate ${GPU_HASH_SPEED[$I]}"
        add_to_graphite "GPU.$I.ETH.shares ${GPU_SHARES[$I]}"
    done

    add_to_graphite "total.rejected_shares $REJECTED_SHARES"
    add_to_graphite "total.hashrate $TOTAL_HASH_SPEED"


    for I in `seq 0 $[${#GPU_HASH_SPEED[@]}-1]`; do
        HASH_SPEED_CUR=${GPU_HASH_SPEED[$I]}
        HASH_SPEED_MAX=${GPU_HASH_SPEED_MAX[$I]}
        if [ -z "$HASH_SPEED_MAX" ]; then
            HASH_SPEED_MAX=0
            GPU_HASH_SPEED_MAX[$I]=0
        fi


        DELTA=`echo "$HASH_SPEED_CUR>$HASH_SPEED_MAX" | bc -l`
        if [ "$DELTA" = "1" ]; then
            GPU_HASH_SPEED_MAX[$I]=$HASH_SPEED_CUR
        fi

        # echo "I=$I, HASH_SPEED_CUR=$HASH_SPEED_CUR, HASH_SPEED_MAX=$HASH_SPEED_MAX"

        HASH_SPEED_MAX_PERCENT=`echo "$HASH_SPEED_MAX*75/100" | bc -l`
        DELTA=`echo "$HASH_SPEED_MAX_PERCENT>$HASH_SPEED_CUR" | bc -l`
        if [ "$DELTA" = "1" ]; then
            add_to_graphite "GPU.$I.slow 1"
            echo "GPU$I slowed down to $HASH_SPEED_CUR Mh/s."
            SLOWDOWN_EPOCH=${GPU_SLOWDOWN_EPOCHS[$I]}
            [ -z "$SLOWDOWN_EPOCH" ] && SLOWDOWN_EPOCH=0

            if [ $SLOWDOWN_EPOCH -ne 0 ]; then
                DELTA=$[EPOCH-SLOWDOWN_EPOCH]
                echo "I=$I, DELTA=$DELTA"
                if [ $DELTA -ge 60 ]; then
                    echo "Restarting miner due to GPU$I slowing down."
                    restart_miner
                    sleep 10
                    continue
                fi
            else
                GPU_SLOWDOWN_EPOCHS[$I]=$EPOCH
            fi
        else
            GPU_SLOWDOWN_EPOCHS[$I]=0
            add_to_graphite "GPU.$I.slow 0"
        fi
    done


    send_to_graphite

    # declare | egrep -v '^(BASH|BASHOPTS|BASH_ALIASES|BASH_ARGC|BASH_ARGV|BASH_CMDS|BASH_LINENO|BASH_SOURCE|BASH_VERSINFO|BASH_VERSION|DIRSTACK|DISPLAY|EUID|GROUPS|HISTCONTROL|HOME|HOSTNAME|HOSTTYPE|IFS|LANG|LD_LIBRARY_PATH|LESSCLOSE|LESSOPEN|LOGNAME|LS_COLORS|MACHTYPE|MAIL|MC_SID|MC_TMPDIR|OPTERR|OPTIND|OSTYPE|PATH|PIPESTATUS|PPID|PS4|PWD|SHELL|SHELLOPTS|SHLVL|TERM|UID|USER|XDG_RUNTIME_DIR|XDG_SESSION_ID|_)='
    # exit

    MINER_LOG_SIZE_LAST=$MINER_LOG_SIZE
    sleep 9
done

