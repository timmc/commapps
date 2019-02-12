#!/bin/bash
# Clean up after ACME auth for dns-01 challenge on NearlyFreeSpeech.net DNS

set -eu -o pipefail

if [[ "${CERTBOT_DOMAIN}" != 'sandy.parsni.ps' ]]; then
    echo "Unexpected domain for DNS-01 auth challenge: ${CERTBOT_DOMAIN}"
    exit 1
fi

if [[ "${CERTBOT_VALIDATION}" = '' ]]; then
    echo "No validation string given"
    exit 1
fi

/opt/commapps/certbot/scripts/nfsn-call.sh \
    "POST" "/dns/parsni.ps/removeRR" \
    "name=_acme-challenge.sandy&type=TXT&data=${CERTBOT_VALIDATION}"
