```shell
Host *
  GSSAPIAuthentication yes
  GSSAPIDelegateCredentials yes
  PasswordAuthentication no
```
yarn-site.xml
```xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <!-- ResourceManager 地址 -->
  <property>
    <name>yarn.resourcemanager.hostname</name>
    <value>nn.example.com</value>
  </property>

  <!-- Web UI 端口（YARN 3.x 默认 8088） -->
  <property>
    <name>yarn.resourcemanager.webapp.address</name>
    <value>nn.example.com:8088</value>
  </property>

  <!-- NodeManager 列表 -->
  <property>
    <name>yarn.resourcemanager.nodes.include-path</name>
    <value>/etc/hadoop/conf/yarn.include</value>
  </property>

  <!-- 启用 Kerberos 安全 -->
  <property>
    <name>yarn.resourcemanager.principal</name>
    <value>yarn/nn.example.com@EXAMPLE.COM</value>
  </property>
  <property>
    <name>yarn.resourcemanager.keytab</name>
    <value>/etc/security/keytabs/yarn.service.keytab</value>
  </property>

  <property>
    <name>yarn.nodemanager.principal</name>
    <value>yarn/_HOST@EXAMPLE.COM</value>
  </property>
  <property>
    <name>yarn.nodemanager.keytab</name>
    <value>/etc/security/keytabs/yarn.service.keytab</value>
  </property>

  <!-- Web UI SPNEGO -->
  <property>
    <name>yarn.webapp.spnego-principal</name>
    <value>HTTP/_HOST@EXAMPLE.COM</value>
  </property>
  <property>
    <name>yarn.webapp.spnego-keytab-file</name>
    <value>/etc/security/keytabs/yarn.service.keytab</value>
  </property>

  <!-- 启用 LinuxContainerExecutor（推荐用于安全集群） -->
  <property>
    <name>yarn.nodemanager.container-executor.class</name>
    <value>org.apache.hadoop.yarn.server.nodemanager.LinuxContainerExecutor</value>
  </property>

  <property>
    <name>yarn.nodemanager.linux-container-executor.group</name>
    <value>hadoop</value>
  </property>

  <!-- 其他常规配置 -->
  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>

  <property>
    <name>yarn.log-aggregation-enable</name>
    <value>true</value>
  </property>
</configuration>


```