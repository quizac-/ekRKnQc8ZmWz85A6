#!/bin/bash


SELF=`readlink -f "$0"`
SELF_DIR=`dirname "$SELF"`

my_pool_host='eu1.ethermine.org'
my_pool_port='4444'
my_pool_ip=`dig $my_pool_host +short | head -n1`


ethos_hosts="bios.ethosdistro.com
ethos1.ethosdistro.com
ethosdistro.com
ETHOSPANEL.ethosdistro.com
mobodb.ethosdistro.com
paste.ethosdistro.com
update2.ethosdistro.com
update.ethosdistro.com
www.ethosdistro.com"
ethos_port=80

pools="asia.ethash-hub.miningpoolhub.com 20535:20538
eth-ar.dwarfpool.com 8008
eth-asia.dwarfpool.com 8008
eth-au.dwarfpool.com 8008
eth-br.dwarfpool.com 8008
eth-cn2.dwarfpool.com 8008
eth-cn.dwarfpool.com 8008
ethermine.ru 8008
eth-eu.dwarfpool.com 8008
eth-hk.dwarfpool.com 8008
eth-ru2.dwarfpool.com 8008
eth-ru.dwarfpool.com 8008
eth-sg.dwarfpool.com 8008
eth-us2.dwarfpool.com 8008
eth-us.dwarfpool.com 8008
eu1.ethermine.org 4444
eu.dwarfpool.com 8008
europe.ethash-hub.miningpoolhub.com 12020,20535:20538
exp-eu.dwarfpool.com 81,8018
hub.miningpoolhub.com 20535:20558
nicehash.com 3333:3361
us1.ethermine.org 4444
us-east1.ethereum.miningpoolhub.com 20536
us-east.ethash-hub.miningpoolhub.com 20535:20538"

pools=`echo -e "$pools" | grep -v "^${my_pool_host} ${my_pool_port}$"`

killall percentage_filter

nohup "$SELF_DIR/percentage_filter/percentage_filter" -f "$SELF_DIR/percentage_filter/percentage_rules.txt" -v >>/root/percentage_rules.log &




iptables-save --counters

ethos_ips=''
for h in $ethos_hosts; do
    ips=`dig $h +short`
    ethos_ips="$ethos_ips\n$ips"
done
ethos_ips=`echo -e "$ethos_ips" | sort -u | egrep -v '[a-z]' | grep -v '^$'`

echo -e "ethos_ips=$ethos_ips"


iptables -F -t nat
iptables -F -t filter

iptables -t filter -N SUBMITLOGIN
iptables -A SUBMITLOGIN -j LOG --log-prefix 'BSUBLOG'
iptables -A SUBMITLOGIN -j NFQUEUE
iptables -A SUBMITLOGIN -j LOG --log-prefix 'ASUBLOG'
iptables -A OUTPUT -p tcp  --sport 1024:65535 --dport 1024:65535 -m string --algo bm --string 'submitLogin' -j SUBMITLOGIN

iptables -t filter -N ETHOS
iptables -t filter -A ETHOS -m string --algo bm --string 'GET /get.php?hostname=' -j REJECT

for ip in $ethos_ips; do
    iptables -t filter -A OUTPUT -p tcp --dport $ethos_port -d $ip -m comment --comment 'ethosdistro' -j REJECT
    iptables -t filter -A OUTPUT -p tcp --dport $ethos_port -d $ip -m comment --comment 'ethosdistro' -j ETHOS
done

# http://ethosdistro.com/get.php

while read pool_host pool_port; do
    while read pool_ip; do
#        iptables -t nat -A OUTPUT -o eth0 -p tcp -d $pool_ip --dport $pool_port -j LOG --log-prefix 'BDNAT'
        iptables -t nat -A OUTPUT -o eth0 -p tcp -d $pool_ip -m multiport --dports $pool_port -m comment --comment "$pool_host" -j DNAT --to $my_pool_ip:$my_pool_port
#        iptables -t nat -A OUTPUT -o eth0 -p tcp -d $pool_ip --dport $pool_port -j LOG --log-prefix 'ADNAT'
    done < <(dig $pool_host +short | sort -u | egrep -v '[a-z]' | grep -v '^$')
done < <(echo -e "$pools")

echo
echo

iptables-save
