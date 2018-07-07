#!/bin/bash
# Update Prosody modules from the community repo and update the record
# of what revision they were copied from.

set -eu -o pipefail

DEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR=~/repos/prosody-modules
MODULES="privacy_lists smacks smacks_noerror cloud_notify csi blocking http_upload omemo_all_access"

# Clear the revision file until we're back in a consistent state
echo > "$DEST_DIR/revision.txt"

for m in $MODULES; do
    >&2 echo "Updating mod_$m"
    rsync -ax --delete "$SRC_DIR/mod_$m/" "$DEST_DIR/mod_$m/"
done

(cd -- "$SRC_DIR"; hg identify --id) > "$DEST_DIR/revision.txt"
