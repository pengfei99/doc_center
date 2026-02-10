## Intégration de Kerberos dans un cluster Hadoop

Cette documentation décrit les étapes pour sécuriser l’authentification des composants d’un cluster Hadoop (NameNode, DataNode, ResourceManager, etc.) à l’aide de Kerberos et SSL.


### 1. Contexte et architecture

* **Cluster** : 3 nœuds (spark-m01, spark-m02, spark-m03) dans le domaine **CASDDS.CASD**

  * *spark-m01* : NameNode, ResourceManager, HistoryServer
  * *spark-m02* & *spark-m03* : DataNode, NodeManager

* **But** :

  * Authentification forte via Kerberos
  * Chiffrement des communications via SSL/TLS


### 2. Prérequis

1. **AD/Kerberos**

   * Les serveurs Linux doivent être joints au domaine AD/Kerberos `CASDDS.CASD`
   * Un contrôleur de domaine (KDC + DNS) configuré pour forward/reverse lookup

2. **Logiciels**

   * Java 11 (OpenJDK)
   * Hadoop 3.x
   * Utilitaires Kerberos (`kinit`, `klist`, `ktpass`, `ktutil`)
   * Keytool (Java)


### 3. Configuration Kerberos

#### 3.1. Création des comptes service et keytabs

Pour chaque service, créez un compte AD dédié et générez un fichier `.keytab` :

| Service       | Rôle            | FQDN                  | Principal Kerberos                       | AD User     |
| ------------- | --------------- | --------------------- | ---------------------------------------- | ----------- |
| HDFS NameNode | NameNode        | spark-m01.casdds.casd | `hdfs/spark-m01.casdds.casd@CASDDS.CASD`   | `hdfs-m01`   |
| HDFS DataNode | DataNode        | spark-m02.casdds.casd | `hdfs/spark-m02.casdds.casd@CASDDS.CASD`   | `hdfs-m02`  |
| HDFS DataNode | DataNode        | spark-m03.casdds.casd | `hdfs/spark-m03.casdds.casd@CASDDS.CASD`   | `hdfs-m03`  |
| HTTP          | HTTP Service    | spark-m01.casdds.casd | `HTTP/spark-m01.casdds.casd@CASDDS.CASD` | `http-m01`   |
| YARN RM       | ResourceManager | spark-m01.casdds.casd | `yarn/spark-m01.casdds.casd@CASDDS.CASD`   | `yarn-m01`   |
| YARN NM       | NodeManager     | spark-m0X.casdds.casd | `yarn/spark-m0X.casdds.casd@CASDDS.CASD`   | `yarn-m0x`  |
| HOST          | Host principal  | spark-m0X.casdds.casd | `host/spark-m0X.casdds.casd@CASDDS.CASD` | `host-m0X` |

*Commande Windows (AD) :*

```powershell
New-ADUser -Name "hdfs-m01" -SamAccountName "hdfs-m01" \
  -UserPrincipalName "hdfs/spark-m01.casdds.casd@CASDDS.CASD" \
  -Enabled $true -PasswordNeverExpires $true -CannotChangePassword $true

ktpass -princ hdfs/spark-m01.casdds.casd@CASDDS.CASD \
  -mapuser hdfs-m01 -crypto ALL -ptype KRB5_NT_PRINCIPAL \
  -pass "Password!" -out hdfs-m01.keytab

scp hdfs-m01.keytab user@spark-m0x.casdds.casd:/tmp/

```

> Copiez chaque keytab sous `/etc/` sur le serveur correspondant, avec permissions `root:hadoop`, `chmod 640`.


#### 3.2. Vérification des keytabs

```bash
# Authentication sans mot de passe
kinit -kt /etc/hdfs-m01.keytab hdfs/spark-m01.casdds.casd@CASDDS.CASD
# Afficher tickets
klist
# Lister contenu d'un keytab
klist -e -k -t /etc/hdfs-m01.keytab
```

#### 3.3. Fusion de plusieurs keytabs

```bash
sudo ktutil
rkt /tmp/yarn-m02.keytab
rkt /tmp/host-m02.keytab
wkt /etc/merged.keytab
q
sudo klist -k /etc/merged.keytab
```


### 4. Configuration du client Kerberos (/etc/krb5.conf)

```ini
[libdefaults]
  default_realm = CASDDS.CASD
  default_tkt_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96
  default_tgs_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96
  permitted_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96
  kdc_timesync = 1
  ticket_lifetime = 24h
  forwardable = true
  dns_lookup_realm = true
  dns_lookup_kdc = true
  rdns = false
  #allow_weak_crypto = true

[realms]
  CASDDS.CASD = {
    kdc = @ip
    admin_server = @ip
  }

[domain_realm]
  .casdds.casd = CASDDS.CASD
  casdds.casd = CASDDS.CASD
```

