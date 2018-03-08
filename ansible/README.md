# Ansible config for Parsnips

Running playbook from controller machine:

```
ssh-agent bash
ssh-add ~/.ssh/id_ansible_root
ansible-playbook -i hosts.prod parsnips.yml
```
