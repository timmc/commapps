#!/bin/bash

# Randomized [0..59] sleep to reduce impact on afraid.org
sleep 20

logfile=/var/log/dyndns-afraid.org-home.log

token="$(cat /opt/commdata/dyndns/secrets/afraid.org-token-home)"

echo -n "`date -u +'%Y-%m-%d %H:%M:%S'`: " >> $logfile
curl -sS "https://sync.afraid.org/u/$token/?content-type=json" -m10 \
     >> $logfile 2>&1
