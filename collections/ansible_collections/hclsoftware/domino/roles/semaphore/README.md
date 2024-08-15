ANSIBLE ROLE
------------

# semaphore
Performs initial Semaphore configuration


Role Variables
--------------
## main

*Performs initial Semaphore configuration*

This is the main entrypoint for the role.

Initialize Semaphore deployment by creating configuration documents:

Token, Project, SSH key, Repository, Inventory, Task Templates

| Variable | Description | Type | Required | Default |
| -------- | ----------- | ---- | -------- | ------- |
| semaphore__username | Administrator login name | str | no | `admin` |
| semaphore__password | Administrator password | str | no | `password` |
| semaphore__hostname | Semaphore hostname. When run in a local container, use `localhost`. | str | no | `localhost` |
| semaphore__port | Semaphore port. | int | no | `3000` |
| semaphore__project | Project name. Used as a name of a configuration document. | str | no | `My Project` |
| semaphore__repository | Repository name. Used as a name of a configuration document. | str | no | `My Repository` |
| semaphore__repository_path | Repository path. When run in a local container, must be valid inside the container. | str | no | `/repo` |
| semaphore__key | SSH key name. Used as a name of a configuration document. | str | no | `My Key` |
| semaphore__key_file | SSH key file path used to log into the remore server. When run in a local container, must be valid inside the container. | str | no | `~/.ssh/id_rsa` |
| semaphore__key_user | User account name used to log into the remote server. | str | no | `ansible` |
| semaphore__inventory | Inventory name. Used as a name of a configuration document. | str | no | `My Inventory` |
| semaphore__inventory_file | Path to the inventory file. When run in a local container, must be valid inside the container. | str | no | `/repo/inventory.yml` |
| semaphore__environment | Environment name. Used as a name of a configuration document. | str | no | `My Environment` |
| semaphore__environment_json | Dictionary with optional parameters, specific for the environment. | dict | no | `{}` |
| semaphore__view | View name. Used as a name of a configuration document. | str | no | `My View` |
| semaphore__templates | List with dictionary items. Templates for creating Semaphore tasks documents. | list(dict) | no | `[ { name: My Template, playbook: playbook.yml, description: Playbook description, arguments: [] } ]` |
## assert

*Check input values before configuring Sempahore*

This is an alternative entrypoint for the role.

Performs validation (assertion) of values, combined from the role defaults values and playbook values.

This validation is part of the main role task.

| Variable | Description | Type | Required | Default |
| -------- | ----------- | ---- | -------- | ------- |
## delete

*Deletes template tasks documents*

This is an alternative entrypoint for the role.

Deletes task templates documents.

| Variable | Description | Type | Required | Default |
| -------- | ----------- | ---- | -------- | ------- |


Dependencies
------------
None.

Example Playbook
----------------
```
- hosts: all
  tasks:
    - name: Importing role - semaphore
      ansible.builtin.import_role:
        name: semaphore
      vars:
        
```


License
-------
Apache License 2.0


Author Information
------------------
Petr Kunc @ HCLSoftware
