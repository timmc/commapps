#!/bin/bash
# Fetch an updated cert file from the web server's cert oracle and
# install it if it has changed.
#
# Usage: $0 <domain-name> <base-url>
#
# Needs to run as prosody user or as root.
#
# Exits 0 when no change made, and exits 64 when cert updated.
# Exits 65 if cert could not be fetched.

set -eu -o pipefail

log() { echo >&2 "$(date -u "+%Y-%m-%d %H:%M:%S"):" "$@"; }

DOMAIN="$1"
BASE_URL="$2"

dest_dir=/srv/commdata/jabber/tls
install_path="$dest_dir/$DOMAIN.chain.pem"
fetch_url="$BASE_URL/$DOMAIN.chain.pem"

old_data="$(cat -- "$install_path" || true)"
new_data="$(curl -sS -m 10 -H 'Cache-Control: no-cache' -- "$fetch_url")"
if [[ ! "$new_data" =~ BEGIN\ CERTIFICATE ]]; then
    log -e "Could not fetch new certificate from $fetch_url. Response was: \n$new_data"
    exit 65
fi

if [[ "$old_data" = "$new_data" ]]; then
    log "Not installing new cert, hasn't changed: $install_path"
    exit 0
fi

log "Installing certificate to $install_path and reloading Prosody"
echo "$new_data" > "$install_path"
systemctl reload prosody
exit 64
