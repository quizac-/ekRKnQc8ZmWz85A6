#!/usr/bin/env python3

# SNMPv2-SMI::enterprises.318.1.1.12.2.3.1.1.2.1 = Gauge32: 43
# snmpget -r0 -t1 -v1 -c public -O qv 10.0.0.249 .1.3.6.1.4.1.318.1.1.12.2.3.1.1.2.1

import urllib.request
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError
import json
import time
import socket
import traceback
import logging
import subprocess
import sys
import argparse
import re
import math


HOSTNAME            = socket.gethostname().split('.')[0]
GRAPHITE_SERVER     = '10.0.0.244'
GRAPHITE_PORT       = 32003
INTERVAL            = 59
WALLET              = '82BB67244a0CBaFFeC4709ebD66C36dFD6eF428b'
ETHERMINE_API       = 'https://ethermine.org/api/miner_new/'
ETHERMINE_URL       = ETHERMINE_API + WALLET
ETHERMINE_INTERVAL  = 60
APC_PDU_INTERVAL    = 60
SENSORS_INTERVAL    = 3
GPU_FAN_INTERVAL    = 3

gpu_temperature = []


def connect_to_graphite():
    sock = socket.socket()
    sock.settimeout(2)

    try:
        sock.connect((GRAPHITE_SERVER, GRAPHITE_PORT))
    except Exception as e:
        print('Graphite socket failed')
        return

    # print('Graphite connected')

    return sock


def send_to_graphite(sock, message):
    if not message:
        return True

    # print('sending message:\n%s' % message)

    try:
        sock.sendall(message.encode())
    except Exception as e:
        print('Graphite send failed')
        sock.close()
        return False

    # print('messsage sent')
    return True


def sleep_until_epoch(wake_up_epoch):
    delta = wake_up_epoch - int(time.time())

    if delta > 0:
        # print('sleeping for %d seconds' % (delta))
        time.sleep(delta)


def get_apc_pdu_stats(timestamp):
    graphite_lines = []
    # print('calling snmpget')
    stdoutdata = subprocess.getoutput("snmpget -r0 -t1 -v1 -c public -O qv 10.0.0.249 .1.3.6.1.4.1.318.1.1.12.2.3.1.1.2.1 2>/dev/null")
    # print('snmpget finished')

    if stdoutdata:
        try:
            ampers = float(stdoutdata)
            ampers /= 10
        except Exception as e:
            print('no float delivered')
            return graphite_lines

        # Hochtarif (HT) Montag bis Freitag 07:00 . 20:00 Uhr = 65h
        #                           Samstag 07:00 . 13:00 Uhr =  6h
        # Niedertarif (NT) uebrige Zeiten
        # wk = 168h
        # HT = 71h/wk * 0.2026
        # NT = 97h * 0.1351
        # (71h*0.2026CHF + 97h*0.1351CHF) / 168 = 0.16362678571 CHF avg
        watts = ampers * 240
        kWh = watts/1000
        chf_per_hour    = 0.16362678571 * kWh
        chf_per_day     = chf_per_hour * 24
        chf_per_week    = chf_per_day * 7
        chf_per_month   = chf_per_week * 4.34
        chf_per_year    = chf_per_day * 365

        graphite_lines.append('pdu.1.total_load %s %d' % (ampers, timestamp))
        graphite_lines.append('pdu.1.watts %s %d' % (watts, timestamp))
        graphite_lines.append('pdu.1.CHFperHour %s %d' % (chf_per_hour, timestamp))
        graphite_lines.append('pdu.1.CHFperDay %s %d' % (chf_per_day, timestamp))
        graphite_lines.append('pdu.1.CHFperWeek %s %d' % (chf_per_week, timestamp))
        graphite_lines.append('pdu.1.CHFperMonth %s %d' % (chf_per_month, timestamp))
        graphite_lines.append('pdu.1.CHFperYear %s %d' % (chf_per_year, timestamp))
    else:
        print('no stdoutdata')

    return graphite_lines


