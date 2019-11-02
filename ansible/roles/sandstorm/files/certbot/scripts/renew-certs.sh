#!/bin/bash
# Renew certs required for Sandstorm, including wildcard cert, using
# NearlyFreeSpeech.net API.

set -eu -o pipefail

export RENEW_BASE_DOMAIN=parsni.ps
export RENEW_SANDSTORM_SUBDOMAIN=sandy
/opt/commapps/certbot/scripts/renew-one-cert.sh

export RENEW_BASE_DOMAIN=appux.com
export RENEW_SANDSTORM_SUBDOMAIN=sandstorm
/opt/commapps/certbot/scripts/renew-one-cert.sh
