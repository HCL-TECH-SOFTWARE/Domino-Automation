ANSIBLE ROLE
------------

# os
Basic Linux OS configuration


Role Variables
--------------
## main

*Basic Linux OS configuration*

This is the main entrypoint for the role.

It does the basic Linux configration:

Hostname, packages update, SELinux, firewall.

| Variable | Description | Type | Required | Default |
| -------- | ----------- | ---- | -------- | ------- |
| os__set_hostname | Related to os__set_hostname parameter. `True` = server hostname will be set using a hostname Linux command.  `False` = no changes will be made. | bool | no | `False` |
| os__hostname | Server hostname; if not specified, ansible_host from Ansible inventory is used. Related to *os__set_hostname* and *os__set_etc_hosts* parameters. | str | no | `` |
| os__set_etc_hosts | `True` = adds records for all servers in ansible_play_hosts_all to /etc/hosts. `False` = no changes will be made. | bool | no | `False` |
| os__generate_etc_hosts | Related to os__set_hostname parameter. `True` = server hostname will be stored in /etc/hosts, resolving to 192.168.0.1.  `False` = no changes will be made. | bool | no | `False` |
| os__update_all_packages | `True` = update all existing OS packages to the latest version. `False` = no changes will be made. | bool | no | `True` |
| os__packages_to_install | OS packages you want to install. | list(str) | no | `[]` |
| os__selinux | Configure SELinux. Options: `enforcing`, `permissive`, `disabled`. | str | no | `enforcing` |
| os__disable_firewall | Enable/Disable system firewall in OS. `True` = Disable firewall. `False` = Enable firewall and add defined rules. The current version of Sametime script was tested only with "true", which means firewall is disabled. | bool | no | `False` |
| os__fw_open_services | Services you want to open in the Linux firewalld. | list(str) | no | `[]` |
| os__fw_open_ports | Ports you want to open in the Linux firewalld. | list(str) | no | `[]` |


Dependencies
------------
None.

Example Playbook
----------------
```
- hosts: all
  tasks:
    - name: Importing role - os
      ansible.builtin.import_role:
        name: os
      vars:
        
```


License
-------
Apache License 2.0


Author Information
------------------
Petr Kunc @ HCLSoftware
