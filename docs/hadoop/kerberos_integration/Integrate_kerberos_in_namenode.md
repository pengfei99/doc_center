# Integrate kerberos in name node
In this tutorial, we will show how to integrate kerberos into the hadoop cluster.

## Pre-requis hadoop cluster
We suppose the cluster has three nodes:
- namenode: 10.50.5.203 deb13-spark1
- datanode: 10.50.5.204 deb13-spark2
- datanode: 10.50.5.205 deb13-spark3

### set server hostname
The server hostname is very important if you want to use kerberos, it will be used by the KDC server to authenticate
the server.

To set the hostname on each server, you can use below command
```shell
# the general form is 
sudo hostnamectl set-hostname <new-hostname>

# in our case
sudo hostnamectl set-hostname deb13-spark1

# set the value for /etc/hosts
vim /etc/hosts
# remove the default host config if there are any, it may cause the datanode unable to connect to the namenode 
127.0.0.1 localhost

# add the below lines
10.50.6.203	    deb13-spark1.casdds.casd	deb13-spark1
10.50.6.204     deb13-spark2.casdds.casd    deb13-spark2
10.50.6.205     deb13-spark3.casdds.casd    deb13-spark3

# test the hostname, run below command on each server
hostname 

# test the connectivity, run below command on each server
ping deb13-spark1.casdds.casd
```

### change dns setting

As we will use AD as our dns, so we need to change the dns setting too. Suppose the AD runs at 10.50.5.64.
You need to configure `/etc/resolv.conf` as below.
```shell
sudo vim /etc/resolv.conf

# add below lines
nameserver 10.50.5.64
# google dns for internet
nameserver 8.8.8.8
```
## Pre-requis DNS

As we use DNS(AD) as our DNS, we need to create the `dns forward lookup entries` and the `reverse lookup entries(PTR)`

The below figure shows the DNS config interface:
![ad_dns_example.png](../../assets/ad_dns_example.png)

The below figure shows the `dns forward lookup entries` example:
![ad_forward_lookup_host.png](../../assets/ad_forward_lookup_host.png)

The below figure shows the `reverse lookup entries` example:
![ad_reverse_lookup.png](../../assets/ad_reverse_lookup.png)


> The objective of this step is to make the three server recognizable by the AD, and KDC.

## Pre-requis AD

Account creation in AD is essential for KDC to generate the `right ticket kerberos` for the `right host` with right `SPN(service 
principal name)`

### Service Principal Name definition
In the kerberos best practice, each service should have its own SPN. For the namenode, we should have at least three
Service Principals  
- host/master1.exemple.com@EXEMPLE.COM
- hdfs/master1.exemple.com@EXEMPLE.COM      # HDFS NameNode/DataNode & YARN ResourceManager
- HTTP/master1.exemple.com@EXEMPLE.COM      # Web UI HTTPS

> These SPN can be individual accounts in AD, or multiple SPNs in one gMSA account.
> 
### Keytab file configuration


```shell
/etc/krb5.keytab                    # Principal Kerberos système
```

### Configuration SSL/TLS (Encryption) between nodes in hadoop cluster

Step1. Generation of keystore

```shell
# generate a keystore JKS with auto sign certificate
sudo keytool -genkeypair \
  -alias hadoop \
  -keyalg RSA \
  -keysize 2048 \
  -validity 365 \
  -keystore /opt/hadoop/keystore.jks \
  -storepass changeit
```

