#!/bin/bash
# Mount community-data filesystem

set -eu -o pipefail

# ZFS tries importing this on startup and fails; try again now that
# the partition is decrypted.
zpool import commdata

mount -t zfs /dev/mapper/con-commdata /srv/commdata
