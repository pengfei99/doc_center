# Production ready logging system

## 1. Create log dir

```shell
# log dir layout
/var/log/hadoop/
├── hdfs/
├── yarn/
├── mapred/
└── containers/

# create folder for log
mkdir -p /var/log/hadoop/{hdfs,yarn,mapred,containers}
chown -R hadoop:hadoop /var/log/hadoop
chmod -R 750 /var/log/hadoop

# creat folder for pid
sudo mkdir -p /var/run/hadoop
sudo chown hadoop:hadoop /var/run/hadoop
sudo chmod 755 /var/run/hadoop
```

## 2. Config hadoop to use the new log dir

Edit `hadoop-env.sh`, and put the below lines

```shell
export HADOOP_LOG_DIR=/var/log/hadoop
export HADOOP_PID_DIR=/var/run/hadoop
```

> In hadoop 3.3.6, `YARN_LOG_DIR` and `YARN_PID_DIR` are deprecated, just use  `HADOOP_LOG_DIR` and `HADOOP_PID_DIR`
> for all hadoop daemons

```shell
# if you have old env var, you can remove them 
unset YARN_LOG_DIR
unset YARN_PID_DIR
```

> You need to restart the cluster to enable the new conf
> 
> 

## 3. Configure hadoop log behaviors

To optimize the hadoop log behaviors, we want to do three things
- log rotation to avoid big log file
- change log level of certain services to reduce spam for `non critical` services
- redirect container log to another dir, because it will be written with the end user right.

You can edit the log4j conf file with the below command
```shell
sudo vim $HADOOP_HOME/etc/hadoop/log4j2.properties
```

### 3.1 Configure log4j2 rotation

In the below config, we define two `rolling policies`:
- `TimeBasedTriggeringPolicy`: rotate log file every day 
- `SizeBasedTriggeringPolicy`: rotate log file if the file size is greater than 128MB

Below is the rotation config ane comments

```shell
# This declares the list of all appenders available in the configuration.
# Multiple values must be comma-separated.
appenders = rolling

### Defines the properties of rolling appender
# define the type of rolling appender. In this example we use `RollingFile`
# `RollingFile` is a Log4j2 appender that writes logs to a file and automatically "rolls over"
appender.rolling.type = RollingFile
# define the name
appender.rolling.name = RollingFile
# Specifies the base filename for the active log file.
appender.rolling.fileName = ${sys:hadoop.log.dir}/${sys:hadoop.log.file}
# Defines the pattern for archived (rolled-over) log files. %d{yyyy-MM-dd} appends the date,
# %i adds an incrementing integer for multiple rolls per day (e.g., if size triggers),
# and .gz enables gzip compression.
# This results in files like yarn-nodemanager.log.2026-02-18.1.gz
appender.rolling.filePattern = ${sys:hadoop.log.dir}/${sys:hadoop.log.file}.%d{yyyy-MM-dd}.%i.gz

# Specifies the layout type for formatting log messages.
appender.rolling.layout.type = PatternLayout
# Defines the log message format
# %d{yy/MM/dd HH:mm:ss}: Timestamp (e.g., 26/02/18 12:34:56).
# %p: Log level (e.g., INFO, ERROR).
# %c{1}: Logger name (shortened to last component, e.g., NodeManager).
# %m: The actual log message.
# %n: Newline.
# %ex: Exception stack trace (if any).
# This pattern is concise and matches common Hadoop/Spark defaults for readability in cluster logs.
appender.rolling.layout.pattern = %d{yy/MM/dd HH:mm:ss} %-5p %c{1}: %m%n%ex

### Define Rotation policies
appender.rolling.policies.type = Policies

appender.rolling.policies.time.type = TimeBasedTriggeringPolicy
# 1 means roll every 1 day
appender.rolling.policies.time.interval = 1
# Aligns rollovers to calendar boundaries (e.g., exactly at midnight for daily rolls, regardless of when the process started).
# this can avoid arbitrary times based rollovers
appender.rolling.policies.time.modulate = true

# Enables size-based rollover, triggering when the file reaches a certain size
appender.rolling.policies.size.type = SizeBasedTriggeringPolicy
# Sets the maximum size for the active log file before rollover
appender.rolling.policies.size.size = 128MB

### Define log Retention
# Specifies the strategy for managing rolled files.
# The DefaultRolloverStrategy handles file renaming, compression, and deletion of old files.
appender.rolling.strategy.type = DefaultRolloverStrategy
# we only keep the 30 rolled files. 1 month of daily rotated log files.
appender.rolling.strategy.max = 30

```

### 3.2. Customize log levels
To reduce the log spam of `non critical` services, we can reduce their log level to `warn`.
For essential services, we still need to keep level `info`. So the idea is to set the root logger level to
`info`. For `non critical` services, when we identify one, we reduce their log level to `warn`.
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

### 3.3. Separate container logs (YARN)

Container logs can explode in size. So we can't keep them for long time. In general, we only keep container logs for 
1 week. To allow end users to visualize these logs, we need to put them into HDFS. 

Edit :

To specify where nodemanager to write container log, we can use the below property. It must be added to all
`yarn-site.xml` on all data nodes
```xml
<property>
  <name>yarn.nodemanager.log-dirs</name>
  <value>/var/log/hadoop/containers</value>
</property>
```

> This will write the container log on the local disk
> We can also copy these logs to hdfs, to make them more accessible

```xml
<property>
  <name>yarn.log-aggregation-enable</name>
  <value>true</value>
</property>

<property>
  <name>yarn.log-aggregation.retain-seconds</name>
  <value>604800</value> <!-- 7 days -->
</property>
```

## 4. Create an OS-level safety net (logrotate)

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