#!/bin/bash
# Add a DNS resource record.

set -eu -o pipefail

while getopts "n:b:t:d:l:" opt; do
    if [[ ! "$OPTARG" =~ ^[-a-zA-Z0-9_./+=:]*$ ]]; then
        echo >&2 "Option '$opt' was not URL querystring safe."
        echo >&2 "If you want arbitrary text inputs, you'll need to enhance the script to do URL encoding."
        exit 1
    fi

    case "$opt" in
        n)
            RECORD_NAME="$OPTARG"
            ;;
        b)
            BASE_DOMAIN="$OPTARG"
            ;;
        t)
            RECORD_TYPE="$OPTARG"
            ;;
        d)
            DATA="$OPTARG"
            ;;
        l)
            TTL="$OPTARG"
            ;;
        *)
            exit 1
            ;;
    esac
done

# Note: NFSN's addRR will fail on an empty record value.
if [[ -z "$DATA" ]]; then
    echo "Record data cannot be empty"
    exit 1
fi

/opt/commapps/nfsn-dns/scripts/api-call.sh \
    "POST" "/dns/${BASE_DOMAIN}/addRR" \
    "name=${RECORD_NAME}&type=${RECORD_TYPE}&data=${DATA}&ttl=${TTL}"
