#!/usr/bin/env bash
# Back up currently active snapshot -- not intended to be called directly.
set -eu -o pipefail

log() { echo >&2 "$(date -u "+%Y-%m-%d %H:%M:%S"):" "$@"; }

mountpoint -q /srv/active-commdata-snapshot || {
  log "ERROR: Community data snapshot is not yet mounted"
  exit 1
}

# Configure borg via environment variables
source /opt/commapps/backups/borg/env.sh

# Compression:
#
# I'm going to saturate my uplink very easily, so compress as much as
# possible. This is also one-time compression, so it's worth burning
# CPU on. zstd is allegedly every effective, and 22 is the max
# compression level.
#
# --one-file-system keeps the backup from wandering onto mounted
# drives, tmp directories, ramdisks, and pseudo-filesystems such as
# `/proc`. Especially important if `/` is included in the list of
# directories to be backed up, but still needed even without that.
#
# Exclusions:
#
# --exclude-caches avoids any dir with the CACHEDIR.TAG standard file,
# which isn't a very widespread standard but is used by borg for its
# own cache at least. --exclude-from has a list of additional excludes.
#
# SSH:
#
# --rsh sets the SSH command to use, including the private key to use
# (since the command is running as root).
#
# Additional:
#
# - `--stats` shows end-of-backup stats (incompatible with `--dry-run`)
# - `--list` shows the status of each file considered, and `--filter`
#   limits the output to just interesting conclusions.
#
# The filter does not include A or M because filenames can be
# sensitive information, and this is going to /var/log. (Chances of
# borg erroring out on a sensitive file in particular are low, so
# leave E and ? in the filter.)
#
# Directories for backup:
#
# - /srv contains the main community data, the most important things.
#   Have to explicitly include /srv/commdata, since it's a mountpoint and
#   borg is instructed not to cross filesystem boundaries.
# - /home and /root are home directories -- incidental user data
# - /etc has program configuration, but also /etc/group and /etc/passwd
#   (important for restoring ownership of files!)
# - /var contains system-level program data, including databases. Important
#   data *might* end up here. /var/log could be important in some situations.
/opt/commapps/backups/borg/venv/bin/borg create \
     --compression zstd,22 --one-file-system \
     --exclude-caches --exclude-from /opt/commapps/backups/borg/exclusions.lst \
     --stats --list --filter='E?' \
     "::drive_selective_{utcnow}" \
     /srv /srv/active-commdata-snapshot /etc /var /home /root || {
    borg_exit="$?"
    log "Borg died with non-zero exit $borg_exit"
    exit "$borg_exit"
}
log "Borg finished successfully"
