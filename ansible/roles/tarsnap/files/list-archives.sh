#!/bin/bash
# List backups of community data

mountpoint -q /srv/commdata || {
  echo "ERROR: Community data is not yet mounted"
  exit 2
}

tarsnap --list-archives \
        --cache /srv/commdata/cache/tarsnap \
        --keyfile /srv/commdata/backups/secrets/tarsnap-rw.key \
    | sort
