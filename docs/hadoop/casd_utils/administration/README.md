# D1MUTUA administration

The projet `D1MUTUA` has a Windows server, users already have groups defined in AD and associated projet data directory
hierarchy defined in the Windows server. 

For the administrator, you have four main tasks:
1. synchronize user account and groups of the Windows server(AD) to the Linux servers.
2. configure ssh client on `D1MUTUA` Windows server to allow user to connect and transferring data to the Linux servers
3. Create home directory on hdfs and clone the same projet data directory hierarchy of `D1MUTUA` on the HDFS.
4. Ensure the ACL on all HDFS files and directories as in the Windows server.

## 1. User account and groups synchronization in Linux server 

All the linux servers are connected to the CASD AD/KDC server. All the user accounts and groups information are from
the AD/KDC.

The `user authentication` in Linux server is done via SSO `ticket Kerberos`. The first authentication is done inside
the Windows server, after the authentication the Windows server grant user a `ticket kerberos`. When user connecte to 
the Linux server, a new TGT is delegated to the linux server. For example when user connect to linux server via ssh,
The authentication process `ssh client(windows) -> sshd(linux) -> PAM -> sssd -> Kerberos -> AD`

The groups synchronization is done via `sssd` and `Name Service Switch (NSS)`. When a user is connected/authenticated, a user 
lookup will be initiated to get user groups. By default, without NSS, the system checks `/etc/passwd` only. With NSS, 
the system can do `user lookup -> files(/etc/passwd) -> sssd -> ldap/AD -> …`

The key config file are(to do):
- /etc/ssh/sshd_config
- /etc/pam.d/...(six files)
- /etc/nss.conf

### 1.1 Access control

Even the user has an account in AD and a valid kerberos ticket, it does not mean this user has the right to access the 
Linux servers. We use RBAC to control user access of the linux servers. So in `sshd_config`, we use `allow group` to
control which group of the users has access.

> For example, for project `D1MUTUA`, we only allow users of group `D1MUTUA`.

## 2. Configure ssh client on windows side

The minimum configuration of ssh client (C:\Users\<user-name>\.ssh\config) on windows side is shown in the below example 

```powershell
Host *.casd.fr
    User                        $env:USERNAME
    GSSAPIAuthentication        yes
    GSSAPIDelegateCredentials   yes
    PreferredAuthentications    gssapi-with-mic
```

This config allows user to do the below command

```powershell
ssh -K D1MUTUA_P_LIU0000@d1mutua-client.casd.fr
```

To allow users to transfer data between windows and linux, we can use scp command.

```powershell
# for example, transfer a file test.txt, don't forget to replace D1MUTUA_P_LIU0000 by your username
scp -o GSSAPIAuthentication=yes t1.txt D1MUTUA_P_LIU0000@d1mutua-client.casd.fr:/home/D1MUTUA_P_LIU0000/

# for example, transfer a folder, you need to add -r to make the command recursive
scp -o GSSAPIAuthentication=yes -r folder1/ D1MUTUA_P_LIU0000@d1mutua-client.casd.fr:/home/D1MUTUA_P_LIU0000/
```

### 2.1 shortcut

To facilitate user's command, we have developed a script to create shortcut for data transferring. You can find the 
source of the script [gen_win_shortcut.ps1](./scripts/win/gen_win_shortcut.ps1)


## 3. HDFS folder setup

For `D1MUTUA`, we will create two types of folders in hdfs:
- `user home folder`: user personal folder to store private data
- `projet folder`: project data folder shared between all users of the project


### 3.1 Create user home folder

For `D1MUTUA`, we have decided that the root path of the users home folder is `/users/.`. For example, for `user1`, the 
home folder path will be `/users/user1`.



### 3.2 Create project folder

For `D1MUTUA`, we have decided that the root path of the users home folder is `/projects/.`. For example, for `project1`, 
the project folder path will be `/projects/project1`.

The project folder hierarchy is defined in the `D1MUTUA` Windows server file system. The naming convention and 
associated group information is defined in a file. Here we only give an example

```text
# in the `D1MUTUA` Windows server file system, you will see:
V:\
  BES\
    COMMUN
    ENQUETE-URGENCE
    RPU
  BCL\
    COMMUN
    EEC
    OLINPE-PRODUCTION
    PRODUCTION-CSNS

# the corresponding hdfs folder name and associated group will be:
BES_ENQUETE-URGENCE,G_D1_BES_ENQUETE-URGENCE
BES_RPU,G_D1_BES_RPU
BCL_EEC,G_D1_BCL_EEC
BCL_OLINPE-PRODUCTION,G_D1_BCL_OLINPE-PRODUCTION
BCL_PRODUCTION-CSNS,G_D1_BCL_PRODUCTION-CSNS
```

