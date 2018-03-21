# Ansible config for Parsnips

Configuration management for Parsnips servers using Ansible.

## Requirements

- ansible
- ssh-agent (optional)
- gpg-agent (optional)

## Setup

- Have SSH private key installed, perhaps in
  `~/.ssh/id_ansible_parsnips`, with a strong passphrase
- Have Ansible vault passphrase in GPG-encrypted file, perhaps in
  `../vault-passphrase.gpg` (using symmetric encryption, and again a
  strong passphrase)
    - The vault passphrase itself is *very* strong, since the
      encrypted vault will be public, so offline attacks are
      possible. I used `cat /dev/urandom | tr -dc '[:print:]' | head -c80`
      to produce the passphrase.
    - The passphrase protecting vault-passphrase.gpg is something
      you'll need to type in from time to time, so it has to be
      memorable, which limits the strength. Use diceware for this.

## Run

Unlock the SSH private key for your session, if using ssh-agent:

```
ssh-agent bash
ssh-add ~/.ssh/id_ansible_parsnips
```

Tell the vault script where to find the encrypted passphrase, if using
gpg-agent:

```
export VAULT_PASSPHRASE_GPG_FILE=vault-passphrase.gpg
```

And run the parsnips.yml playbook on the production hosts inventory:

```
ansible-playbook parsnips.yml -i prod.ini --vault-password-file=open-vault.sh
```

If you're not using gpg-agent to manage the vault password file,
instead run this command:

```
ansible-playbook parsnips.yml -i prod.ini --ask-vault-pass
```

## Secrets

Secrets are stored in `ansible/group_vars/*/vault.yml` vault variable
files for each relevant host group. Each secret variable has the
`vault_` prefix, and is accompanied by an assignment in an
accompanying `vars.yml` file to a variable *without* that
prefix. (This is a common Ansible pattern.)

The `vault.yml` files are not in source control. The assignments in
the indirection files should each have a comment describing the secret
-- how it was generated, and the last date it was generated, or any
changed inputs. This is in lieu of versioning the actual secret, but
still provides for some degree of version history.
