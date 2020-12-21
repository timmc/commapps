# Tarsnap

Tarsnap is a service providing remote, encrypted, deduplicated,
compressed backups. It entails a preloaded account with pro rata
billing and an open source client that performs all encryption
locally.

## General approach

- TODO: Each service host has its own Tarsnap private key
- Each service host runs a nightly backup job
- TODO: The management host rotates backups on behalf of the service hosts

## Details

NOT YET IMPLEMENTED

- The service host retains only a read-write version of the key
    - Delete and nuke access have been stripped from it so that if the
      machine is compromised the attacker cannot destroy existing
      backups.
- The management host has the full key for every service host
    - This is required for performing deletions. Read access is
      necessary because of the deduplication.
- Each ansible role is responsible for initiating nightly backups for
  whatever data it manages, using the read-write key.
- The archives contain the host name and the role name (or similar).
- The management host has a daily task to rotate backups (that is,
  delete selected older backups) for each of those other hosts
- Because tarsnap requires in up-to-date cache dir per key, each
  host runs tarsnap with the `--fsck` flag before running a backup,
  since any intervening archive deletions from the management host
  will have put the cache dir out of sync.

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

```
sudo mount -t ramfs ramfs ~/tmp/ram && sudo chown `whoami`: ~/tmp/ram
sudo mount -t ramfs ramfs ~/.ansible/tmp && sudo chown `whoami`: ~/.ansible/tmp
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
(ansible-vault decrypt --output - group_vars/all/vault.yml; echo "vault_tarsnap__rw_key_$MACHINE_NAME: |"; sed 's/^/  /' < "$TMPDIR/tarsnap-rw.key") | ansible-vault encrypt --output group_vars/all/vault.yml
``

Save the full key for the management machine to use.

```
(ansible-vault decrypt --output - group_vars/supervisor/vault.yml; echo "vault_tarsnap__full_key_$MACHINE_NAME: |"; sed 's/^/  /' < "$TMPDIR/tarsnap-full.key") | ansible-vault encrypt --output group_vars/supervisor/vault.yml
```

Clean up.

```
rm -rf "$TMPDIR"
sudo umount ~/tmp/ram ~/.ansible/tmp
```

Make sure to update `group_vars/all/vars.yml` and
`host_vars/supervisor/vars.yml` with the newest machine key dictionary
entries.

## TODO

- Timing of cron jobs
- Fast restore: https://github.com/directededge/redsnapper
