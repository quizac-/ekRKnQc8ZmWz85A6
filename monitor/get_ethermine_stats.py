#!/usr/bin/env python3

import urllib.request
from urllib.request import Request, urlopen
import json
import time
import socket


GRAPHITE_SERVER = '10.0.0.244'
GRAPHITE_PORT   = 32003
INTERVAL        = 59

url = 'https://ethermine.org/api/miner_new/82BB67244a0CBaFFeC4709ebD66C36dFD6eF428b'
#file_name = '82BB67244a0CBaFFeC4709ebD66C36dFD6eF428b'


def send_to_graphite(message):
    print('sending message:\n%s' % message)
    sock = socket.socket()
    sock.settimeout(2)

    try:
        sock.connect((GRAPHITE_SERVER, GRAPHITE_PORT))
    except (KeyboardInterrupt, SystemExit):
        raise
    except:
        return

    sock.sendall(message.encode())
    sock.close()


while True:

    messages = []
    timestamp = int(time.time())

    try:
        req = Request(url, data=None)
        req.add_header('User-Agent', 'Mozilla/5.0')
        res = urlopen(req, None, 2)
        body = res.read()
        #body = open(file_name).read()
    except (KeyboardInterrupt, SystemExit):
        raise
    except:
        time.sleep(INTERVAL)
        continue

    encoding = res.info().get_content_charset('utf-8')

    try:
        data = json.loads(body.decode(encoding))
        #data = json.loads(body)
    except (KeyboardInterrupt, SystemExit):
        raise
    except:
        time.sleep(INTERVAL)
        continue

    # print(data)

    for worker, worker_data in data['workers'].items():
        worker_name = worker_data['worker']
        lines = [
            'ethermine.eth.worker.%s.hashrate %s %d' % (worker_name, worker_data['hashrate'].split()[0], timestamp),
            'ethermine.eth.worker.%s.validShares %s %d' % (worker_name, worker_data['validShares'], timestamp),
            'ethermine.eth.worker.%s.invalidShares %s %d' % (worker_name, worker_data['invalidShares'], timestamp),
            'ethermine.eth.worker.%s.staleShares %s %d' % (worker_name, worker_data['staleShares'], timestamp),
            'ethermine.eth.worker.%s.invalidShareRatio %s %d' % (worker_name, worker_data['invalidShareRatio'], timestamp),
            'ethermine.eth.worker.%s.workerLastSubmitTimeAgo %s %d' % (worker_name, timestamp-worker_data['workerLastSubmitTime'], timestamp),
        ]
        messages += lines

    lines = [
        'ethermine.eth.reportedHashrate %s %d' % (data['minerStats']['reportedHashrate'], timestamp),
        'ethermine.eth.currentHashrate %s %d' % (data['minerStats']['currentHashrate'], timestamp),
        'ethermine.eth.validShares %s %d' % (data['minerStats']['validShares'], timestamp),
        'ethermine.eth.invalidShares %s %d' % (data['minerStats']['invalidShares'], timestamp),
        'ethermine.eth.staleShares %s %d' % (data['minerStats']['staleShares'], timestamp),
        'ethermine.eth.averageHashrate %s %d' % (data['minerStats']['averageHashrate'], timestamp),
        'ethermine.eth.activeWorkers %s %d' % (data['minerStats']['activeWorkers'], timestamp),
        'ethermine.eth.unpaid %s %d' % (data['unpaid']/1000000000000000000, timestamp),
        'ethermine.eth.ethPerHour %s %d' % (data['ethPerMin']*60, timestamp),
        'ethermine.eth.usdPerHour %s %d' % (data['usdPerMin']*60, timestamp),
        'ethermine.eth.btcPerHour %s %d' % (data['btcPerMin']*60, timestamp),
    ]
    messages += lines
    message = '\n'.join(messages) + '\n'
    print(message)

    send_to_graphite(message)

    time.sleep(INTERVAL)

