#!/bin/bash
# Mount community-data filesystem

set -u

# ZFS tries importing this on startup and fails; try again now that
# the partition is decrypted. But also allow for it to have *already*
# been imported, for instance on initial setup.

pool_status=`zpool list -H -o health commdata 2>/dev/null || true`
if [[ "$pool_status" != "ONLINE" ]]; then
    # Automatically mounts
    zpool import commdata
fi
