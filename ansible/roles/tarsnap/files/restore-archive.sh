#!/bin/bash
# Restore from an archive of community data
#
# Usage: $0 <archive-name>

if [[ "$#" != "1" ]]; then
    echo "ERROR: Must pass archive-name argument"
    exit 1
fi

ARCHIVE="$1"

# Check if commdata is mounted before proceeding

mountpoint -q /srv/commdata || {
  echo "ERROR: Community data is not yet mounted"
  exit 2
}

TARGET="/srv/commdata/tmp/tarsnap-restore/$ARCHIVE"

mkdir -p "$TARGET"
tarsnap -x -f "$ARCHIVE" -C "$TARGET" \
        --cache /srv/commdata/cache/tarsnap \
        --keyfile /srv/commdata/backups/secrets/tarsnap-rw.key \
        -p -v
