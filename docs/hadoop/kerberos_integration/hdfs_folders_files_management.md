# HDFS folder files management

By default, hdfs has zero files and folders create by default. So as an admin user, you need to provide a 
folder management policy.

## Admin users in Kerberos enabled hdfs

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
usermod -aG hadoop pliu-ad
```

## Home folders for users

In this section, we show how to create a personal folders for all logon users. 

The root folder is `/users`. Each user has it's individual folder such as `/users/<user-name>`
The access control policies of `/users` are :
1. owner and group: hadoop:hadoop
2. acl is: 755
3. default owner and group for subfolder is: hadoop:hadoop
4. default acl for subfolder is 750
> only admin user can create file and folders under /users
> All users can list and navigate under /users

The access control policies of `/users/<user-name>` are :
1. owner and group must be: <user-name>:hadoop
2. acl is: 750
> User can read/write/execute. 
> Other have --- right. even the owner change acl to 777. 
> 

The below commands can create and set up the `/users`
```shell
# Set ownership to the admin
hdfs dfs -chown hadoop:hadoop /users

# Set permissions to rwxr-xr-x
hdfs dfs -chmod 755 /users

# Set the default ACLs for the /users directory
hdfs dfs -setfacl -m "default:user::rwx,default:group::r-x,default:other::---" /users
```

The below script can create user folders

```shell
USER_NAME="alice"
hdfs dfs -mkdir -p /users/$USER_NAME
hdfs dfs -chown $USER_NAME:hadoop /users/$USER_NAME
hdfs dfs -chmod 750 /users/$USER_NAME
hdfs dfs -setfacl -m "user::rwx,group::r-x,other::---,mask::r-x,default:user::rwx,default:group::r-x,default:other::---" /users/$USER_NAME
```


You can check the created folder acl with the below command

```shell
hdfs dfs -getfacl /users/$USER_NAME
```