> Décommentez `allow_weak_crypto = true` si nécessaire pour RC4.


### 5. Sécurisation SSL/TLS

#### 5.1. Génération du keystore Java

```bash
sudo keytool -genkeypair \
  -alias hadoop -keyalg RSA -keysize 2048 -validity 365 \
  -keystore /opt/hadoop/keystore.jks -storepass changeit
sudo keytool -list -keystore /opt/hadoop/keystore.jks -storepass changeit
sudo keytool -export -alias hadoop \
  -file /opt/hadoop/hadoop-cert.pem -keystore /opt/hadoop/keystore.jks \
  -storepass changeit
```

#### 5.2. Configuration `ssl-server.xml`

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
        <description>Optional. The keystore file format, default value is "jks".</description>
    </property>
    <property>
        <name>ssl.server.exclude.cipher.list</name>
        <value>TLS_ECDHE_RSA_WITH_RC4_128_SHA,SSL_DHE_RSA_EXPORT_WITH_DES40_CBC_SHA,
        SSL_RSA_WITH_DES_CBC_SHA,SSL_DHE_RSA_WITH_DES_CBC_SHA,
        SSL_RSA_EXPORT_WITH_RC4_40_MD5,SSL_RSA_EXPORT_WITH_DES40_CBC_SHA,
        SSL_RSA_WITH_RC4_128_MD5</value>
        <description>Optional. The weak security cipher suites that you want excludedfrom SSL communication.</description>
    </property>
</configuration>
```

> Répétez l’opération sur tous les nœuds.


### 6. Configuration Hadoop

#### 6.1. `hadoop-env.sh`

```bash
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export HADOOP_OPTS="-Djava.net.preferIPv4Stack=true -Djava.security.debug=gssloginconfig,configfile,configparser,logincontext"
export HADOOP_OPTS="-Djava.security.krb5.conf=/etc/krb5.conf $HADOOP_OPTS"
export HDFS_NAMENODE_USER=hadoop
export HDFS_DATANODE_USER=hadoop
export HDFS_SECONDARYNAMENODE_USER=hadoop
export JSVC_HOME=$(dirname $(which jsvc))
export HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop
export HADOOP_SECURITY_LOGGER=INFO,RFAS,console
export JAVA_TOOL_OPTIONS="$JAVA_TOOL_OPTIONS --add-opens=java.base/sun.net.dns=ALL-UNNAMED"
```

#### 6.2. Politiques de sécurité Java

```properties
# $JAVA_HOME/conf/security/java.security
crypto.policy = unlimited
sun.security.krb5.disableReferrals = true
# Retirer RC4 de jdk.jar.disabledAlgorithms / jdk.tls.disabledAlgorithms si besoin
```

#### 6.3. Configuration des services

##### 6.3.1. NameNode (`core-site.xml`, `hdfs-site.xml`, `yarn-site.xml`)

```xml
<!-- core-site.xml -->
<configuration>
  <property>
    <name>hadoop.ssl.server.conf</name>
    <value>/opt/hadoop/etc/hadoop/ssl-server.xml</value>
  </property>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://spark-m01.casdds.casd:9000</value>
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
        <name>hadoop.security.group.mapping</name>
        <value>org.apache.hadoop.security.ShellBasedUnixGroupsMapping</value>
    </property>
  <property>
    <name>hadoop.http.authentication.type</name>
    <value>kerberos</value>
  </property>
  <property>
    <name>hadoop.http.authentication.kerberos.principal</name>
    <value>HTTP/spark-m01.casdds.casd@CASDDS.CASD</value>
  </property>
  <property>
    <name>hadoop.http.authentication.kerberos.keytab</name>
    <value>/etc/http-m01.keytab</value>
  </property>
  <property>
    <name>hadoop.http.filter.initializers</name>
    <value>org.apache.hadoop.security.AuthenticationFilterInitializer</value>
  </property>
  <property>
    <name>hadoop.security.auth_to_local</name>
    <value>
      RULE:[2:$1@$0](.*@casdds\.casd)s/@casdds\.casd//
      RULE:[1:$1]
      DEFAULT
    </value>
    <description>Mapping du principal Kerberos vers le nom d’utilisateur local.</description>
  </property>
