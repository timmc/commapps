#!/bin/bash
# Unmount and close encrypted community-data partition

umount "/opt/commdata"
zpool export commdata
cryptsetup luksClose /dev/mapper/con-commdata
