#!/bin/bash
# Update DNS records to point to this server's public IP.

set -eu -o pipefail

function log {
  echo >&2 `date --universal "+%Y-%m-%d %H:%M:%S"`: "$@"
}

log "Running dyndns updater"

source /srv/commdata/dyndns/config

current_public_ip4=`dig +short -4 @resolver1.opendns.com myip.opendns.com`

dns_listing="$(
    /opt/commapps/nfsn-dns/scripts/dns-rr-list.sh \
        -n "$DYNDNS_RECORD" -b "$DYNDNS_BASE_DOMAIN" \
        -t "A"
)"

if [[ "$dns_listing" == *"$current_public_ip4"* ]]; then
    log "Record is up to date"
else
    log "Record is out of date, updating"
    /opt/commapps/nfsn-dns/scripts/dns-rr-replace.sh \
        -n "$DYNDNS_RECORD" -b "$DYNDNS_BASE_DOMAIN" \
        -t "A" -d "$current_public_ip4" -l "$DYNDNS_TTL_S"
fi
