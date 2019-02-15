#!/bin/bash
# Mount community-data filesystem

set -u

# ZFS tries importing this on startup and fails; try again now that
# the partition is decrypted. But also allow for it to have *already*
# been imported, for instance on initial setup.

pool_status=`zpool list -H -o health commdata 2>/dev/null || true`

if [[ "$pool_status" == "ONLINE" ]]; then
    exit 0
fi

if [[ "$pool_status" == "FAULTED" ]]; then
    # Maybe it tried to mount before LUKS was open and failed. Let's
    # try to reset it so it can mount.
    zpool export commdata || true
fi

# Automatically mounts
zpool import commdata
