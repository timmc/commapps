#!/bin/bash
# Update DNS records to point to this server's public IP.
#
# Set DYNDNS_SLEEP to a fixed random number of seconds 0-59 when
# running from a cron job to help level load on the dyndns service.

set -eu -o pipefail

function log {
  echo `date --universal "+%Y-%m-%d %H:%M:%S"`: "$@"
}

sleep "${DYNDNS_SLEEP:-0}"

log "Running dyndns updater"

token="$(cat /srv/commdata/dyndns/secrets/afraid.org-token-home)"
curl -sS "https://sync.afraid.org/u/$token/?content-type=json" -m10 || true

log "Dyndns update complete"
