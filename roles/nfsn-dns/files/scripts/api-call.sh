#!/bin/bash
# Make an API call to NearlyFreeSpeech.net
#
# Usage: $0 <http-method> <uri-path> <req-body>
#
# - http-method: GET, POST, or PUT
# - uri-path: Path and query component of API call URL
# - req-body: Request body, form-encoded (possibly empty)
#
# Optional overrides:
# - NFSN_API_KEY
# - NFSN_USERNAME

set -eu -o pipefail

NFSN_REQUEST_METHOD="$1"
NFSN_REQUEST_PATH="$2"
NFSN_REQUEST_BODY="$3"

#== Auth header ==#

NFSN_API_KEY=${NFSN_API_KEY:-`cat /srv/commdata/nfsn-dns/secrets/api-key`}
NFSN_USERNAME=${NFSN_USERNAME:-`cat /srv/commdata/nfsn-dns/secrets/username`}

auth_timestamp=`date +%s`
auth_salt=`head --bytes=8 /dev/urandom | xxd -p`
auth_body_hash=$(echo -n "$NFSN_REQUEST_BODY" | sha1sum | cut -f1,1 -d' ')

auth_preimage="${NFSN_USERNAME};${auth_timestamp};${auth_salt};${NFSN_API_KEY};${NFSN_REQUEST_PATH};${auth_body_hash}"
auth_hash=$(echo -n "$auth_preimage" | sha1sum | cut -f1,1 -d' ')

auth_header_value="${NFSN_USERNAME};${auth_timestamp};${auth_salt};${auth_hash}"

#====#

call_output=$(
    curl -sS -i "https://api.nearlyfreespeech.net${NFSN_REQUEST_PATH}" \
     -H "X-NFSN-Authentication: ${auth_header_value}" \
     --data-binary "${NFSN_REQUEST_BODY}" -X "${NFSN_REQUEST_METHOD}"
)

status_line="$(echo "$call_output" | head -n1 )"

re_success="^HTTP/[0-9.]+\s+200\s+"
if [[ "$status_line" =~ $re_success ]]; then
    exit 0
else
    echo >&2 "$call_output"
    exit 1
fi
