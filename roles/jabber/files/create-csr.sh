#!/usr/bin/env bash
# Create a CSR for the domain's key.

DOMAIN="$1"

keyfile="/srv/commdata/jabber/tls/$DOMAIN.key"
csrfile="/srv/commdata/jabber/tls/$DOMAIN.csr.pem"

openssl req -out "$csrfile" \
        -key "$keyfile" \
        -new -sha256 -subj "/CN=$DOMAIN"
chown prosody: "$csrfile"
chmod u=rw,g=r,o=r "$csrfile"
