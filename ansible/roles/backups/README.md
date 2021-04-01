# Backups

This role uses borgbackup to provide for deduplicated, compressed, and
encrypted backups to a remote server.

Each host runs a nightly backup job to its own borg repo, for which it
has an SSH key authorized for append-only access. Each run creates a
timestamped archive in the repo.

Since the archives make use of deduplication, automated pruning from
the supervisor host is not an urgent need, although it could be
implemented in the future. (Note: It should be preceded by some sort
of correctness check of the most recent archives.)

## Security notes

The encryption and authentication key for the archives is stored in
the repo itself, encrypted with a passphrase. The passphrase is stored
in /srv/commdata.

## Recovery

Borg's append-only mode is not as straightforward as Tarsnap's
write-only keys and has *serious caveats* attached; if you need to
recover from an attack where the attacker was able to access the repo
with an append-only key, first remove all access to the repo for
non-append-only keys and then seek assistance. A single access with a
full-powered key can make an attacker's changes permanent!

If there was any malicious activity on the computer that was backed
up, this needs to handled very carefully. **Do not perform any
operations with the non-append-only key**, as this could make an
attacker's changes permanent (such as archive deletions).

Otherwise, a straightforward mount or extract is appropriate:

```
source /opt/commapps/backups/borg/env.sh
cd /srv/commdata/tmp/restore/...
/opt/commapps/backups/borg/venv/bin/borg extract ::ARCHIVE srv/active-commdata-snapshot/...
```

Notes:

- This extract command will extract files into the current directory
- Leave off the leading slash from the paths to extract
- Paths to extract start with the *snapshot* dir, not `/srv/commdata`

## Host configuration

Create a borg repository somewhere. <https://www.borgbase.com> is a
good place.

Then set up the below variables, including uploading the SSH public
key to the borg server and marking it as an authorized append-only
key.

The first Ansible run should initialize the repository.

### `borg__cron_timing`

Pick a random minute and hour and enter them in a format like `53 9 * * *`.

### `vault_borg__repo_address`

Repository address for borgbackup, indicating username, host, and
path. See the supported
[borgbackup repo URL formats](https://borgbackup.readthedocs.io/en/stable/usage/general.html#repository-urls)
for more information.

### `vault_borg__repo_known_hosts`

An SSH `known_hosts` file prepopulated with keys for the repo. Can be
left unhashed, and that makes verification easier. Example of how to
generate:

`ssh-keyscan -t rsa,ecdsa,ed25519 a4b3c2d1.repo.borgbase.com 2>/dev/null > a4b3c2d1_known_hosts`

Then generate fingerprints (SHA256 hashes of the public keys) so you
can verify them against the server's advertised fingerprints:

```
$ cat a4b3c2d1_known_hosts | while IFS= read -r line; do echo "$line" | cut -d' ' -f2; echo "$line" | cut -d' ' -f3 | base64 -d | sha256sum | cut -d' ' -f1 | xxd -r -p | base64; done
ssh-rsa
Wyt7NfJy9XSVeGFBG5RIbIukYMetp2kMy8o/GQ2V/5w=
ecdsa-sha2-nistp256
BmYzPJ4GEOilkv1z1nwhHMkkFv/FRyYOAcVRZKf0NVQ=
ssh-ed25519
tlz8o+DhESqRqmPaDA1yOlT7avGqCEqdhbjB8h6R29s=
```

### `vault_borg__key_passphrase`

Generate a diceware passphrase by running the following and trimming
it down to about ten words:

`shuf /usr/share/dict/words | head -n20 | tr '\n' ' '`

### `vault_borg__ssh_priv_key_append`

Mount a ramdisk for safety. `ramfs` is chosen here over `tmpfs` to
avoid data being swapped out. Unalias `rm` if you have it aliased so
that sensitive date doesn't end up in your desktop trash can.

```
sudo mount -t ramfs ramfs ~/tmp/ram && sudo chown `whoami`: ~/tmp/ram
unalias rm rmdir
```

Generate an SSH private key with no passphrase:

```
ssh-keygen -f ~/tmp/ram/id_append -t ed25519 -N "" -C ""
```

Upload the public key (`~/tmp/ram/id_append.pub`) to the borg server
as an append-only key, and put the private key in the vault.

Clean up by unmounting -- this is the safest way to do it.

```
sudo umount ~/tmp/ram ~/.ansible/tmp
```