Step2. Configure `ssl-server.xml`
```xml
<configuration>
  <property>
    <name>ssl.server.keystore.location</name>
    <value>/opt/hadoop/keystore.jks</value>
  </property>
  <property>
    <name>ssl.server.keystore.password</name>
    <value>changeit</value>
  </property>
  <property>
    <name>ssl.server.keystore.keypassword</name>
    <value>changeit</value>
  </property>
  <property>
    <name>ssl.server.keystore.type</name>
    <value>jks</value>
    <description>(Optionnel) Format du keystore (par défaut « jks »).</description>
  </property>
  <property>
    <name>ssl.server.exclude.cipher.list</name>
    <value>
      TLS_ECDHE_RSA_WITH_RC4_128_SHA,
      SSL_DHE_RSA_EXPORT_WITH_DES40_CBC_SHA,
      SSL_RSA_WITH_DES_CBC_SHA,
      SSL_DHE_RSA_WITH_DES_CBC_SHA,
      SSL_RSA_EXPORT_WITH_RC4_40_MD5,
      SSL_RSA_EXPORT_WITH_DES40_CBC_SHA,
      SSL_RSA_WITH_RC4_128_MD5
    </value>
    <description>(Optionnel) Liste des suites de chiffrement faibles à exclure.</description>
  </property>
</configuration>

```

## Hadoop configuration with kerberos integration

The blow config files need to be modified to enable kerberos in hdfs and yarn:
- core-site.xml


### core-site.xml with Kerberos

```xml
<configuration>
    <property>
        <name>hadoop.ssl.server.conf</name>
        <value>/path/to/ssl-server.xml</value>
        <description>Points to the configuration file for SSL certificate management (keystores/truststores) for encrypted Web UI traffic.</description>
    </property>

    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://sparkm01.casd.fr:8020</value>
        <description>The primary NameNode URI. Defines the default file system host and port for all HDFS operations.</description>
    </property>

    <property>
        <name>hadoop.security.authentication</name>
        <value>kerberos</value>
        <description>Enables Kerberos authentication. This forces all users and services to provide a valid Kerberos ticket to access the cluster.</description>
    </property>

    <property>
        <name>hadoop.security.authorization</name>
        <value>true</value>
        <description>Enables Service Level Authorization (SLA). This checks if a user is actually allowed to connect to specific services like the NameNode.</description>
    </property>

    <property>
        <name>hadoop.http.authentication.type</name>
        <value>kerberos</value>
        <description>Configures the Hadoop Web UIs (NameNode, DataNode) to use Kerberos (SPNEGO) for browser-based authentication.</description>
    </property>

    <property>
        <name>hadoop.http.authentication.kerberos.principal</name>
        <value>HTTP/sparkm01.casd.fr@CASD.FR</value>
        <description>The Kerberos principal used by the Web Server. Usually starts with HTTP/ followed by the FQDN of the server.</description>
    </property>

    <property>
        <name>hadoop.http.authentication.kerberos.keytab</name>
        <value>/etc/krb5.keytab</value>
        <description>The local path to the keytab file containing the credentials for the HTTP principal. Must be readable by the hdfs user.</description>
    </property>

    <property>
        <name>hadoop.http.filter.initializers</name>
        <value>org.apache.hadoop.security.AuthenticationFilterInitializer</value>
        <description>Initializes the authentication filter for the Web UI, enforcing the Kerberos rules defined above.</description>
    </property>

    <property>
        <name>hadoop.security.auth_to_local</name>
        <value>
            RULE:[2:$1@$0](.*@CASD\.FR)s/@CASD\.FR//
            RULE:[1:$1]
            DEFAULT
        </value>
        <description>Maps Kerberos principals (user@REALM) to local Linux usernames. This rule strips the @CASD.FR suffix from Active Directory accounts.</description>
    </property>

    <property>
        <name>hadoop.security.group.mapping</name>
        <value>org.apache.hadoop.security.ShellBasedUnixGroupsMapping</value>
        <description>Determines how Hadoop resolves a user's group membership. This setting uses the local OS 'groups' command (via SSSD/LDAP).</description>
    </property>

    <property>
        <name>hadoop.proxyuser.hdfs.groups</name>
        <value>*</value>
        <description>Allows the 'hdfs' user to impersonate any user in any group. Required for Spark/Hive to execute jobs as the end-user.</description>
    </property>

    <property>
        <name>hadoop.proxyuser.hdfs.hosts</name>
        <value>*</value>
        <description>Specifies the hosts from which the 'hdfs' user can request impersonation. '*' allows requests from any node in the cluster.</description>
    </property>


    

</configuration>
```

### hdfs-site.xml

