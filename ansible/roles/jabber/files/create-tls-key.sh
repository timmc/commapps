#!/usr/bin/env bash
# Create a new server key.

DOMAIN="$1"

keyfile="/srv/commdata/jabber/tls/$DOMAIN.key"

umask 077
openssl genrsa -out "$keyfile" 4096
chown prosody: -- "$keyfile"
chmod u=rw,g=,o= "$keyfile"
