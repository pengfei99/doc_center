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


# set acl of a folder or file in general form
# -R means recursive
hdfs dfs -setfacl [-R] [-m|-x|-b|-k] <acl_spec> <path>

# some examples 
# We want the team_a_leads group to have full access, while team_a_interns only has read access.
hdfs dfs -setfacl -m group:team_a_leads:rwx DREES/projects/projetA
hdfs dfs -setfacl -m group:team_a_interns:r-x DREES/projects/projetB
```

| Option | Action         | Description                                       |
|--------|----------------|---------------------------------------------------|
| -m     | Modify         | Adds new entries or updates existing ones.        |
| -x     | Remove         | Removes specific entries (e.g., a specific user). |
| -b     | Remove All     | Strips all ACLs, reverting to basic POSIX.        |
| -k     | Remove Default | Removes only the Default ACLs.                    |
| -R     | Recursive      | Applies changes to the entire directory tree.     |