def get_ethermine_stats(timestamp):
    graphite_lines = []
    # print('urlopen to ethermine')
    try:
        req = Request(ETHERMINE_URL)
        req.add_header('User-Agent', 'Mozilla/5.0')
        res = urlopen(req, None, 2)
    except HTTPError as e:
        print('urlopen failed. Error code: ', e.code)
        return graphite_lines
    except URLError as e:
        print('urlopen failed. Reason: ', e.reason)
        return graphite_lines
    except Exception as e:
        print('urlopen failed')
        return graphite_lines

    # print('urlopen finished. body read')
    try:
        body = res.read()
    except Exception as e:
        print('body read failed')
        return graphite_lines

    # print('body read finished. loading json')
    encoding = res.info().get_content_charset('utf-8')

    try:
        data = json.loads(body.decode(encoding))
    except Exception as e:
        print('json.loads failed')
        return graphite_lines

    # print('json loaded')

    active_workers_correction = 0
    for worker, worker_data in data['workers'].items():
        worker_name = worker_data['worker']

        if timestamp - worker_data['workerLastSubmitTime'] >= 800:
            active_workers_correction -= 1
            continue

        graphite_lines += [
            'ethermine.eth.worker.%s.hashrate %s %d' % (worker_name, worker_data['hashrate'].split()[0], timestamp),
            'ethermine.eth.worker.%s.validShares %s %d' % (worker_name, worker_data['validShares'], timestamp),
            'ethermine.eth.worker.%s.invalidShares %s %d' % (worker_name, worker_data['invalidShares'], timestamp),
            'ethermine.eth.worker.%s.staleShares %s %d' % (worker_name, worker_data['staleShares'], timestamp),
            'ethermine.eth.worker.%s.invalidShareRatio %s %d' % (worker_name, worker_data['invalidShareRatio'], timestamp),
            'ethermine.eth.worker.%s.workerLastSubmitTimeAgo %s %d' % (worker_name, timestamp-worker_data['workerLastSubmitTime'], timestamp),
        ]

    graphite_lines += [
        'ethermine.eth.reportedHashrate %s %d' % (data['minerStats']['reportedHashrate'], timestamp),
        'ethermine.eth.currentHashrate %s %d' % (data['minerStats']['currentHashrate'], timestamp),
        'ethermine.eth.validShares %s %d' % (data['minerStats']['validShares'], timestamp),
        'ethermine.eth.invalidShares %s %d' % (data['minerStats']['invalidShares'], timestamp),
        'ethermine.eth.staleShares %s %d' % (data['minerStats']['staleShares'], timestamp),
        'ethermine.eth.averageHashrate %s %d' % (data['minerStats']['averageHashrate'], timestamp),
        'ethermine.eth.activeWorkers %s %d' % (data['minerStats']['activeWorkers']+active_workers_correction, timestamp),
        'ethermine.eth.unpaid %s %d' % (data['unpaid']/1000000000000000000, timestamp),
        'ethermine.eth.ethPerHour %s %d' % (data['ethPerMin']*60, timestamp),
        'ethermine.eth.usdPerHour %s %d' % (data['usdPerMin']*60, timestamp),
        'ethermine.eth.btcPerHour %s %d' % (data['btcPerMin']*60, timestamp),
    ]

    return graphite_lines


#09:02 PM root@83f54e 10.0.0.3 [168.1 hash] /root/tuning # sensors
#amdgpu-pci-0300
#Adapter: PCI adapter
#temp1:        +49.0°C  (crit =  +0.0°C, hyst =  +0.0°C)
#
#asus-isa-0000
#Adapter: ISA adapter
#cpu_fan:        0 RPM
#
#acpitz-virtual-0
#Adapter: Virtual device
#temp1:        +27.8°C  (crit = +119.0°C)
#temp2:        +29.8°C  (crit = +119.0°C)
#
#amdgpu-pci-0700
#Adapter: PCI adapter
#temp1:        +47.0°C  (crit =  +0.0°C, hyst =  +0.0°C)
#
#amdgpu-pci-0500
#Adapter: PCI adapter
#temp1:        +52.0°C  (crit =  +0.0°C, hyst =  +0.0°C)
#
#amdgpu-pci-0100
#Adapter: PCI adapter
#temp1:        +50.0°C  (crit =  +0.0°C, hyst =  +0.0°C)
#
#coretemp-isa-0000
#Adapter: ISA adapter
#Physical id 0:  +37.0°C  (high = +84.0°C, crit = +100.0°C)
#Core 0:         +36.0°C  (high = +84.0°C, crit = +100.0°C)
#Core 1:         +37.0°C  (high = +84.0°C, crit = +100.0°C)
#
#amdgpu-pci-0800
#Adapter: PCI adapter
#temp1:        +45.0°C  (crit =  +0.0°C, hyst =  +0.0°C)
#
#amdgpu-pci-0600
#Adapter: PCI adapter
#temp1:        +48.0°C  (crit =  +0.0°C, hyst =  +0.0°C)
#

