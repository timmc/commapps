#!/bin/bash
# Perform ACME auth for dns-01 challenge on NearlyFreeSpeech.net DNS

set -eu -o pipefail

# Note: NFSN's removeRR will fail on an empty record value, so we try
# to avoid getting into such a situation here.
if [[ "${CERTBOT_VALIDATION}" = '' ]]; then
    echo "No validation string given"
    exit 1
fi

/opt/commapps/certbot/scripts/nfsn-call.sh \
    "POST" "/dns/${RENEW_BASE}/addRR" \
    "name=_acme-challenge.${RENEW_SUB}&type=TXT&data=${CERTBOT_VALIDATION}&ttl=180"

sleep 30
