#!/bin/bash
# Setup to receive Let's Encrypt certs for Prosody
# Usage: $0 <domain.name>

set -eu -o pipefail

tls_dir=/srv/commdata/jabber/tls
DOMAIN="$1"

(umask 077; openssl genrsa -out "$tls_dir/$DOMAIN.key" 4096)
chown prosody:prosody "$tls_dir/$DOMAIN.key"

openssl req -out "$tls_dir/$DOMAIN.csr.pem" \
        -key "$tls_dir/$DOMAIN.key" \
        -new -sha256 -subj "/CN=$DOMAIN"
