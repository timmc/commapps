#!/bin/bash
# Back up community data

# Exit codes:
# 2 - Precondition failed
# 3 - Startup failed (could not snapshot)
# 4 - Backup error
# 5 - Cleanup error (may cause future backup to fail)

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

# Establish mountpoint for snapshot
mkdir -p /srv/active-snapshot
mountpoint -q /srv/active-snapshot && {
    log "ERROR: Snapshot mountpoint is already in use"
    exit 2
}

# Creation of the snapshot serves as a mutex for backups

log "Snapshotting community data: $snapshot_id"
lvcreate --snapshot --extents='100%FREE' --name="$snapshot_id" commdata/main --permission r || {
    log "ERROR: Failed to take snapshot; did another backup start at exactly the same time?"
    exit 3
}
# Between now and releasing the snapshot, all non-zero exits must be
# captured and converted to a failure flag. Releasing the snapshot is
# more important than any other cleanup.


log "Mounting snapshot"
mount -o ro "/dev/commdata/$snapshot_id" /srv/active-snapshot || {
    log "ERROR: Mounting failed with exit code $?"
    backup_failure=true
}

if [[ -z "${backup_failure:-}" ]]; then
    log "Running backup on $snapshot_id"

    # Back up the entire snapshot. There's no exclusion for the
    # Tarsnap cache directory, since Tarsnap is able to exclude that
    # on its own.
    #
    # Also back up user and group information so ownership can be
    # remapped on restore.
    tarsnap -c -f "$(uname -n)-$(date --universal +%Y-%m-%d_%H-%M-%S)" \
            --cache /srv/commdata/cache/tarsnap \
            --keyfile /srv/commdata/backups/secrets/tarsnap-rw.key \
            --snaptime "$snaptime_path" \
            --humanize-numbers --aggressive-networking \
            /srv/active-snapshot /etc/passwd /etc/group || {
        log "ERROR: Tarsnap failed with exit code $?"
        backup_failure=true
    }
fi

log "Unmounting snapshot"
umount /srv/active-snapshot || {
    log "ERROR: Unmount of snapshot failed with exit code $?"
    cleanup_failure=true
}

log "Releasing snapshot $snapshot_id"
lvremove --yes "commdata/$snapshot_id" || {
    log "ERROR: Snapshot release failed with exit code $?"
    cleanup_failure=true
}
# At this point, uncontrolled exits become safe.


rm -- "$snaptime_path" || {
    log "ERROR: Failed to remove snaptime file"
    # These won't cause trouble, but should still be reported
    cleanup_failure=true
}

# Choose between possible exit codes based on priority.

if [[ -n "${backup_failure:-}" ]]; then
  log "ERROR: Backup failure, possibly incomplete or failed to start."
  exit 4
elif [ -n "${cleanup_failure:-}" ]; then
  log "WARN: Failure during cleanup, which may make the next backup fail."
  exit 5
else
  log "Backup complete: Successful."
fi
