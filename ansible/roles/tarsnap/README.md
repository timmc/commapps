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
    - Read access is retained for two reasons: It's needed for at
      least the initial cache dir setup, and because it's nice to be
      able to do restores directly from the machine that needs them.
      It's not strictly necessary, since the supervisor could perform
      both of these actions, and theoretically an attacker might be
      interested in reading deleted files that are still in the
      archives, but it's likely not worth the trouble.
- The supervisor has the full key for every service host
    - This is required for performing deletions. Read access is
      necessary because of the deduplication.
    - The key is protected with a passphrase that is [TODO] stored on the
      same host, but in a different file.
- `/srv/commdata` is backed up nightly using the read-write key; all
  ansible roles must store any sensitive or important data in this
  directory.
- The archive names contain the host name, rather than the roles the
  host performs. The roles change over time, but Tarsnap machine keys
  are intended to be specific to a machine.
    - They also contain the timestamp of their creation. This is not
      just to make them unique and sortable, but to allow archive
      deletions to choose which older archives to delete.
- TODO: The supervisor has a daily task to rotate backups (that is,
  delete selected older backups) for each of those other hosts
- TODO: Because tarsnap requires an up-to-date cache dir per key, the
  supervisor must sync its version of the cache dir onto the focal
  host after performing deletions.
    - The supervisor would likely acquire a copy of the cache dir from
      the host, run the deletions, and then ship the cache dir back
      again.
    - Alternatively, each host could run with `--fsck` before
      performing a backup. (This is another reason to retain read
      permissions on the key, since fsck requires read + write.) This
      might also take longer and require more network traffic.

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
unalias rm rmdir
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

Read the tarsnap passphrase out of the supervisor's vars:

```
ansible-vault decrypt --output - roles/supervisor/vars/vault.yml | grep vault_supervisor__tarsnap_key_pass
```

Make a passphrased version of the full key for the supervisor machine
to use. Use the passphrase printed above when prompted.

```
tarsnap-keymgmt --outkeyfile "$TMPDIR/tarsnap-full.enc.key" -r -w -d --nuke --passphrased --passphrase-mem 25000000 --passphrase-time 8 "$TMPDIR/tarsnap-full.key"
(ansible-vault decrypt --output - roles/supervisor/vars/vault.yml; echo "vault_supervisor__tarsnap_full_enc_key_$MACHINE_NAME: |"; sed 's/^/  /' < "$TMPDIR/tarsnap-full.enc.key") | ansible-vault encrypt --output roles/supervisor/vars/vault.yml
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
unalias rm rmdir
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

## TODO

- Timing of cron jobs
- Fast restore: https://github.com/directededge/redsnapper
