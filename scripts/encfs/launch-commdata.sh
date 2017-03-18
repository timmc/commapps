#!/bin/bash
# Decrypt and mount community-data partition, then launch sandstorm

set -eu -o pipefail

device="UUID=ac597ea6-a8b1-4a03-a267-8a200f02104d" # /dev/sda5
luks_vol_name="con-commdata"
mtpoint="/opt/commdata"

cryptsetup --key-file /mnt/not-an-hsm/commdata/enckey/pass.txt \
           open "$device" "$luks_vol_name" --type luks
mount -t zfs /dev/mapper/"$luks_vol_name" "$mtpoint"

service sandstorm start

# This should be turned into a systemd service, I think.
