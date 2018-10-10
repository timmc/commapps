#!/bin/bash
# Unmount community-data filesystem

set -eu -o pipefail

# Automatically unmounts
zpool export commdata
