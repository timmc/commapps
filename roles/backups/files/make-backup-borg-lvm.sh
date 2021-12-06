#!/usr/bin/env bash
# Back up community data using borgbackup on an LVM snapshot.

# Exit codes:
# 65 - Precondition failed
# 66 - Startup failed (could not snapshot)
# 67 - Backup error
# 68 - Cleanup error (may cause future backup to fail)

set -eu -o pipefail

log() { echo >&2 "$(date -u "+%Y-%m-%d %H:%M:%S"):" "$@"; }

# Check if commdata is mounted before proceeding

mountpoint -q /srv/commdata || {
  log "ERROR: Community data is not yet mounted"
  exit 65
}


# Establish mountpoint for snapshot
mkdir -p /srv/active-commdata-snapshot
mountpoint -q /srv/active-commdata-snapshot && {
    log "ERROR: Snapshot mountpoint is already in use"
    exit 65
}

# Creation of the snapshot serves as a mutex for backups

snapshot_id="borgbackup-commdata-$(date -u +%s%N)"
log "Creating LVM snapshot $snapshot_id"
lvcreate --snapshot --extents='100%FREE' --name="$snapshot_id" commdata/main --permission r || {
    log "ERROR: Failed to take snapshot; did another backup start at exactly the same time?"
    exit 66
}
# Between now and releasing the snapshot, all non-zero exits must be
# captured and converted to a failure flag rather than immediately
# exiting. Releasing the snapshot is more important than any other
# cleanup.


log "Mounting snapshot"
mount -o ro "/dev/commdata/$snapshot_id" /srv/active-commdata-snapshot || {
    log "ERROR: Mounting failed with exit code $?"
    backup_failure=true
}

if [[ -z "${backup_failure:-}" ]]; then
    log "Creating archive"
    /opt/commapps/backups/borg/archive-snapshot.sh || {
        log "ERROR: Archive creation failed with exit code $?"
        backup_failure=true
    }
fi

log "Unmounting snapshot"
umount /srv/active-commdata-snapshot || {
    log "ERROR: Unmount of snapshot failed with exit code $?"
    cleanup_failure=true
}

log "Releasing snapshot"
lvremove --yes "commdata/$snapshot_id" || {
    log "ERROR: Snapshot release failed with exit code $?"
    cleanup_failure=true
}
# At this point, uncontrolled exits become safe.


# Choose between possible exit codes based on priority.

if [[ -n "${backup_failure:-}" ]]; then
  log "ERROR: Backup failure, possibly incomplete or failed to start."
  exit 67
elif [ -n "${cleanup_failure:-}" ]; then
  log "WARN: Failure during cleanup of LVM snapshot $snapshot_id, which may make the next backup fail."
  exit 68
else
  log "Backup complete: Successful."
fi
