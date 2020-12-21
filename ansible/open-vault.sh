#!/bin/bash
# Call with VAULT_PASSPHRASE_GPG_FILE environment variable pointing to
# the vault_passphrase.gpg file.

set -eu -o pipefail

# adapted from
# https://github.com/yaegashi/ansible-snippets/blob/master/gnupg/ansible-gpg-file.sh

if [ -z "$GPG_TTY" ]; then
    echo "Error: GPG_TTY variable must be set for gpg-agent to work"
    cat << EOF
# The following must be in .bashrc or similar:
GPG_TTY=\$(tty)
export GPG_TTY
EOF
    exit 1
fi

gpg --batch --use-agent --decrypt -- \
    "${VAULT_PASSPHRASE_GPG_FILE:-$HOME/secrets/appux/vault-passphrase.gpg}"
