# Install ansible on debian

Ansible can manage complex deployments, and scale deployments on thousands of servers. The official site is [here](https://www.ansible.com/)

You can find the official ansible installation guide [here](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html).

## Ansible Python Compatibility

Ansible requires python to run, so before you install ansible, make sure you have python installed.

Based on the table below and the available python version for your ansible host you should choose the appropriate ansible version to use with kubespray.

|Ansible Version|Python Version|
|---------------|--------------|
|2.11|2.7,3.5-3.9|
|2.12|3.8-3.10|

## Install virtualenv

It is recommended to deploy the ansible version used by kubespray into a python virtual environment. So we need to install virtualenv too.

```shell
# if you don't have pip, install pip first
sudo apt install python3-pip

# install virtual env
python3 -m pip install virtualenv

# if you see this warning The script virtualenv is installed in '/home/pliu/.local/bin' which is not on PATH, you need to add /home/pliu/.local/bin into your path

# For example you can update path by adding below line to .bashrc
export PATH="/home/pliu/.local/bin:$PATH"

```

## Install ansible

This doc will install a specific ansible to run kubespary, so it'n not the standard way to install ansible.
For more information on ansible installation, you can visit this [page](https://www.guru99.com/ansible-tutorial.html)


Now follow the below steps to install ansible:

### Step 1: creat an virtual env 

The full shell script can be found [here](../bash_commands/create_vir_env.sh)

```shell
# change it if you want
ROOTDIR=~/opt
mkdir -p $ROOTDIR

VENVDIR=$ROOTDIR/kubespray-venv

KUBESPRAYDIR=$ROOTDIR/kubespray

# change it based on your python version
ANSIBLE_VERSION=2.12

# create the virtual env for ansible
virtualenv  --python=$(which python3) $VENVDIR
```

### Step 2: Install ansible via kubespary installation script

```shell
# activate the virtual env
source $VENVDIR/bin/activate

# clone the kubespray source from git repo
cd $ROOTDIR

# The tag number should be one of the release (latest release is recommended)
TAG=v2.19.1
git clone -b $TAG https://github.com/kubernetes-sigs/kubespray.git

# go to the kubespray dir
cd $KUBESPRAYDIR

# install the dependenices and ansible
pip install -U -r requirements-$ANSIBLE_VERSION.txt

# test the dependencies and install ansible
test -f requirements-$ANSIBLE_VERSION.txt && 

# Below two command does not work, because the file does not exist, and the ansible-galaxy command
# does not take .txt file. 
ansible-galaxy role install -r requirements-$ANSIBLE_VERSION.yml

ansible-galaxy collection -r requirements-$ANSIBLE_VERSION.yml

```

## Test your ansible

First you need to build an inventory which is a list of server name and ip address.

Below example shows that we can divide server in groups, and each server is represented with a name
and its ip address

```text
[k8s]
k8s-02 ansible_host=10.0.2.5
k8s-03 ansible_host=10.0.2.4

[others]
k8s-01 ansible_host=10.0.2.6
```

### Ad-hoc commands

The simplest way to use ansible is to call ad-hoc commands. Below example will call ping command on the servers that are in the inventory

```shell
ansible -i hosts all -m ping

# You should see below results
k8s-02 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}

k8s-03 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3
    },
    "changed": false,
    "ping": "pong"
}

k8s-01 | UNREACHABLE! => {
    "changed": false,
    "msg": "Failed to connect to the host via ssh: ssh: connect to host 10.0.2.6 port 22: No route to host",
    "unreachable": true
}

```

You can notice for k8s-02 and 03, it shows success, which means the command worked. But for k8s-01, it shows unreachable, which means ansible can't connect to this server.

You can also limit the server that you want to run commands. For example, below command will only run command on group k8s. 

```shell
ansible -i hosts k8s -m ping

# we can even limit to the server name (e.g. k8s-02)
ansible -i hosts all -m ping --limit k8s-02
```

### ansible playbook

Ansible Playbooks are the way of sending commands to remote systems through scripts. Ansible playbooks are used to configure complex system environments to increase flexibility by executing a script to one or more systems. Ansible playbooks tend to be more of a configuration language than a programming language.

Below is an example:

```yaml
---

# defines the target host of the task
- hosts: group1
  tasks:
  - name: Enable SELinux
    selinux:
      state: enabled
    # The when clause is the activation condition of the task. The ansible_os_family variable is gathered via gather_facts functionality.
    when: ansible_os_family == 'Debian'
    # Register can save output of the task to a variable, this variable can be used in the future task
    register: enable_selinux

  # a message will be displayed for the host user if the SELinux was indeed enabled before.
  - debug:
      Imsg: "Selinux Enabled. Please restart the server to apply changes."
    when: enable_selinux.changed == true

- hosts: group2
  tasks:
  - name: Install apache
    yum:
      name: httpd
      state: present
     # we can use logic operator in the when close 
    when: ansible_system_vendor == 'HP' and ansible_os_family == 'RedHat'
```

You can also handler task. Below example shows that we changed the config file of sshd, and we need to restart the service to make the change take effect.

```yaml
- hosts: group2
  tasks:
  # this task will go to the target file and find the target line by using
  # regexp, and replace the target line with value which we specified. 
  - name: sshd config file modify port
    lineinfile:
     path: /etc/ssh/sshd_config
     regexp: 'Port 28675'
     line: '#Port 22'
     # notify cluase can call the handler task 
    notify:
       - restart sshd

handlers
    # a handler task will not be executed if not notified
    - name: restart sshd
      service: sshd
        name: sshd
        state: restarted
```

### Ansible Roles

In a playbook, we defines all the task in one file. This makes the sub-module not reusable