#!/bin/bash
# Perform ACME auth for dns-01 challenge (using NearlyFreeSpeech.net DNS)

set -eu -o pipefail

/opt/commapps/nfsn-dns/scripts/dns-rr-add.sh \
    -n "_acme-challenge.${RENEW_SUB}" -b "$RENEW_BASE" \
    -t TXT -d "$CERTBOT_VALIDATION" -l 180

sleep 30
