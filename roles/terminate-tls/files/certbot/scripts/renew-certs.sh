#!/bin/bash
# Renew certs listed in domains directory.

set -eu -o pipefail

function renew_for_file {
    filepath="$1"
    export RENEW_SUB="$(jq -r .sub < "$filepath")"
    export RENEW_BASE="$(jq -r .base < "$filepath")"
    export RENEW_WILD="$(jq -r .wild < "$filepath")"
    echo >&2 "Running renewal check with configuration for $RENEW_SUB.$RENEW_BASE (wild=$RENEW_WILD)"
    /opt/commapps/certbot/scripts/renew-one-cert.sh
}

failed=
find /opt/commapps/certbot/domains.d -maxdepth 1 -name '*.json' -type f | while IFS= read -r f; do
    echo >&2 "Found configuration file $f"
    renew_for_file "$f" || {
        failed=true # delay exit code
        echo >&2 "Renewal failed! Moving on to next configuration."
    }
done

if [[ "$failed" = "true" ]]; then
    exit 1
fi
