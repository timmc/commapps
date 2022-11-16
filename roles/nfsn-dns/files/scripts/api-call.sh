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

# Get the complete headers + body, then separate them afterwards. This
# was the least worst option I could find for getting both 1) the
# response body, and 2) the success/failure status. (Curl does not
# give an error exit for 4xx or 5xx, and trust me, the other options
# for getting response code aren't very good.)
call_output=$(
    curl -sS -i "https://api.nearlyfreespeech.net${NFSN_REQUEST_PATH}" \
     -H "X-NFSN-Authentication: ${auth_header_value}" \
     --data-binary "${NFSN_REQUEST_BODY}" -X "${NFSN_REQUEST_METHOD}"
)
response_status=$(echo "$call_output" | grep -Po '\s[0-9]{3}\s' | head -n1 | tr -dc 0-9)

if [[ "$response_status" == 200 ]]; then
    # Output the response body (skip over headers)
    echo "$call_output" | sed -ne $'/^\r$/,$p' | tail -n+2
    exit 0
else
    # Output everything on error, including headers
    echo "$call_output"
    exit 1
fi
