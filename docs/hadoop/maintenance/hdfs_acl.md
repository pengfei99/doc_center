# hdfs acl

In this tutorial, we will learn how to work with hdfs and user acls.

Prerequisites: Enabling ACLs
HDFS ACLs are often disabled by default to save NameNode memory. You must enable them in your configuration.

Edit file: `/etc/hadoop/conf/hdfs-site.xml`. 

```xml
<property>
  <name>dfs.namenode.acls.enabled</name>
  <value>true</value>
</property>
```


## The ACL Architecture

HDFS ACLs consist of two distinct types of entries.

- **Access ACLs**: These define the permissions for a specific file or directory. They are immediate.
- **Default ACLs**: These are defined only on directories. They do not affect the directory itself, but act as a template. 
                    Any new file or subdirectory created inside will automatically inherit these permissions.

## The core command for managing ACL

```shell
# view acl of a folder or file
hdfs dfs -getfacl /DREES

# the basic commands is chmod, but this command only allows use to manage primary user and group
hdfs dfs -chmod <acl_spec> <path>

# set acl allows you to add extra users and groups of a folder or file.
# The below line is the general form
# -R means recursive
hdfs dfs -setfacl [-R] [-m|-x|-b|-k] <acl_spec> <path>

# some examples 
# We want the team_a_leads group to have full access, while team_a_interns only has read access.
hdfs dfs -setfacl -m group:team_a_leads:rwx DREES/projects/projetA
hdfs dfs -setfacl -m group:team_a_interns:r-x DREES/projects/projetB

# remove a user from the file's acl
hdfs dfs -setfacl -x user:bob /path

# remove a group form the file's acl
hdfs dfs -setfacl -x group:marketing /path
```

| Option | Action         | Description                                       |
|--------|----------------|---------------------------------------------------|
| -m     | Modify         | Adds new entries or updates existing ones.        |
| -x     | Remove         | Removes specific entries (e.g., a specific user). |
| -b     | Remove All     | Strips all ACLs, reverting to basic POSIX.        |
| -k     | Remove Default | Removes only the Default ACLs.                    |
| -R     | Recursive      | Applies changes to the entire directory tree.     |

## The Mask: The Safety Mechanism

`The Mask defines the maximum permissions allowed for all non-owner entries` (named users and all groups). If you 
set a user to rwx but the mask is r--, the user’s effective permission is r--. The logic follows a bitwise 
AND operation:`P_effective = P_acl_entry and P_mask`. To update a mask to be more restrictive
```shell
hdfs dfs -setfacl -m mask::r-- /projects/team_a

```

> The mask defines the maximum permissions for all named users and groups. It does not restrict others

## Best Practices for Administrators
- Prefer Groups over Users: Never assign ACLs to individual usernames if possible. Manage access via LDAP/Active
                       Directory groups synced to Debian.

- Monitor NameNode Heap: `Every ACL entry consumes roughly 40 bytes of memory on the NameNode`. In a cluster with 
              millions of files, excessive ACLs can cause Out-Of-Memory (OOM) errors.

- Use the Sticky Bit: Always combine ACLs with the Sticky Bit (chmod +t) on shared directories to prevent users from deleting each other's work.

- Audit Regularly: Use the script I provided previously to find directories that have drifted from the standard.

## Limits

- There is a hard limit on the number of ACL entries per file (typically 32 entries).
##  Troubleshooting Common Issues

- `Permission Denied (despite ACL)`: Check the parent directory permissions. A user needs +x (execute) on every parent 
 directory in the path to reach the target folder.

- `Default ACLs not applying`: Default ACLs only apply to new objects. To fix existing objects, you must run the command with the -R (recursive) flag.


## Enable append support
Before you can append, HDFS must be configured to allow it. If this isn't set, your command will fail with a RemoteException.

File: `/etc/hadoop/conf/hdfs-site.xml` Ensure this property is set to true:

```xml
<property>
  <name>dfs.support.append</name>
  <value>true</value>
</property>

```

```shell
hdfs dfs -appendToFile /tmp/local_updates.log /data/finance/audit_log.csv

echo "$(date): Health check passed" | hdfs dfs -appendToFile - /data/monitoring/status.log
```
## A working scenario

I have two teams:
- DREES
- DARES
They both work on a hdfs cluster, but we don't want them to exchange data between them

```shell
hdfs dfs -chown hadoop:drees /DREES
hdfs dfs -chown hadoop:dares /DARES

hdfs dfs -chmod 770 /DREES
hdfs dfs -chmod 770 /DARES

# set default acl to ensure drees has full access, but others have zero access
hdfs dfs -setfacl -m default:group:drees:rwx /DREES
hdfs dfs -setfacl -m default:group:drees:--- /DREES

# set a cross team auditor
hdfs dfs -setfacl -m user:pliu:rwx /DREES

# the raw data folder, we set a sticky bit to avoid delete even with write access
hdfs dfs -chmod 1770 /DREES/data/share
```