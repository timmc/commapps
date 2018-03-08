#!/bin/bash

sleep 20

token="$(cat /opt/commdata/dyndns/secrets/afraid.org-token-home)"
curl -sS "https://sync.afraid.org/u/$token/" >> /var/log/dyndns-afraid.org-home.log 2>&1