```xml

<configuration>
    <property>
        <name>dfs.https.server.keystore.resource</name>
        <value>ssl-server.xml</value>
    </property>

    <property>
        <name>dfs.replication</name>
        <value>2</value>
        <description>Default block replication. Standard for research centers to ensure data durability.</description>
    </property>

    <property>
        <name>dfs.namenode.name.dir</name>
        <value>file:///opt/hadoop/hadoop_tmp/hdfs/namenode</value>
        <description>Local path where NameNode stores the fsimage. Should be separate from data blocks.</description>
    </property>

    <property>
        <name>dfs.datanode.data.dir</name>
        <value>file:///opt/hadoop/hadoop_tmp/hdfs/datanode</value>
        <description>Local path where DataNode stores actual blocks. Must be a different path than the NameNode dir.
        </description>
    </property>

    <property>
        <name>dfs.http.policy</name>
        <value>HTTPS_ONLY</value>
        <description>Forces all Web UI traffic to use SSL/TLS.</description>
    </property>

    <property>
        <name>dfs.https.address</name>
        <value>sparkm01.casd.fr:50470</value>
        <description>url of the Namenode.</description>
    </property>

    <property>
        <name>dfs.block.access.token.enable</name>
        <value>true</value>
        <description>Required for Kerberos. NameNode issues tokens to clients to access DataNodes.
            If "true", access tokens are used as capabilities
            for accessing datanodes. If "false", no access tokens are checked on
            accessing datanodes.
        </description>
    </property>

    <property>
        <name>dfs.namenode.kerberos.principal</name>
        <value>hdfs/sparkm01.casd.fr@CASD.FR</value>
        <description>The principal the NameNode uses to login. _HOST automatically resolves to the FQDN.</description>
    </property>
    <property>
        <name>dfs.namenode.keytab.file</name>
        <value>/etc/krb5.keytab</value>
    </property>

    <property>
        <name>dfs.datanode.kerberos.principal</name>
        <value>dn/_HOST@CASD.FR</value>
    </property>
    <property>
        <name>dfs.datanode.keytab.file</name>
        <value>/etc/security/keytabs/dn.service.keytab</value>
    </property>

    <property>
        <name>dfs.data.transfer.protection</name>
        <value>authentication</value>
        <description>Options: authentication, integrity, or privacy (encryption). 'authentication' is usually enough for
            internal lab networks.
        </description>
    </property>

    <property>
        <name>dfs.encrypt.data.transfer</name>
        <value>true</value>
        <description>Encrypts the actual data packets moving between DataNodes and clients.</description>
    </property>

    <property>
        <name>dfs.permissions.enabled</name>
        <value>true</value>
        <description>If "true", enable permission checking in
            HDFS. If "false", permission checking is turned
            off, but all other behavior is
            unchanged. Switching from one parameter value to the other does
            not change the mode, owner or group of files or
            directories.
        </description>
    </property>

    <property>
        <name>dfs.namenode.handler.count</name>
        <value>100</value>
        <description>Number of server threads for NameNode to handle RPC requests from clients.</description>
    </property>

    <property>
        <name>ipc.server.read.threadpool.size</name>
        <value>5</value>
    </property>
    
    <property>
        <name>dfs.access.time.precision</name>
        <value>0</value>
        <description>The access time for HDFS file is precise upto this
            value.The default value is 1 hour. Setting a value of 0
            disables access times for HDFS.
        </description>
    </property>

    <property>
        <name>dfs.cluster.administrators</name>
        <value>hadoop</value>
        <description>ACL for who all can view the default servlets in the HDFS</description>
    </property>
    <property>
        <name>dfs.permissions.supergroup</name>
        <value>hadoop</value>
        <description>Members of this Linux/AD group can perform any HDFS action (equivalent to root).</description>
    </property>
</configuration>

```

### Configure yarn-site.xml


