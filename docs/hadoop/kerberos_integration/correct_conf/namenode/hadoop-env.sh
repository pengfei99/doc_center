export JAVA_HOME=/opt/java/jdk-11.0.2

export HADOOP_OS_TYPE=${HADOOP_OS_TYPE:-$(uname -s)}
export HDFS_NAMENODE_USER=hadoop
export HDFS_DATANODE_USER=hadoop
export YARN_RESOURCEMANAGER_USER=hadoop
export YARN_NODEMANAGER_USER=hadoop

export HADOOP_LOG_DIR=/var/log/hadoop
export HADOOP_PID_DIR=/var/run/hadoop

# for hdfs client
export HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_HOME/lib/native
export HADOOP_OPTS="$HADOOP_OPTS -Djava.library.path=$HADOOP_HOME/lib/native"
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$HADOOP_HOME/lib/native
