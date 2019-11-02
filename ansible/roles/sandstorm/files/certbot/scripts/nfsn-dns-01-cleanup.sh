#!/bin/bash
# Clean up after ACME auth for dns-01 challenge on NearlyFreeSpeech.net DNS

set -eu -o pipefail

if [[ "${CERTBOT_DOMAIN}" != "${RENEW_SANDSTORM_FULL_DOMAIN}" ]]; then
    echo "Unexpected domain for DNS-01 auth challenge: ${CERTBOT_DOMAIN}"
    exit 1
fi

if [[ "${CERTBOT_VALIDATION}" = '' ]]; then
    echo "No validation string given"
    exit 1
fi

/opt/commapps/certbot/scripts/nfsn-call.sh \
    "POST" "/dns/${RENEW_BASE_DOMAIN}/removeRR" \
    "name=_acme-challenge.${RENEW_SANDSTORM_SUBDOMAIN}&type=TXT&data=${CERTBOT_VALIDATION}"
