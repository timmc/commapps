#!/bin/bash
# Decrypt and mount community-data partition

set -eu -o pipefail

# TODO: Parameterize the UUID here
cryptsetup --key-file /mnt/not-an-hsm/commdata/enckey/pass.txt \
           open UUID=ac597ea6-a8b1-4a03-a267-8a200f02104d \
           con-commdata --type luks

# ZFS tries importing this on startup and fails; try again now that
# the partition is decrypted.
zpool import commdata

mount -t zfs /dev/mapper/con-commdata /opt/commdata
