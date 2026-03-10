# lab

Ansible files for the homelab.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [check inventory](#check-inventory)
- [run playbooks](#run-playbooks)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## check inventory

```sh
ansible -i lab/inventory.ini harpocrates -m ping
```

## run playbooks

```sh
# base
ansible-playbook -i lab/inventory.ini lab/playbook/base.yml

# podman
ansible-playbook -i lab/inventory.ini lab/playbook/podman.yml
```
