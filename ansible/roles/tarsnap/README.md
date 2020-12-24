# Tarsnap

Tarsnap is a service providing remote, encrypted, deduplicated,
compressed backups. It entails a preloaded account with pro rata
billing and an open source client that performs all encryption
locally.

It's a bit slow, especially on the restore side, but it does the job.

## General approach

- Each service host has its own Tarsnap private key
- Each service host runs a nightly backup job
- TODO: The supervisor rotates backups on behalf of the service hosts

## Details

NOT YET IMPLEMENTED

- The service host retains only a read-write version of the key
    - Delete and nuke access have been stripped from it so that if the
      machine is compromised the attacker cannot destroy existing
      backups.
- The supervisor has the full key for every service host
    - This is required for performing deletions. Read access is
      necessary because of the deduplication.
- `/srv/commdata` is backed up nightly using the read-write key; all
  ansible roles must store any sensitive or important data in this
  directory.
- The archive names contain the host name, rather than the roles the
  host performs.
- TODO: The supervisor has a daily task to rotate backups (that is,
  delete selected older backups) for each of those other hosts
- TODO: Because tarsnap requires in up-to-date cache dir per key, each host
  runs tarsnap with the `--fsck` flag before running a backup, since
  any intervening archive deletions from the supervisor will have put
  the cache dir out of sync. (Alternatively, the supervisor might be
  able to copy its copy of the cache dir over after performing
  rotations.)

## Key provisioning

For each new host, follow these instructions to create a full key and
save it off in several variations:

- Full key protected by GPG (just in case)
- Read/write-only key in vault, for new host to use
- Full key in vault, for supervisor machine to use [TODO]

Full key is used for periodic deletions of old archives. [TODO]
Read/write key cannot be used to delete archives (if an attacker gets
into the machine and wants to wipe it) but can be used to
`--fsck`. (This is needed when the supervisor has deleted some
archives, invalidating the machine's cache.)

**TODO**: Automate fsck after archive deletion/rotation (will need to
be done every time an archive is deleted using a different cache dir);
alternatively, push cache dir to host after deletions.

### Instructions

Mount ramdisks over sensitive working areas, including where
ansible-vault writes temporary plaintext copies of vaults. `ramfs` is
chosen here over `tmpfs` to avoid data being swapped out.

Also unalias `rm` if you've got it aliased to put things in the
Trash. Not that that would have ever bitten me...

```
sudo mount -t ramfs ramfs ~/tmp/ram && sudo chown `whoami`: ~/tmp/ram
sudo mount -t ramfs ramfs ~/.ansible/tmp && sudo chown `whoami`: ~/.ansible/tmp
unalias rm
```

Set up variables and a work directory.

```
MACHINE_NAME=_____
TMPDIR=~/tmp/ram/"$MACHINE_NAME"
mkdir "$TMPDIR"
```

Create a full tarsnap key for the machine and save off an encrypted
copy. This may or may not be the same passphrase you use for Ansible
vaults, and you can replace this GPG command with any approach you
prefer for saving secrets.

```
tarsnap-keygen --keyfile "$TMPDIR/tarsnap-full.key" --user comm-tarsnap-commdata@brainonfire.net --machine "$MACHINE_NAME"
gpg2 --symmetric --armor -o ~/secrets/appux/"tarsnap-machine-$MACHINE_NAME.key.gpg" < "$TMPDIR/tarsnap-full.key"
```

Make a read-and-write-only key for the machine to use and save it to
the vault.

```
tarsnap-keymgmt --outkeyfile "$TMPDIR/tarsnap-rw.key" -r -w "$TMPDIR/tarsnap-full.key"
(ansible-vault decrypt --output - roles/tarsnap/vars/vault.yml; echo "vault_tarsnap__rw_key_$MACHINE_NAME: |"; sed 's/^/  /' < "$TMPDIR/tarsnap-rw.key") | ansible-vault encrypt --output roles/tarsnap/vars/vault.yml
``

Save the full key for the supervisor machine to use.

```
(ansible-vault decrypt --output - roles/supervisor/vars/vault.yml; echo "vault_tarsnap__full_key_$MACHINE_NAME: |"; sed 's/^/  /' < "$TMPDIR/tarsnap-full.key") | ansible-vault encrypt --output roles/supervisor/vars/vault.yml
```

Clean up by unmounting -- this is the safest way to do it.

```
sudo umount ~/tmp/ram ~/.ansible/tmp
```

Make sure to update `roles/{tarsnap,supervisor}/vars/main.yml` with
the newest machine key dictionary entries.

## Deleting old archives

This is still an annoying manual process that must be done from the
controller machine using the full key that is kept GPG protected
there. The only impact of not running this every few months is that
costs slowly creep up, despite Tarsnap's deduplication.

TODO: Have the supervisor perform deletions automatically.

Mount a ramdisk:

```
sudo mount -t ramfs ramfs ~/tmp/ram && sudo chown `whoami`: ~/tmp/ram
unalias rm
```

Retrieve the full key:

```
gpg2 --decrypt ~/secrets/appux/tarsnap-machine-MACHINE_NAME.key.gpg > ~/tmp/ram/tarsnap-full.key
```

Make a cache dir, prepare it for use, and list the archives:

```
mkdir ~/tmp/ram/cache
tarsnap --fsck-prune --keyfile ~/tmp/ram/tarsnap-full.key --cachedir ~/tmp/ram/cache
tarsnap --list-archives --keyfile ~/tmp/ram/tarsnap-full.key --cachedir ~/tmp/ram/cache | sort > ~/tmp/ram/archives.lst
```

Edit the archives list to remove any entries you want to *keep*,
saving it as `delete.lst`. The perform the deletions:

```
tarsnap -d --archive-names ~/tmp/ram/delete.lst --print-stats --humanize-numbers --keyfile ~/tmp/ram/tarsnap-full.key --cachedir ~/tmp/ram/cache
```

Clean up by unmounting -- this is the safest way to do it:

```
sudo umount ~/tmp/ram
```

Finally, log into the machine whose archives have been trimmed and run
tarsnap's fsck so that the next backup will work properly:

```
tarsnap --fsck --keyfile /srv/commdata/backups/secrets/tarsnap-rw.key --cache /srv/commdata/cache/tarsnap
```

(TODO: Have hosts automatically run --fsck as part of their backup
process so that the supervisor is free to perform deletions at will.)

## TODO

- Timing of cron jobs
- Fast restore: https://github.com/directededge/redsnapper