```xml
<configuration>

  <!-- Enable log aggregation -->
  <property>
    <name>yarn.log-aggregation-enable</name>
    <value>true</value>
  </property>

  <!-- HDFS directory for YARN logs -->
  <property>
    <name>yarn.nodemanager.remote-app-log-dir</name>
    <value>/var/log/hadoop-yarn/apps</value>
  </property>

  <!-- Required for MapReduce & Spark on YARN -->
  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>

  <property>
    <name>yarn.nodemanager.aux-services.mapreduce.shuffle.class</name>
    <value>org.apache.hadoop.mapred.ShuffleHandler</value>
  </property>

  <!-- ResourceManager -->
  <property>
    <name>yarn.resourcemanager.hostname</name>
    <value>sparkm01.casd.fr</value>
  </property>

  <!-- NodeManager resources (per worker) -->
  <property>
    <name>yarn.nodemanager.resource.memory-mb</name>
    <value>14336</value>
  </property>

  <property>
    <name>yarn.nodemanager.resource.cpu-vcores</name>
    <value>8</value>
  </property>

  <!-- Scheduler limits -->
  <property>
    <name>yarn.scheduler.minimum-allocation-mb</name>
    <value>1024</value>
  </property>

  <property>
    <name>yarn.scheduler.maximum-allocation-mb</name>
    <value>8192</value>
  </property>

  <property>
    <name>yarn.scheduler.minimum-allocation-vcores</name>
    <value>1</value>
  </property>

  <property>
    <name>yarn.scheduler.maximum-allocation-vcores</name>
    <value>4</value>
  </property>

  <!-- Kerberos: ResourceManager -->
  <property>
    <name>yarn.resourcemanager.principal</name>
    <value>hdfs/sparkm01@CASD.FR</value>
  </property>

  <property>
    <name>yarn.resourcemanager.keytab</name>
    <value>/etc/krb5.keytab</value>
  </property>

  <!-- Kerberos: NodeManager -->
  <property>
    <name>yarn.nodemanager.principal</name>
    <value>hdfs/sparkw01@CASD.FR</value>
  </property>

  <property>
    <name>yarn.nodemanager.keytab</name>
    <value>/etc/krb5.keytab</value>
  </property>

</configuration>
```

> We don't need timeline service here, because spark does not use timeline service. Unless you use explicitly ATS v1 or v2,

### Configuration of hadoop-env.sh

```shell
# Java
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64

# Run HDFS daemons as hadoop user
export HDFS_NAMENODE_USER=hadoop
export HDFS_DATANODE_USER=hadoop

# Hadoop home
export HADOOP_HOME=/usr/local/hadoop
export HADOOP_SBIN_DIR=${HADOOP_HOME}/sbin

# Hadoop config
export HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop
export HADOOP_OS_TYPE=${HADOOP_OS_TYPE:-$(uname -s)}


# JVM options (base)
export HADOOP_OPTS="${HADOOP_OPTS} -Djava.net.preferIPv4Stack=true"
export HADOOP_OPTS="${HADOOP_OPTS} -Djava.security.krb5.conf=/etc/krb5.conf"

#
# Heap defaults (fallback values)
#
export HADOOP_HEAPSIZE_MIN=1024
export HADOOP_HEAPSIZE_MAX=2048

# Hadoop security logging, to be remove for prod
export HADOOP_SECURITY_LOGGER=INFO,RFAS,console


# NameNode JVM tuning (Java 11 optimized)
export HDFS_NAMENODE_OPTS="
  -Xms2g
  -Xmx2g
  -XX:+UseG1GC
  -XX:MaxGCPauseMillis=500
  -XX:+DisableExplicitGC
  -XX:+ParallelRefProcEnabled
  -XX:InitiatingHeapOccupancyPercent=45
  -XX:MaxMetaspaceSize=256m
  -Xlog:gc*,gc+heap=info:file=/var/log/hadoop/gc-namenode.log:time,uptime:filecount=5,filesize=100m
"

#
# DataNode JVM options (Java 11 safe)
#
export HDFS_DATANODE_OPTS="
  -XX:+UseG1GC
  -XX:MaxGCPauseMillis=500
  -XX:+DisableExplicitGC
  -Dhadoop.security.logger=ERROR,RFAS
"

```