#!/bin/bash
# Renew certs required for Sandstorm, including wildcard cert, using
# NearlyFreeSpeech.net API.

# Because this will be publicly visible, an anti-spam measure:
at_sign="@"
email="for-letsencrypt-parsnips${at_sign}brainonfire.net"

scripts=/opt/commapps/certbot/scripts

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
        --config-dir "/srv/commdata/etc-letsencrypt" \
        --agree-tos --manual-public-ip-logging-ok --email "$email" \
        --manual -d '*.sandy.parsni.ps' -d 'sandy.parsni.ps' \
        --preferred-challenges 'dns-01' \
        --server 'https://acme-v02.api.letsencrypt.org/directory' \
        --manual-auth-hook "$scripts/nfsn-dns-01-setup.sh" \
        --manual-cleanup-hook "$scripts/nfsn-dns-01-cleanup.sh" \
        --deploy-hook "$scripts/install-certs.sh"
