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
ansible-playbook --vault-password-file=open-vault.sh parsnips.yml -i hosts.prod
```

If you're not using gpg-agent to manage the vault password file,
instead run this command:

```
ansible-playbook --ask-vault-pass parsnips.yml -i hosts.prod
```
