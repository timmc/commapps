#!/bin/bash
# Call with VAULT_PASSPHRASE_GPG_FILE environment variable pointing to
# the vault_passphrase.gpg file.
#
# See ansible.cfg for more details.

set -eu -o pipefail


# Precondition: ramfs mounted over Ansible tmp dir

while true; do
    mtype=`findmnt --output=fstype --noheadings -- ~/.ansible/tmp || true`
    if [[ "$mtype" = "ramfs" ]]; then
        break
    fi
    cat <<EOF >&2
WARNING: ~/.ansible/tmp not mounted as ramdisk! Some vault operations result in
vault contents being written in plaintext to that directory. If you are using
these vault operations (especially 'edit'), you are strongly encouraged to
mount a ramdisk over the tmp dir as follows before proceeding:

sudo mount -t ramfs ramfs ~/.ansible/tmp && sudo chown `whoami`: ~/.ansible/tmp

EOF
    read -p "Continue? Answer 'unsafe' in caps to proceed: " answer
    if [[ "$answer" = "YES" ]]; then
        break
    else
        echo >&2 -e "\n\nUnknown response. Rechecking...\n\n"
    fi
done


# Precondition: GPG agent running

if [ -z "$GPG_TTY" ]; then
    cat << EOF >&2
Error: GPG_TTY variable must be set for gpg-agent to work
# The following must be in .bashrc or similar:
GPG_TTY=\$(tty)
export GPG_TTY
EOF
    exit 1
fi


# Main

pass_file="${VAULT_PASSPHRASE_GPG_FILE:-$HOME/secrets/appux/vault-passphrase.gpg}"
gpg --batch --use-agent --decrypt --quiet -- "$pass_file"
