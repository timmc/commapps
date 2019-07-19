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
snapshot_id="tarsnap-periodic-$(date --universal +%s%N)"

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

log "Running backup on $snapshot_id"

# This uses a tarsnap key that can only read and write, but not delete

set +e
tarsnap -c -f "$(uname -n)-$(date --universal +%Y-%m-%d_%H-%M-%S)" \
        --keyfile /srv/commdata/backups/secrets/tarsnap-rw.key \
        --snaptime "$snaptime_path" \
        -C /srv/commdata/.zfs/snapshot/"$snapshot_id" \
        --humanize-numbers \
        ./sandstorm \
        ./jabber/data # FIXME don't require jabber and sandstorm on same box
tarsnap_exit=$?
set -e

rm -- "$snaptime_path"

log "Releasing snapshot $snapshot_id"
set +e
zfs destroy commdata@"$snapshot_id"
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
