#!/bin/bash
# Back up community data

# Exit codes:
# 2 - Precondition failed
# 3 - Startup failed (could not snapshot)
# 4 - Backup error
# 5 - Cleanup error (non-fatal, but needs followup)

set -eu -o pipefail

function log {
  echo `date --universal "+%Y-%m-%d %H:%M:%S"`: "$@"
}

# Check if commdata is mounted before proceeding

mountpoint -q /srv/commdata || {
  log "ERROR: Community data is not yet mounted"
  exit 2
}

# Give each snaptime file a different path based on ID, just in case
# of concurrent runs. For correctness this should be created *before*
# the snapshot is taken; for performance it should not be *too* long
# before, says Colin Percival.

# Using timestamped snapshots solves some concurrency issues. Use
# nanoseconds since UNIX epoch.
snapshot_prefix="tarsnap-periodic"
snapshot_id="${snapshot_prefix}-$(date --universal +%s%N)"

snaptime_path="/tmp/commdata-snaptime-$snapshot_id.ref"
touch -- "$snaptime_path"

# Creation of the ZFS snapshot serves as a mutex lock on these
# backups.

log "Snapshotting community data: $snapshot_id"
zfs snapshot commdata@"$snapshot_id" || {
  log "ERROR: Failed to take snapshot; did another backup start at exactly the same time?"
  exit 3
}
# That's the last place we can call exit without cleanup.

# zfs-fuse doesn't yet allow you to *look* at snapshots via
# .zfs/snapshot, but you can clone them and look at the clone.
# Source: https://www.csamuel.org/2008/06/28/recovering-files-from-a-zfsfuse-snapshot-under-linux
log "Cloning snapshot to make it visible"
zfs clone commdata@"$snapshot_id" commdata/snapclone-"$snapshot_id"

log "Running backup on $snapshot_id"

# This uses a tarsnap key that can only read and write, but not delete

set +e
# FIXME don't hardcode sandstorm here
tarsnap -c -f "$(uname -n)-$(date --universal +%Y-%m-%d_%H-%M-%S)" \
        --keyfile /srv/commdata/backups/secrets/tarsnap-rw.key \
        --snaptime "$snaptime_path" \
        -C /srv/commdata/snapclone-"$snapshot_id" \
        --humanize-numbers \
        ./sandstorm
tarsnap_exit=$?
set -e

rm -- "$snaptime_path"

log "Releasing snapshot $snapshot_id"
set +e
# Destroy the snapshot as well as the clone (recursive). I would have
# explicitly destroyed the clone, but zfs didn't let me!
#
# The `destroy` command sometimes fails with "dataset is busy", and
# I'm not sure why. It might have something to do with the order in
# which snapshots are created and destroyed; in any event, looping
# over all existing (Tarnsap) snapshots in timestamp order seems to
# help if you end up in this situation:
#
#    for s in `zfs list -t snapshot | grep -F "tarsnap-periodic" | sort | awk '{ print $1 }'`; do echo "Destroying $s"; zfs destroy -R "$s"; done
#
# TODO: Switch to using ext4 and use LVM for snapshotting -- more reliable?
zfs destroy -R commdata@"$snapshot_id"
snapshot_destroy_exit=$?
set -e

# Choose between possible exit codes based on priority.

if [ "$tarsnap_exit" -ne 0 ]; then
  log "ERROR: Tarsnap backup failure. Exit code was $tarsnap_exit"
  exit 4
elif [ "$snapshot_destroy_exit" -ne 0 ]; then
  log "WARN: Could not destroy snapshot; please investigate and destroy it at earliest convenience: $snapshot_id"
  exit 5
else
  log "Backup complete: Successful."
fi
