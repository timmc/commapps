#!/bin/bash
# Back up community data

# Exit codes:
# 2 - Precondition failed
# 3 - Startup failed (could not snapshot)
# 4 - Backup error
# 5 - Cleanup error (non-fatal, but needs followup)

function log {
  echo `date --universal "+%Y-%m-%d %H:%M:%S"`: "$@"
}

# Check if commdata is mounted before proceeding

mountpoint -q /mnt/commdata || {
  log "Community data is not yet mounted"
  exit 2
}

# Give each snaptime file a different path based on ID, just in case
# of concurrent runs. For correctness this should be created *before*
# the snapshot is taken; for performance it should not be *too* long
# before.

snaptime_path="/tmp/commdata-snaptime-$snapshot_id.ref"
touch "$snaptime_path"

# Using timestamped snapshots solves some concurrency issues. Use
# nanoseconds since UNIX epoch.
snapshot_id="tarsnap-periodic-$(date --universal +%s%N)"

# Creation of the ZFS snapshot serves as a mutex lock on these
# backups.

log "Snapshotting community data: $snapshot_id"
zfs snapshot commdata@"$snapshot_id" || {
  log "Failed to take snapshot; did another backup start at exactly the same time?"
  exit 3
}
# That's the last place we can call exit without cleanup.

log "Running backup on $snapshot_id"

# This uses a write-only tarsnap key.

tarsnap -c -f "$(uname -n)-$(date --universal +%Y-%m-%d_%H-%M-%S)" \
        --keyfile /mnt/commdata/backups/tarsnap-w.key \
        --snaptime "$snaptime_path" \
        -C /mnt/commdata/.zfs/snapshot/"$snapshot_id" \
        --humanize-numbers \
        ./sandstorm
tarsnap_exit=$?

rm -- "$snaptime_path"

log "Releasing snapshot $snapshot_id"
zfs destroy commdata@"$snapshot_id"
snapshot_destroy_exit=$?

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