> The groups and group members are defined in AD, the linux server only synchronize these information from AD.

## 4. ACL setup

### 4.1 User home folder acl setup

For now, we have decided the ACL of the user home folder will be 

```text
user::rwx,group::r-x,other::---,mask::r-x,default:user::rwx,default:group::r-x,default:other::---,default:mask::r-x
```

> 1. User is the owner of his home folder which has all the right.
> 2. Group is the admin group which has read and execute right
> 3. Other has 0 right
> The mask defines the max right of group and other which the owner can set up.
> 
### 4.2 Project folder acl setup

For now, we have decided the ACL of the project folder will be

```text
user::rwx,group::rwx,other::---,mask::rwx,default:user::rwx,default:group::rwx,default:other::---,default:mask::rwx
```

>1. The owner of the project folder is the admin user.
>2. The group is a dedicated group of the target project (You can check section 3.2 for example)


## 5 HDFS folder creation Automation

To avoid creating these folder manually, we have created server scripts to automate the process

### 5.1 User home folder creation

For now, we have decided for all users in group `D1MUTUA`, we will create a home folder.

You can use this script [create_hdfs_home_dir.sh](./scripts/lin/create_hdfs_home_dir.sh). 

This script takes three types of argument
- `-n` :  Process a single `AD username`
- `-f` :  Process a list of users from a file (one AD username per line)
- `-g` :  Process all users belonging to a specific `AD group`

```shell

create_home_dir_group.sh [-n username] | [-f filename] | [-g groupname]
  -n  Process a single OS/AD username
  -f  Process a list of users from a file (one username per line)
  -g  Process all users belonging to a specific system/AD group

```

> To run this script, the user must have a valid ticket kerberos and write privilege of `/users` in hdfs.
> A cron job is recommended to run this script on the background.

### 5.2 Project folder creation

For the project folder, as the origin folder hierarchy is in a Windows server. So the first part is to generate the 
folder name and associated groups in the Windows server.

We have developed a Powershell script [gen_projet_dir_group_mapping.ps1](./scripts/win/gen_projet_dir_group_mapping.ps1).

> This script runs inside `D1MUTUA` windows server.
> 
> Before running this script, don't forget to change the `root project path` in the config section. The default value is `V:\`.
> 
> This script generates a csv file without header, it has two columns, 1st column is the `folder name`, 2nd column is the `associated
> group name`


The second part is to create folder in HDFS and setup ACL. You can use this script [create_hdfs_project_dir.sh](./scripts/lin/create_hdfs_project_dir.sh)

This script takes two types of argument:
- `Single project mode`: create_hdfs_project_dir.sh -p <project_name> -g <group_name>
- `Batch Mode`    : create_hdfs_project_dir.sh -f <csv_file>     

> For batch mode, the input csv file should be generated by the first script `gen_projet_dir_group_mapping.ps1`. The 
> csv file format should be project,group without header
> 
> 
## 6. Running a jupyter server

For now, we have not been able to run hdfs client with kerberos on windows, so we launch a jupyter lab server on linux
for user to do inactive pyspark job.

To avoid port conflict, we have developed a script [launch_jupyter.bash](./scripts/lin/launch_jupyter.bash) which detects
available ports and run the jupyter server with the first available port.

We also create a shortcut in /usr/local/bin to run this script with below example


```shell
run_jupyterlab
```

## 7. Admin users in Kerberos enabled hdfs

In a hdfs with kerberos enabled, you can no longer use local account such as `hadoop` or `hdfs` as the root user
to create folders and manage permissions. Because all user account must have one krb ticket valid to access
the hdfs cluster.

The best solution is to use `superusergroup`

Add or ensure the below config is inside the `hdfs-site.xml` file. This property means all users in this
group will have admin rights in the hdfs cluster. If the user has the krb ticket, then he can act as an 
admin user.

```xml
<property>
  <name>dfs.permissions.superusergroup</name>
  <value>hadoop</value>
</property>
```
This group can be local or in AD. If this group is a local group, you need to add this group to the user account
on all nodes of the cluster(e.g. namenode and datanodes).

```shell
# for example, pliu-ad
sudo usermod -aG hadoop pliu-ad

# to remove a group from user account
sudo gpasswd -d pliu-ad hadoop
```

> The user account `pliu-ad` must have valid kerberos ticket


