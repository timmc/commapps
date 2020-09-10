#!/bin/bash
# Clean up after ACME auth for dns-01 challenge on NearlyFreeSpeech.net DNS

set -eu -o pipefail

if [[ "${CERTBOT_VALIDATION}" = '' ]]; then
    echo "No validation string given"
    exit 1
fi

/opt/commapps/certbot/scripts/nfsn-call.sh \
    "POST" "/dns/${RENEW_BASE}/removeRR" \
    "name=_acme-challenge.${RENEW_SUB}&type=TXT&data=${CERTBOT_VALIDATION}"
