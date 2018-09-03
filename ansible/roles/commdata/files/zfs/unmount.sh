#!/bin/bash
# Unmount community-data filesystem

set -eu -o pipefail

umount "/srv/commdata"
zpool export commdata
