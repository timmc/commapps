#!/bin/bash
# Call with VAULT_PASSPHRASE_GPG_FILE environment variable pointing to
# the vault_passphrase.gpg file.

set -eu -o pipefail

# adapted from
# https://github.com/yaegashi/ansible-snippets/blob/master/gnupg/ansible-gpg-file.sh

if [ -z "$GPG_TTY" ]; then
    cat << EOF >&2
Error: GPG_TTY variable must be set for gpg-agent to work
# The following must be in .bashrc or similar:
GPG_TTY=\$(tty)
export GPG_TTY
EOF
    exit 1
fi

pass_file="${VAULT_PASSPHRASE_GPG_FILE:-$HOME/secrets/appux/vault-passphrase.gpg}"
gpg --batch --use-agent --decrypt --quiet -- "$pass_file"