def get_sensors_stats(timestamp):
    global gpu_temperature

    if not hasattr(get_sensors_stats, "skip_counter"):
        get_sensors_stats.skip_counter = 0
    else:
        get_sensors_stats.skip_counter += 1
        if get_sensors_stats.skip_counter == 3:
            get_sensors_stats.skip_counter = 0

    graphite_lines = []
    # print('calling sensors %d' % (get_sensors_stats.skip_counter))
    stdoutdata = subprocess.getoutput('sensors')

    collected_sections = {}
    if stdoutdata:
        amdgpus     = {}
        sections    = []
        for line in stdoutdata.splitlines():
            if not line:
                sections = []
                continue
            elif not sections:
                sections = line.split('-')
                # print('sections=%s' % (repr(sections)))
                continue
            elif line.find('Adapter:') == 0:
                # print('skipped=%s' % (line))
                continue
            elif line.find('Physical') == 0:
                # print('skipped=%s' % (line))
                continue
            sensor, line = line.split(':', 1)
            sensor = re.sub('\s+', '', sensor)
            values = re.split('\s+', line)
            while values and not values[0]:
                values.pop(0)
            value           = re.sub('[^\-\d\.]', '', values[0])
            section_id      = re.sub('^0+', '', sections[2])
            section_name    = sections[0]
            if not section_id:
                section_id='0'
            # print('sensor=%s, value=%s' % (sensor, value))

            if section_name not in collected_sections:
                collected_sections[section_name] = {}
            if section_id not in collected_sections[section_name]:
                collected_sections[section_name][section_id] = {}

            collected_sections[section_name][section_id][sensor] = value
    else:
        print('no stdoutdata from sensors')

    # print('collected_sections=%s' % (repr(collected_sections)))

    if collected_sections:
        for section_name in collected_sections.keys():
            # print('section_name=%s' % (repr(section_name)))
            section_id_counter = 0
            for section_id in sorted(collected_sections[section_name].keys()):
                # print('section_id=%s' % (repr(section_id)))
                for sensor_name in sorted(collected_sections[section_name][section_id].keys()):
                    value = collected_sections[section_name][section_id][sensor_name]
                    if get_sensors_stats.skip_counter == 0:
                        if section_name == 'amdgpu':
                            graphite_lines.append('mining.%s.GPU.%d.temp %s %d' % (HOSTNAME, section_id_counter, value, timestamp))
                        else:
                            graphite_lines.append('mining.%s.sensors.%s.%d.%s %s %d' % (HOSTNAME, section_name, section_id_counter, sensor_name, value, timestamp))
                    if section_name == 'amdgpu':
                        # print('updating gpu_temperature')
                        try:
                            gpu_temperature[section_id_counter] = int(float(value))
                        except IndexError:
                            gpu_temperature.append(int(float(value)))
                section_id_counter += 1

    #print('graphite_lines=%s' % (repr(graphite_lines)))
    # print('sensors finished')

    return graphite_lines


