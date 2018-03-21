# Tarsnap

Tarsnap is a service providing remote, encrypted, deduplicated,
compressed backups. It entails a preloaded account with pro rata
billing and an open source client that performs all encryption
locally.

## General approach

- Each service host has its own Tarsnap private key
- Each service host runs a nightly backup job
- The management host rotates backups on behalf of the service hosts

## Details

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

## TODO

- Timing of cron jobs
