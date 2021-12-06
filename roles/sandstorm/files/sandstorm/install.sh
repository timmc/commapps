#!/bin/bash

set -eu -o pipefail

install_to="$1"

installer_file="$(mktemp sandstorm-installer.sh.XXXXXXXX)"
wget --output-document="$installer_file" --timeout=60 \
     "https://raw.githubusercontent.com/sandstorm-io/sandstorm/master/install.sh"

# The -d flag says to accept all defaults (non-interactive mode)
export OVERRIDE_SANDSTORM_DEFAULT_DIR="$install_to"
export REPORT=no
bash -- "$installer_file" -d

rm -- "$installer_file"
