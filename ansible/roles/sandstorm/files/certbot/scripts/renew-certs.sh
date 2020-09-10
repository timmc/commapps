#!/bin/bash
# Renew certs required for Sandstorm, including wildcard cert, using
# NearlyFreeSpeech.net API.

set -eu -o pipefail

RENEW_SUB=sandy RENEW_BASE=parsni.ps RENEW_WILD=true \
 /opt/commapps/certbot/scripts/renew-one-cert.sh

RENEW_SUB=sandstorm RENEW_BASE=appux.com RENEW_WILD=true \
 /opt/commapps/certbot/scripts/renew-one-cert.sh