def gpu_fan_speed_monitor(timestamp):
    global gpu_temperature
    graphite_lines = []

    if not hasattr(gpu_fan_speed_monitor, "hwmons"):
        gpu_fan_speed_monitor.skip_counter = 0

        # print('init temp_to_fan')
        gpu_fan_speed_monitor.temp_to_fan = []
        for temp in range(120):
            if temp <= 30:
                gpu_fan_speed_monitor.temp_to_fan.append(0)
            elif temp >= 70:
                gpu_fan_speed_monitor.temp_to_fan.append(255)
            else:
                # fan_speed=`echo "136*s(3.1415*($temp+55)/52.5)+128" | bc -l`
                fan_speed = int(135 * math.sin(math.pi * (temp+55) / 50) + 120)
                gpu_fan_speed_monitor.temp_to_fan.append(fan_speed)

        stdoutdata = subprocess.getoutput('ls /sys/class/drm/card[0-9]/device/hwmon/* -d')
        # print(repr(stdoutdata))
        if stdoutdata:
            gpu_fan_speed_monitor.hwmons = stdoutdata.split()
        else:
            return

        gpu_fan_speed_monitor.fan_last_speed = []
        gpu_fan_speed_monitor.fan_delay = []
        for i in range(len(gpu_fan_speed_monitor.hwmons)):
            gpu_fan_speed_monitor.fan_last_speed.append(0)
            gpu_fan_speed_monitor.fan_delay.append(0)
            filename = gpu_fan_speed_monitor.hwmons[i] + '/pwm1_enable'
            with open(filename, 'w') as f:
                f.write('1')
            f.closed
    else:
        gpu_fan_speed_monitor.skip_counter += 1
        if gpu_fan_speed_monitor.skip_counter == 3:
            gpu_fan_speed_monitor.skip_counter = 0

    # print('temp_to_fan=%s' % (repr(gpu_fan_speed_monitor.temp_to_fan)))
    # print('hwmons=%s' % (repr(gpu_fan_speed_monitor.hwmons)))


    # print('gpu_temperature=%s' % (repr(gpu_temperature)))
    for i in range(len(gpu_fan_speed_monitor.hwmons)):
        # print('i=%d' % (i))

        temp = gpu_temperature[i]
        fan_speed = gpu_fan_speed_monitor.temp_to_fan[temp]
        last_speed = gpu_fan_speed_monitor.fan_last_speed[i]

        if last_speed != fan_speed:
            if last_speed > fan_speed:
                if last_speed-fan_speed in range(1,10):
                    gpu_fan_speed_monitor.fan_delay[i] = 0
                    graphite_lines.append('mining.%s.GPU.%d.fan %d %d' % (HOSTNAME, i, last_speed*100/255, timestamp))
                    continue
                else:
                    gpu_fan_speed_monitor.fan_delay[i] += 1
                    if gpu_fan_speed_monitor.fan_delay[i] < 20:
                        if get_sensors_stats.skip_counter == 0:
                            graphite_lines.append('mining.%s.GPU.%d.fan %d %d' % (HOSTNAME, i, last_speed*100/255, timestamp))
                        continue

            gpu_fan_speed_monitor.fan_delay[i] = 0
            with open(gpu_fan_speed_monitor.hwmons[i]+'/pwm1', 'w') as f:
                f.write('%s' % (fan_speed))
            f.closed
            # print('%d > $HWMON/pwm1' % (fan_speed))
            gpu_fan_speed_monitor.fan_last_speed[i] = fan_speed

        if get_sensors_stats.skip_counter == 0:
            graphite_lines.append('mining.%s.GPU.%d.fan %d %d' % (HOSTNAME, i, fan_speed*100/255, timestamp))

    return graphite_lines


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apc-pdu',    action='store_true')
    parser.add_argument('--ethermine',  action='store_true')
    parser.add_argument('--gpu-fan',    action='store_true')
    parser.add_argument('--sensors',    action='store_true')
    options = parser.parse_args()
    print('Result:',  vars(options))


    sock = connect_to_graphite()
    messages = []
    epoch_counter = int(time.time())
    next_run_ethermine_stats    = epoch_counter
    next_run_apc_pdu_stats      = epoch_counter
    next_run_sensors_stats      = epoch_counter
    next_run_gpu_fan_monitor    = epoch_counter
    while True:
        timestamp = int(time.time())
        stats_to_schedule_epochs = []


        if options.sensors:
            if timestamp >= next_run_sensors_stats:
                next_run_sensors_stats += SENSORS_INTERVAL
                graphite_lines = get_sensors_stats(timestamp)
                if graphite_lines:
                    messages += graphite_lines
            stats_to_schedule_epochs.append(next_run_sensors_stats)


        if options.sensors and options.gpu_fan:
            if timestamp >= next_run_gpu_fan_monitor:
                next_run_gpu_fan_monitor += GPU_FAN_INTERVAL
                graphite_lines = gpu_fan_speed_monitor(timestamp)
                if graphite_lines:
                    messages += graphite_lines
            stats_to_schedule_epochs.append(next_run_gpu_fan_monitor)


        if options.apc_pdu:
            if timestamp >= next_run_apc_pdu_stats:
                next_run_apc_pdu_stats += APC_PDU_INTERVAL
                graphite_lines = get_apc_pdu_stats(timestamp)
                if graphite_lines:
                    messages += graphite_lines
            stats_to_schedule_epochs.append(next_run_apc_pdu_stats)


        if options.ethermine:
            if timestamp >= next_run_ethermine_stats:
                next_run_ethermine_stats += ETHERMINE_INTERVAL
                graphite_lines = get_ethermine_stats(timestamp)
                if graphite_lines:
                    messages += graphite_lines
            stats_to_schedule_epochs.append(next_run_ethermine_stats)


        if messages:
            message = '\n'.join(messages) + '\n'
            # print(message)
            if send_to_graphite(sock, message):
                messages = []
            else:
                sock = connect_to_graphite()

        # print('finished\n')


        lowest_epoch = min(stats_to_schedule_epochs)
        sleep_until_epoch(lowest_epoch)


if __name__ == "__main__":
    main()

