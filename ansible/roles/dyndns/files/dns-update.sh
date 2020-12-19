#!/bin/bash

set -eu -o pipefail

# Randomized [0..59] sleep to reduce impact on afraid.org
sleep 20

token="$(cat /srv/commdata/dyndns/secrets/afraid.org-token-home)"

echo -n "`date -u +'%Y-%m-%d %H:%M:%S'`: "
curl -sS "https://sync.afraid.org/u/$token/?content-type=json" -m10 || true
echo
