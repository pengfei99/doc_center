# HDFS folder files management

By default, hdfs has zero files and folders create by default. So as an admin user, you need to provide a 
folder management policy.

## Kerberos enabled hdfs

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