</configuration>
<!-- hdfs-site.xml -->
<configuration>
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
    <description>Port HTTPS pour le secondary-namenode.</description>
  </property>
  <property>
    <name>dfs.https.address</name>
    <value>spark-m01.casdds.casd:50470</value>
    <description>Adresse HTTPS d’écoute du Namenode.</description>
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
    <name>dfs.permissions</name>
    <value>true</value>
    <description>Activation de la vérification des permissions sur HDFS.</description>
  </property>
  <property>
    <name>dfs.namenode.handler.count</name>
    <value>100</value>
    <description>Augmentation de la file d’attente pour gérer davantage de connexions clients.</description>
  </property>
  <property>
    <name>ipc.server.max.response.size</name>
    <value>5242880</value>
  </property>
  <property>
    <name>dfs.permissions.supergroup</name>
    <value>hadoop</value>
    <description>Nom du groupe des super-utilisateurs.</description>
  </property>
  <property>
    <name>dfs.cluster.administrators</name>
    <value>hadoop</value>
    <description>ACL pour l’accès aux servlets par défaut de HDFS.</description>
  </property>
  <property>
    <name>dfs.access.time.precision</name>
    <value>0</value>
    <description>Désactivation de la mise à jour des temps d’accès pour les fichiers HDFS.</description>
  </property>
  <property>
    <name>dfs.block.access.token.enable</name>
    <value>true</value>
    <description>Activation des tokens d’accès pour sécuriser l’accès aux datanodes.</description>
  </property>
  <property>
    <name>ipc.server.read.threadpool.size</name>
    <value>5</value>
  </property>
  <property>
    <name>dfs.namenode.http-address</name>
    <value>spark-m01.casdds.casd:9870</value>
  </property>
  <property>
    <name>dfs.namenode.kerberos.principal</name>
    <value>hdfs/spark-m01.casdds.casd@CASDDS.CASD</value>
  </property>
  <property>
    <name>dfs.namenode.keytab.file</name>
    <value>/etc/hdfs-m01.keytab</value>
  </property>
  <property>
    <name>dfs.secondary.namenode.kerberos.principal</name>
    <value>hdfs/spark-m01.casdds.casd@CASDDS.CASD</value>
  </property>
  <property>
    <name>dfs.secondary.namenode.keytab.file</name>
    <value>/etc/hdfs-m01.keytab</value>
  </property>
  <property>
    <name>dfs.permissions.enabled</name>
    <value>true</value>
  </property>
</configuration>
<!-- yarn-site.xml -->
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
    <name>yarn.resourcemanager.hostname</name>
    <value>spark-m01.casdds.casd</value>
  </property>
  <property>
    <name>yarn.nodemanager.resource.cpu-vcores</name>
    <value>2</value>
  </property>
  <property>
    <name>yarn.nodemanager.resource.memory-mb</name>
    <value>2048</value>
  </property>
  <property>
    <name>yarn.scheduler.maximum-allocation-mb</name>
    <value>2048</value>
  </property>
  <property>
    <name>yarn.scheduler.minimum-allocation-mb</name>
    <value>512</value>
  </property>
  <property>
    <name>yarn.resourcemanager.principal</name>
    <value>yarn/spark-m01.casdds.casd@CASDDS.CASD</value>
  </property>
  <property>
    <name>yarn.resourcemanager.keytab</name>
    <value>/etc/yarn-m01.keytab</value>
  </property>
  <property>
    <name>yarn.timeline-service.principal</name>
    <value>yarn/spark-m01.casdds.casd@CASDDS.CASD</value>
  </property>
  <property>
    <name>yarn.timeline-service.keytab</name>
    <value>/etc/yarn-m01.keytab</value>
  </property>
</configuration>
```

##### 6.3.2. DataNode (`core-site.xml`, `hdfs-site.xml`, `yarn-site.xml`)

```xml
<!-- core-site.xml -->
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://spark-m01.casdds.casd:9000</value>
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
      RULE:[2:$1@$0](.*@CASDDS\.CASD)s/@CASDDS\.CASD//
      RULE:[1:$1]
      DEFAULT
    </value>
    <description>Mapping du principal Kerberos vers l’utilisateur local.</description>
  </property>
