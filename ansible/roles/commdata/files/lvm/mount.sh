#!/bin/bash
# Mount community-data filesystem - LVM + ext4

set -eu -o pipefail

vgchange --activate y commdata
lvchange --activate y commdata/main

if findmnt --noheadings --list --source /dev/commdata/main --mountpoint /srv/commdata; then
    echo >&2 "Volume already mounted correctly"
    exit 0
fi

src_mounts=$(findmnt --noheadings --list --source /dev/commdata/main || true)
mpt_mounts=$(findmnt --noheadings --list --mountpoint /srv/commdata || true)

if [[ -n "$src_mounts" ]]; then
    echo >&2 "Volume already mounted elsewhere:"
    echo >&2 "$src_mounts"
    exit 1
fi

if [[ -n "$mpt_mounts" ]]; then
    echo >&2 "Mountpoint already in use for different source:"
    echo >&2 "$mpt_mounts"
    exit 1
fi

mount -t ext4 /dev/commdata/main /srv/commdata
