#!/bin/bash
# Unmount community-data filesystem - LVM + ext4

set -eu -o pipefail

if findmnt --source /dev/commdata/main; then
    umount /dev/commdata/main
fi
lvchange --activate n commdata/main
vgchange --activate n commdata
