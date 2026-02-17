# Production ready logging system

## 1. Create log dir

```shell
# log dir layout
/var/log/hadoop/
├── hdfs/
├── yarn/
├── mapred/
└── containers/

mkdir -p /var/log/hadoop/{hdfs,yarn,mapred,containers}
chown -R hadoop:hadoop /var/log/hadoop
chmod -R 750 /var/log/hadoop
```

## 2. Config hadoop to use the new log dir

Edit `hadoop-env.sh`, and put the below lines

```shell
export HADOOP_LOG_DIR=/var/log/hadoop
export HADOOP_PID_DIR=/var/run/hadoop
```

Edit `yarn-env.sh`, 

```shell
export YARN_LOG_DIR=/var/log/hadoop/yarn
export YARN_PID_DIR=/var/run/hadoop
```

> You need to restart the cluster to enable the new conf
> 
> 

## 3. Configure log4j2 rotation

```shell
sudo vim $HADOOP_HOME/etc/hadoop/log4j2.properties

# add the below lines
appender.rolling.type = RollingFile
appender.rolling.name = RollingFile
appender.rolling.fileName = ${sys:hadoop.log.dir}/${sys:hadoop.log.file}
appender.rolling.filePattern = ${sys:hadoop.log.dir}/${sys:hadoop.log.file}.%d{yyyy-MM-dd}.%i.gz

appender.rolling.policies.type = Policies
appender.rolling.policies.time.type = TimeBasedTriggeringPolicy
appender.rolling.policies.time.interval = 1
appender.rolling.policies.size.type = SizeBasedTriggeringPolicy
appender.rolling.policies.size.size = 256MB

appender.rolling.strategy.type = DefaultRolloverStrategy
appender.rolling.strategy.max = 30

```

## 4. Customize log levels
The log level is still defined in `$HADOOP_HOME/etc/hadoop/log4j2.properties`

```shell
# set global level to info
rootLogger.level = info

# reduce spam for non critical services
logger.ipc.name = org.apache.hadoop.ipc
logger.ipc.level = warn

logger.security.name = org.apache.hadoop.security
logger.security.level = warn

logger.jetty.name = org.eclipse.jetty
logger.jetty.level = warn


```

## 5. Separate container logs (YARN)

Container logs can explode in size. So we can't keep them for long time. In general, we only keep container logs for 
1 week. To allow end users to visualize these logs, we need to put them into HDFS. 

Edit yarn-site.xml:

```shell
<property>
  <name>yarn.nodemanager.log-dirs</name>
  <value>/var/log/hadoop/containers</value>
</property>

<property>
  <name>yarn.log-aggregation-enable</name>
  <value>true</value>
</property>

<property>
  <name>yarn.log-aggregation.retain-seconds</name>
  <value>604800</value> <!-- 7 days -->
</property>

```

## 6. Create an OS-level safety net (logrotate)

To avoid log4j fails causes log file explosion. We can setup system level log rotation.

Edit `/etc/logrotate.d/hadoop`

```text
/var/log/hadoop/**/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
```

## 7. warning daemon

```shell
df -h /var/log
du -sh /var/log/hadoop/*
```

> Logs must never exceed 20% of disk. If they do, increase rotation frequency or retention limits.
> 
Create a daemon

```shell
sudo vim /usr/local/bin/hadoop-log-check.sh

#!/bin/bash

THRESHOLD=80
LOG_PATH="/var/log/hadoop"

USAGE=$(df -P "$LOG_PATH" | awk 'NR==2 {print $5}' | tr -d '%')

if [ "$USAGE" -ge "$THRESHOLD" ]; then
    echo "ALERT: Hadoop log disk usage at ${USAGE}% on $(hostname)" \
        | logger -p daemon.alert
fi

chmod +x /usr/local/bin/hadoop-log-check.sh

```