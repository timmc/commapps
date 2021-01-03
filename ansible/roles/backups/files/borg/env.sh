# Set up environment for borgbackup

export BORG_PASSCOMMAND="cat /srv/commdata/backups/borg/key_passphrase"
export BORG_REPO="$(cat /srv/commdata/backups/borg/repo_address)"

# CheckHostIP=no: Don't add IP addresses to the known_hosts file,
# since this doesn't really improve security for automated access, and
# Ansible will just want to change it back again (and the IP address
# is likely to change multiple times in the future).
export BORG_RSH="ssh -i /srv/commdata/backups/borg/ssh_priv_key_append -o UserKnownHostsFile=/srv/commdata/backups/borg/repo_known_hosts -o CheckHostIP=no"

# A "home directory" for borg, in which it will create /config/borg
export BORG_BASE_DIR="/srv/commdata/backups/borg"
# Keep all the caches together so that other tools (which don't follow
# the cache directory tag spec) won't try to back them up.
export BORG_CACHE_DIR="/srv/commdata/cache/borg"
