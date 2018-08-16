#!/bin/bash
# List backups of community data

mountpoint -q /srv/commdata || {
  log "ERROR: Community data is not yet mounted"
  exit 2
}

tarsnap --list-archives \
        --keyfile /srv/commdata/backups/tarsnap-rw.key \
        --humanize-numbers \
    | sort
