export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export HADOOP_OPTS="$HADOOP_OPTS -Dhadoop.security.krb5.principal.validation=false"
export HADOOP_OPTS="$HADOOP_OPTS -Dsun.security.krb5.principal.validation=false"
export HADOOP_OPTS="$HADOOP_OPTS -Djavax.security.auth.useSubjectCredsOnly=false"
export HADOOP_OPTS="$HADOOP_OPTS -Djava.net.preferIPv4Stack=true -Djava.security.debug=gssloginconfig,configfile,configparser,logincontext"
export HADOOP_OPTS="$HADOOP_OPTS -Djava.security.krb5.conf=/etc/krb5.conf"
export HDFS_NAMENODE_USER=hadoop
export HDFS_DATANODE_USER=hadoop
export HDFS_SECONDARYNAMENODE_USER=hadoop

export HADOOP_CONF_DIR=/usr/local/hadoop/etc/hadoop

export JAVA_TOOL_OPTIONS="$JAVA_TOOL_OPTIONS --add-opens=java.base/sun.net.dns=ALL-UNNAMED"
export HADOOP_HOME=/usr/local/hadoop
export HADOOP_SBIN_DIR=$HADOOP_HOME/sbin