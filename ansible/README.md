# Ansible config for Appux

Configuration management for Appux servers using Ansible.

## Requirements

- `sudo apt install python3 python3-venv`
- ssh-agent (optional)
- gpg-agent (optional)

## Setup

- Create a virtualenv: `python3.7 -m venv .venv37`
- If desired, first upgrade dependencies:
  `pip install pip-tools && pip-compile -U -o requirements/base.txt requirements/base.in`
- Install Python dependencies:
  `pip install pip-tools && pip-sync requirements/base.txt`
- Install Ansible Galaxy dependencies:
  `ansible-galaxy collection install -r galaxy-reqs.yml`
- Have SSH private key installed, perhaps in
  `~/.ssh/id_ansible_appux`, with a strong passphrase
- Have Ansible vault passphrase in GPG-encrypted file, perhaps in
  `../vault-passphrase.gpg` (using symmetric encryption, and again a
  strong passphrase)
    - The vault passphrase itself is *very* strong, since the
      encrypted vault might become public at some point, so offline attacks are
      possible. I used `cat /dev/urandom | tr -dc '[:print:]' | head -c80`
      to produce the passphrase.
    - The passphrase protecting vault-passphrase.gpg is something
      you'll need to type in from time to time, so it has to be
      memorable, which limits the strength. Use diceware for this.

## Run

Activate the virtualenv:

```
source .venv37/bin/activate
```

Unlock the SSH private key for your session, if using ssh-agent:

```
ssh-agent bash
ssh-add ~/.ssh/id_ansible_appux
```

And run the appux.yml playbook on the production hosts inventory:

```
ansible-playbook appux.yml -i prod.ini --diff --check
```

If you're not using gpg-agent to manage the vault password file,
instead run this command:

```
ansible-playbook appux.yml -i prod.ini --ask-vault-pass --diff --check
```

Remove `--check` if the output looks reasonable.

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

## Moving a service

Let's say we're moving a service from one host to another. In examples
below, the `jabber` service is moving from a "source" of
`murphy.internal` to a "destination" of `toster.internal`.

- Shut down the service on the source host.
    - Example: `ssh root@murphy.internal systemctl stop prosody`
- Remove any existing service data on the destination machine
    - Example: `ssh root@toster.internal rm -rf /srv/commdata/jabber/`
- Copy over the service data using a tar stream
    - Example: `ssh root@murphy.internal "tar czf - -C /srv/commdata jabber" | ssh root@toster.internal "tar xzf - -C /srv/commdata"`
- Add destination host to service in prod.ini and run Ansible on
  it. This will also start the service.
    - Example: Add `toster.internal` under the `[jabber]` header and
      run Ansible with `--limit toster.internal`
- Change any DNS or router configuration to point to destination
- Confirm service is running properly on destination, then delete
  files from source
    - Example: `ssh root@murphy.internal rm -rf /srv/commdata/jabber/`
