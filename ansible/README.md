# Ansible config for Parsnips

Configuration management for Parsnips servers using Ansible.

## Requirements

- ansible
- ssh-agent (optional)

## Setup

- Have SSH private key installed, perhaps in
  `~/.ssh/id_ansible_parsnips`, with a strong passphrase

## Run

Unlock the SSH private key for your session:

```
ssh-agent bash
ssh-add ~/.ssh/id_ansible_parsnips
```

Run the parsnips.yml playbook on the production hosts inventory:

```
ansible-playbook parsnips.yml -i hosts.prod
```
