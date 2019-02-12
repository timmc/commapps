#!/bin/bash
# Make an API call to NearlyFreeSpeech.net
#
# Usage: $0 <http-method> <uri-path> <req-body>
#
# - http-method: GET, POST, or PUT
# - uri-path: Path component of API call URL
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

NFSN_API_KEY=${NFSN_API_KEY:-`cat /srv/commdata/secrets/certbot/nfsn-api-key`}
NFSN_USERNAME=${NFSN_USERNAME:-phyzome}

auth_timestamp=`date +%s`
auth_salt=`head --bytes=8 /dev/urandom | xxd -p`
auth_body_hash=$(echo -n "$NFSN_REQUEST_BODY" | sha1sum | cut -f1,1 -d' ')

auth_preimage="${NFSN_USERNAME};${auth_timestamp};${auth_salt};${NFSN_API_KEY};${NFSN_REQUEST_PATH};${auth_body_hash}"
auth_hash=$(echo -n "$auth_preimage" | sha1sum | cut -f1,1 -d' ')

auth_header_value="${NFSN_USERNAME};${auth_timestamp};${auth_salt};${auth_hash}"

#====#

curl -sS "https://api.nearlyfreespeech.net${NFSN_REQUEST_PATH}" \
     -H "X-NFSN-Authentication: ${auth_header_value}" \
     --data-binary "${NFSN_REQUEST_BODY}" -X "${NFSN_REQUEST_METHOD}"
