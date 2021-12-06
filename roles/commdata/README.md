# Community data partition

An encrypted partition containing data created, owned, and managed by
the users of these services. May also contain sensitive system files,
such as TLS private keys.

The LUKS portion of the playbook creates and formats a LUKS partition
as needed, and creates a systemd service that opens the partition as
`con-commdata`.

The LVM portion creates a
snapshot-capable filesystem in that partition and adds a service that
mounts the filesystem as `/srv/commdata`.
