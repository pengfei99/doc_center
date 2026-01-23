# Integrate Kerberos in datanode


## Configure DataNode

### 4.1 Connexion au NameNode Master

```xml
<!-- core-site.xml - Worker -->

<configuration>
        <property>
        <name>fs.defaultFS</name>
        <value>hdfs://sparkm01.casd.fr:8020</value>
        <description>The primary NameNode URI. Defines the default file system host and port for all HDFS operations.</description>
    </property>
        <property>
                <name>hadoop.security.authentication</name>
                <value>kerberos</value>
        </property>
         <property>
                <name>hadoop.security.authorization</name>
                <value>true</value>
        </property>
        <property>
                <name>hadoop.ssl.server.conf</name>
                <value>ssl-server.xml</value>
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
</configuration>
```

### 4.2 Configuration DataNode Sécurisé
```xml
<!-- hdfs-site.xml - Worker -->
<configuration>

<!-- In hdfs-site.xml -->
        <property>
                <name>dfs.https.server.keystore.resource</name>
                <value>ssl-server.xml</value>
        </property>
        <property>
                <name>dfs.http.policy</name>
                <value>HTTPS_ONLY</value>
        </property>
        <property>
                <name>dfs.https.port</name>
                <value>50470</value>
        </property>
        <property>
                <name>dfs.data.transfer.protection</name>
                <value>authentication</value>
        </property>
        <property>
                <name>dfs.secondary.https.port</name>
                <value>50490</value>
                <description>The https port where secondary-namenode binds</description>
        </property>
        <property>
                <name>dfs.https.address</name>
                <value>ip-10-50-5-203.casdds.casd:50470</value>
                <description>The https address where namenode binds</description>
        </property>
        <property>
                <name>dfs.encrypt.data.transfer</name>
                <value>true</value>
        </property>
        <property>
                <name>dfs.replication</name>
                <value>3</value>
        </property>
        <property>
                <name>dfs.namenode.name.dir</name>
                <value>file:///opt/hadoop/hadoop_tmp/hdfs/data</value>
        </property>
        <property>
                <name>dfs.datanode.data.dir</name>
                <value>file:///opt/hadoop/hadoop_tmp/hdfs/data</value>
        </property>
        <property>
                <name>dfs.datanode.kerberos.principal</name>
                <value>hdfs/sparkw01.casd.fr@CASDDS.CASD</value>
        </property>
        <property>
                <name>dfs.datanode.keytab.file</name>
                <value>/etc/dn-host-m02.keytab</value>
        </property>
        <property>
                 <name>dfs.namenode.kerberos.principal</name>
                <value>hdfs/spark-m01.casdds.casd@CASDDS.CASD</value>
        </property>
        <property>
                <name>dfs.namenode.keytab.file</name>
                <value>/etc/hdfsm01.keytab</value>
        </property>
        <property>
                <name>dfs.permissions</name>
                <value>true</value>
                <description> If "true", enable permission checking in
                HDFS. If "false", permission checking is turned
                off, but all other behavior is
                unchanged. Switching from one parameter value to the other does
                not change the mode, owner or group of files or
                directories. </description>
        </property>
        <property>
                <name>dfs.permissions.supergroup</name>
                <value>hadoop</value>
                <description>The name of the group of super-users.</description>
        </property>
        <property>
                <name>ipc.server.max.response.size</name>
                <value>5242880</value>
        </property>
        <property>
                <name>dfs.block.access.token.enable</name>
                <value>true</value>
                <description> If "true", access tokens are used as capabilities
                for accessing datanodes. If "false", no access tokens are checked on
                accessing datanodes. </description>
        </property>
        <property>
                <name>dfs.datanode.data.dir.perm</name>
                <value>750</value>
                <description>The permissions that should be there on
                dfs.data.dir directories. The datanode will not come up if the
                permissions are different on existing dfs.data.dir directories. If
                the directories don't exist, they will be created with this
                permission.</description>
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
                <description>ACL for who all can view the default
                servlets in the HDFS</description>
        </property>
        <property>
                <name>ipc.server.read.threadpool.size</name>
                <value>5</value>
        </property>
</configuration>

```

###  5. Configuration 
```xml

<configuration>

    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <property>
        <name>yarn.nodemanager.aux-services.mapreduce.shuffle.class</name>
        <value>org.apache.hadoop.mapred.ShuffleHandler</value>
    </property>
    <property>
        <name>yarn.nodemanager.hostname</name>
        <value>sparkw01.casd.fr</value>
    </property>
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>spark-m01.casdds.casd</value>
    </property>
    <property>
        <name>yarn.nodemanager.resource.cpu-vcores</name>
        <value>4</value>
    </property>
    <property>
        <name>yarn.nodemanager.resource.memory-mb</name>
        <value>2048</value>
    </property>
    <property>
        <name>yarn.scheduler.maximum-allocation-mb</name>
        <value>8192</value>
    </property>
    <property>
        <name>yarn.scheduler.minimum-allocation-mb</name>
        <value>1024</value>
    </property>

    <property>
        <name>yarn.resourcemanager.principal</name>
        <value>yarn/spark-m01.casdds.casd@CASDDS.CASD</value>
    </property>
    <property>
        <name>yarn.resourcemanager.keytab</name>
        <value>/etc/yarnm01.keytab</value>
    </property>

    <property>
        <name>yarn.nodemanager.principal</name>
        <value>yarn/sparkw01.casd.fr@CASDDS.CASD</value>
    </property>
    <property>
        <name>yarn.nodemanager.keytab</name>
        <value>/etc/yarnm02.keytab</value>
    </property>
    <property>
        <name>yarn.timeline-service.http-authentication.type</name>
        <value>kerberos</value>
    </property>
    <property>
        <name>yarn.nodemanager.vmem-check-enabled</name>
        <value>true</value>
    </property>
</configuration>


```

## 6. Configuration Environnement Worker

### 6.1 Variables d'Environnement Worker
```bash

export HDFS_DATANODE_USER=hadoop

export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export JAVA_TOOL_OPTIONS="$JAVA_TOOL_OPTIONS --add-opens=java.base/sun.net.dns=ALL-UNNAMED"

#
# Hadoop configuration directory
#
export HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop
export HADOOP_OS_TYPE=${HADOOP_OS_TYPE:-$(uname -s)}

#
# Hadoop memory settings (worker node)
#
export HADOOP_HEAPSIZE_MIN=1024
export HADOOP_HEAPSIZE_MAX=2048

#
# Base JVM options
#
export HADOOP_OPTS="${HADOOP_OPTS} -Djava.net.preferIPv4Stack=true"
export HADOOP_OPTS="${HADOOP_OPTS} -Djava.security.krb5.conf=/etc/krb5.conf"

#
export HADOOP_SECURITY_LOGGER=INFO,RFAS,console


```
