#!/bin/bash
# Renew one certificate, possibly including a wildcard cert, using
# NearlyFreeSpeech.net API.
#
# Reads environment variables:
# - RENEW_BASE, base domain registered at NFSN [required]
# - RENEW_SUB, subdomain record (without base domain) [required]
# - RENEW_WILD, if "true" include a wildcard SAN

set -eu -o pipefail

# Note to self: Don't put straight email address, lest spammers
# harvest it.
at_sign="@"
email="for-letsencrypt-${RENEW_BASE}${at_sign}brainonfire.net"

configdir=/srv/commdata/etc-letsencrypt
scripts=/opt/commapps/certbot/scripts

if [[ ! -d "$configdir" ]]; then
    echo "Config dir does not exist (commdata partition not mounted?)"
    exit 1
fi

renew_full="${RENEW_SUB}.${RENEW_BASE}"
domain_args=(-d "$renew_full")
if [[ "$RENEW_WILD" = "true" ]]; then
    domain_args+=(-d "*.$renew_full")
fi

# `certonly`: Only do auth steps, don't try to install them
# `--config-dir` so that certs and keys are in encrypted volume
#
# Bypass prompts:
# - `--agree-tos`: Agree to Terms of Service
# - `--manual-public-ip-logging-ok`: Consent to public logging of IP address
#   where certbot is run
#
# `--server https://acme-v02.api.letsencrypt.org/directory`: Earlier
# versions of certbot don't default to v2, I think...
certbot certonly --noninteractive \
        --config-dir "$configdir" \
        --agree-tos --manual-public-ip-logging-ok --email "$email" \
        --manual \
        "${domain_args[@]}" \
        --preferred-challenges 'dns-01' \
        --server 'https://acme-v02.api.letsencrypt.org/directory' \
        --manual-auth-hook "$scripts/nfsn-dns-01-setup.sh" \
        --manual-cleanup-hook "$scripts/nfsn-dns-01-cleanup.sh" \
        --deploy-hook "$scripts/install-certs.sh"
