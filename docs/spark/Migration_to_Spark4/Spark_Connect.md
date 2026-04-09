# Spark connect 
Since spark4.0+, a new application->spark driver->spark executor connection mode `spark connect` is provided.


The core difference between `spark connect application` and `traditional spark application`:
- Traditional Spark -> your application is the driver
- Spark Connect -> your application talks to a remote driver


You can find the official doc [here](https://spark.apache.org/docs/latest/spark-connect-overview.html)

## 1 Traditional spark application architecture

```text
Python / R / Scala app
        ↓
   Driver (local JVM)
        ↓
Cluster Manager (YARN)
        ↓
Executors (DataNodes)
```
Key properties of this architecture:
- Driver runs inside your process
- Python talks to JVM via Py4J
- Tight coupling between: PySpark, JVM and Spark binary(version must match exactly)

Communication flow:
Python(pyspark) -> local JVM via Py4J -> JVM executes everything -> talks to spark cluster
After the calculation, spark cluster send result back to local JVM -> local JVM -> Python
> The pyspark client(Py4j) builds plan, runs spark driver, and manages execution coordination with the spark cluster.
The spark cluster only runs executors.

System requirements:
- Jdk installed
- Spark installed
- Hadoop client (winutils.exe)
- python/pyspark

API coverage(full access):
- DataFrame API
- SQL API
- RDD API
- Spark internals
- JVM calls

## 2 Spark Connect application architecture

```text
Client (Python / R / Notebook)
        ↓  (gRPC)
Spark Connect Server (Driver)
        ↓
Cluster Manager (YARN)
        ↓
Executors
```

Key properties of this architecture:
- Driver runs remotely in the spark master server
- Communication via gRPC
- Client is lightweight

Communication flow:
Python(pyspark) -> spark connect server -> spark cluster
After the calculation, spark cluster send results -> spark connect server -> python

> The pyspark client builds only `logical plans` and send them to the `spark connect server` via `gRPC` protocol.
> The spark driver and everything else runs inside the spark cluster


System requirements:
- python/pyspark

API coverage(partial access):
- DataFrame API
- SQL API

### 1.3 Issues need to examine

- Multi-user behavior
- Security model
- spark.stop() does not free cluster resources immediately for spark-connect mode
- per-user session (--conf spark.connect.session.isolation.enabled=true)
- Kerberos auth (spark.hadoop.security.authentication=kerberos)
- Logging & debugging (logs on server side, not client)
- Use reverse proxy and TLS to secure the spark connect server
- run multiple connect servers behind a load balancer
- systemd service to handle the spark connect servers

#### 1.3.1 Multi-user behavior

Traditional spark client to cluster:
Users run their own spark driver on their local server, spark driver communicates with executor directly.


Spark Connect client to cluster:

Users run their spark application locally. They all connect to same `spark connect server`. They can share the same session or each user has an individual session based on the `spark connect server` configuration.


#### 1.3.2 Security model

They both support kerberos authentication.

#### 1.3.3 spark.stop() in Spark Connect

In traditional Spark:

The spark application contains the `spark driver`. When you call `spark.stop()`, it kills driver, on the cluster side all executors are released.

In Spark Connect:

the pyspark application does not have `spark driver` in it.  When you call `spark.stop()`, It closes your pyspark client session and disconnects from `Spark Connect server`. But the `remote driver` may continue to run and keep the executor alive.

> Spark Connect server is designed to handle `multiple sessions` and `keep sessions alive for reuse`.
> Spark Session lifecycle is server-managed in `Spark Connect` and decoupled from `pyspark client lifecycle`.

To free the resources manually(not recommended):

```shell
# kill the yarn application
yarn application -list
yarn application -kill <app_id>

# stop Spark Connect server
$SPARK_HOME/sbin/stop-connect-server.sh
```

Ask Spark Connect server to handle the session automatically:

```spark-defaults.conf
# After 5 minutes idle: session is cleaned and resources released
spark.connect.session.timeout 300s

# Enable dynamic allocation
spark.dynamicAllocation.enabled=true
spark.shuffle.service.enabled=true
```


### 1.4 Enable spark connect

To enable spark connect mode, you need to start a spark connect server first. Then users can start a client to connect to the server

#### 1.4.1 Configuration on the spark connect server

On the server side, we often use the spark master server to run the `spark connect server`. You need the spark 4.1.1+ binary. For example, we suppose you have the binary in `/opt/spark/spark-4.1.1`

You need to set up the following env var

```shell
# # env var for spark
export SPARK_HOME=/opt/spark/spark-4.1.1
export PATH=$SPARK_HOME/bin:$PATH

# env var for hadoop
export HADOOP_HOME=/opt/hadoop/hadoop-3.4.3
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export YARN_CONF_DIR=$HADOOP_HOME/etc/hadoop
export HADOOP_MAPRED_HOME=$HADOOP_HOME
export HADOOP_COMMON_HOME=$HADOOP_HOME
export HADOOP_HDFS_HOME=$HADOOP_HOME
export YARN_HOME=$HADOOP_HOME

export HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_HOME/lib/native
export HADOOP_OPTS="$HADOOP_OPTS -Djava.library.path=$HADOOP_HOME/lib/native"
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$HADOOP_HOME/lib/native

```

Test your spark cluster health

```bash
 spark-submit --master yarn --deploy-mode client $SPARK_HOME/examples/src/main/java/org/apache/spark/examples/JavaSparkPi.java
```
> If everything goes well, you should see a job in the yarn web ui.

Edit the `$SPARK_HOME/conf/spark-defaults.conf` file and put the below lines

```ini
spark.master                     yarn
spark.submit.deployMode          client

# Resource tuning (small cluster)
spark.executor.instances         2
spark.executor.cores             1
spark.executor.memory            1g

# Driver (on NameNode/edge)
spark.driver.memory              2g

# Performance
spark.sql.adaptive.enabled       true
spark.sql.shuffle.partitions     50

# Compatibility (important for migration)
spark.sql.ansi.enabled           false

# spark connect server is available on port 15002 for all ips
spark.connect.grpc.binding.host  0.0.0.0
spark.connect.grpc.binding.port  15002

```

`Now, you can start a Spark Connect Server`

```shell
$SPARK_HOME/sbin/start-connect-server.sh \
  --master yarn \
  --deploy-mode client
```


#### 1.4.2 Configuration on the spark client

On the python client side, you need to have python virtual env and install the below dependencies = [
    "grpcio>=1.80.0",
    "grpcio-status>=1.80.0",
    "pandas>=3.0.2",
    "pyarrow>=23.0.1",
    "pyspark==4.1.1",
    "zstandard>=0.25.0",
]

And below is a little spark program to test your cluster.

### 1.5 per-user session vs share session

By default, the spark connect server allow user to share the same spark driver. With this mode, we can't control who is doing what.

```text
Many users -> Spark Connect server -> many sessions -> ONE Spark driver -> ONE YARN application
```

So the `per-user` session is recommended for production environment. The key is the configuration `spark.connect.session.isolation.level`. It provides two isolation levels:
- session
- application

```text
User A -> Spark Connect server -> Session A -> Driver A ->Spark App A -> YARN (user A)
User B -> Spark Connect server -> Session B -> Spark App B -> YARN (user B)
```

```spark-defaults.conf
# Spark Connect endpoint
spark.connect.grpc.binding.host=0.0.0.0
spark.connect.grpc.binding.port=15002

# Isolation
spark.connect.session.isolation.level=APPLICATION

# Session lifecycle
spark.connect.session.timeout=300s

# Kerberos
spark.kerberos.principal=spark/host@REALM
spark.kerberos.keytab=/etc/security/keytabs/spark.keytab

# Impersonation
spark.hadoop.proxyuser.spark.hosts=*
spark.hadoop.proxyuser.spark.groups=*
```

