# Ansible roles

Read this [doc](https://blog.stephane-robert.info/docs/infra-as-code/gestion-de-configuration/ansible/ecrire-roles/#utilisation-de-vos-r%C3%B4les-dans-vos-playbooks) 
for more details on how to write an ansible role

An **Ansible Role** is a `self-contained, portable unit` of Ansible automation that serves as the **preferred method** for 
grouping related tasks and associated variables, files, handlers, and other assets in a known file structure. 
While automation tasks can be written exclusively in an Ansible Playbook, Ansible Roles allow you to create bundles 
of automation content that can be 
- run in 1 or more plays, 
- reused across playbooks, 
- shared with other users in collections.


## role organization

`Ansible Roles` are expressed in YAML files. When a role is included in a task or a play, Ansible looks for 
a `main.yml` file in at least 1 of 8 standard role directories such as :
- tasks, 
- handlers, 
- modules, 
- defaults, 
- variables, 
- files, 
- templates,
- meta.

```text
roles/
    my_role1/               # this hierarchy represents a "role"
        tasks/            #
            main.yml      #  <-- tasks file can include smaller files if warranted
        handlers/         #
            main.yml      #  <-- handlers file
        templates/        #  <-- files for use with the template resource
            ntp.conf.j2   #  <------- templates end in .j2
        files/            #
            bar.txt       #  <-- files for use with the copy resource
            foo.sh        #  <-- script files for use with the script resource
        vars/             #
            main.yml      #  <-- variables associated with this role
        defaults/         #
            main.yml      #  <-- default lower priority variables for this role
        meta/             #
            main.yml      #  <-- role dependencies
        library/          # roles can also include custom modules
        module_utils/     # roles can also include custom module_utils
        lookup_plugins/   # or other types of plugins, like lookup in this case

    my_role2/              # same kind of structure as "my_role1" was above, but for another purpose
    my_role3/              # ""
    my_role4/              # ""
```


## Role vs Playbook

Why use an Ansible Role instead of an Ansible Playbook?
Ansible Roles and Ansible Playbooks are both tools for organizing and executing automation tasks, but each serves a different purpose. Whether you choose to create Ansible Roles or write all of your tasks in an Ansible Playbook depends on your specific use case and your experience with Ansible.

Most automation developers and system administrators begin creating automation content with individual playbooks. A playbook is a list of automation tasks that execute for a defined inventory. Tasks can be organized into a play—a grouping of 1 or more tasks mapped to a specific host and executed in order. A playbook can contain 1 or more plays, offering a flexible mechanism for executing Ansible automation in a single file.

While playbooks are a powerful method for automating with Ansible, writing all of your tasks in a playbook isn’t always the best approach. In instances where scope and variables are complex and reusability is helpful, creating most of your automation content in Ansible Roles and calling them within a playbook may be the more appropriate choice.

The following example illustrates the use of a role, linux-systemr-roles.timesync, within a playbook. In this instance, over 4 tasks would be required to achieve what the single role accomplishes. 


## Creating a role


You can create a new role skeleton by using `ansible-galaxy`

```shell
 ansible-galaxy role init role_name
```

## Sharing a role

There are few ways to share your ansible roles:

- **Ansible Galaxy**: A free repository for sharing roles and other Ansible content with the larger Ansible community. 
           Roles can be uploaded to Ansible Galaxy via the command-line (CLI), whereas collections can be shared 
               from the web interface. Since Ansible Galaxy is a community site, content is not vetted, certified.
- **Ansible automation hub**: repo for `Red Hat Ansible Automation Platform`, which is a central repository for 
                       finding, downloading, and sharing `Ansible Content Collections`.
- **Private automation hub**: An on-premise repository. You can share roles and other automation content within your 
                           enterprise, allowing teams to simplify workflows and speed up automation. 

## Use roles in an ansible playbook

There are three ways to integre an `ansible role` in an `ansible playbook`.
- Use the `roles` option in playbook
- Use the `include_role` in a task 
- Use the `import_role` in a task

### Use the `roles` option in playbook

Below is an example of a playbook which calls the role `configure_sshd_pam_sssd_openldap` and `intall_nginx` before tasks. 

> If you have multiple roles, the order is not guarantied with this approach. The roles are executed before tasks. If you
> want to order the task and roles, use the `include_role` or `import_role`

```yaml
---
- hosts: linux_servers
  roles:
    - configure_sshd_pam_sssd_openldap
    - install_nginx
  tasks:
    - name: task1
```

### Use the `include_role` in a task 

The content of the role is parsed during the execution of the task. 

```yaml
---
- hosts: linux_servers
  tasks:
    - name: Print a message
      ansible.builtin.debug:
        msg: "this task runs before the role1"

    - name: Include the role with name role1
      ansible.builtin.include_role:
        name: role1
      vars:
        dir: '/opt/a'
        app_port: 5000
```

### Use the `import_role` in a task

The content of the role is parsed at the start of the playbook. 