</configuration>
<!-- hdfs-site.xml -->
<configuration>
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
    <description>Port HTTPS pour le secondary-namenode.</description>
  </property>
  <property>
    <name>dfs.https.address</name>
    <value>ip-x.x.x.x.casdds.casd:50470</value>  <!-- @ip namdenode -->
    <description>Adresse HTTPS d’écoute du Namenode sur le DataNode.</description>
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
    <value>hdfs/spark-m0x.casdds.casd@CASDDS.CASD</value>
  </property>
  <property>
    <name>dfs.datanode.keytab.file</name>
    <value>/etc/hdfs-m0x.keytab</value>
  </property>
  <property>
    <name>dfs.namenode.kerberos.principal</name>
    <value>hdfs/spark-m01.casdds.casd@CASDDS.CASD</value>
  </property>
  <property>
    <name>dfs.namenode.keytab.file</name>
    <value>/etc/hdfs-m01.keytab</value>
  </property>
  <property>
    <name>dfs.permissions</name>
    <value>true</value>
    <description>Activation de la vérification des permissions sur HDFS.</description>
  </property>
  <property>
    <name>dfs.permissions.supergroup</name>
    <value>hadoop</value>
    <description>Nom du groupe des super-utilisateurs.</description>
  </property>
  <property>
    <name>ipc.server.max.response.size</name>
    <value>5242880</value>
  </property>
  <property>
    <name>dfs.block.access.token.enable</name>
    <value>true</value>
    <description>Activation des tokens d’accès pour l’accès aux datanodes.</description>
  </property>
  <property>
    <name>dfs.datanode.data.dir.perm</name>
    <value>750</value>
    <description>Permissions requises sur les répertoires de données.</description>
  </property>
  <property>
    <name>dfs.access.time.precision</name>
    <value>0</value>
    <description>Désactivation de la mise à jour des temps d’accès pour les fichiers HDFS.</description>
  </property>
  <property>
    <name>dfs.cluster.administrators</name>
    <value>hadoop</value>
    <description>ACL pour l’accès aux servlets par défaut de HDFS.</description>
  </property>
  <property>
    <name>ipc.server.read.threadpool.size</name>
    <value>5</value>
  </property>
</configuration>
<!-- yarn-site.xml -->
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
    <value>spark-m0x.casdds.casd</value>
  </property>
  <property>
    <name>yarn.resourcemanager.hostname</name>
    <value>spark-m01.casdds.casd</value>
  </property>
  <property>
    <name>yarn.nodemanager.resource.cpu-vcores</name>
    <value>2</value>
  </property>
  <property>
    <name>yarn.nodemanager.resource.memory-mb</name>
    <value>2048</value>
  </property>
  <property>
    <name>yarn.scheduler.maximum-allocation-mb</name>
    <value>2048</value>
  </property>
  <property>
    <name>yarn.scheduler.minimum-allocation-mb</name>
    <value>512</value>
  </property>
  <property>
    <name>yarn.resourcemanager.principal</name>
    <value>yarn/spark-m01.casdds.casd@CASDDS.CASD</value>
  </property>
  <property>
    <name>yarn.resourcemanager.keytab</name>
    <value>/etc/yarn-m01.keytab</value>
  </property>
  <property>
    <name>yarn.timeline-service.principal</name>
    <value>yarn/spark-m0x.casdds.casd@CASDDS.CASD</value>
  </property>
  <property>
    <name>yarn.timeline-service.keytab</name>
    <value>/etc/yarn-m0x.keytab</value>
  </property>
  <property>
    <name>yarn.nodemanager.principal</name>
    <value>yarn/spark-m0x.casdds.casd@CASDDS.CASD</value>
  </property>
  <property>
    <name>yarn.nodemanager.keytab</name>
    <value>/etc/yarn-m0x.keytab</value>
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


### 7. Validation et tests

1. **Tester kinit** sur chaque nœud/service
2. **Démarrer Hadoop** en mode sécurisé 
3. **Vérifier** que les services écoutent en HTTPS et que `klist` montre les tickets actifs
4. **Rafraîchir** les mappings utilisateurs-groupes :

   ```bash
   hdfs dfsadmin -refreshUserToGroupsMappings
   ```


### 8. Références

* [https://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-common/SecureMode.html](https://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-common/SecureMode.html)

* [http://docs.cloudera.com.s3-website-us-east-1.amazonaws.com/HDPDocuments/HDP3/HDP-3.1.5/security-reference/content/kerberos_nonambari_adding_security_information_to_configuration_files.html](http://docs.cloudera.com.s3-website-us-east-1.amazonaws.com/HDPDocuments/HDP3/HDP-3.1.5/security-reference/content/kerberos_nonambari_adding_security_information_to_configuration_files.html)

### 9. Repo Ansible 

* [https://github.com/CASD-EU/admin_sys/tree/test/dev/roles](https://github.com/CASD-EU/admin_sys/tree/test/dev/roles)
