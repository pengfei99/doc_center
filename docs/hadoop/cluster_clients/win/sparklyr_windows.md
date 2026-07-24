## Configure Spark env

```R
# Set cluster configuration paths (use forward slashes in R on Windows)
Sys.setenv(HADOOP_CONF_DIR = "C:/hadoop/conf")
Sys.setenv(YARN_CONF_DIR   = "C:/hadoop/conf")

# Specify your local Spark client path matching your cluster's Spark version
Sys.setenv(SPARK_HOME      = "C:/spark/spark-3.4.1-bin-hadoop3")

# Ensure Java home is set to a 64-bit JDK (e.g., Java 8, 11, or 17)
Sys.setenv(JAVA_HOME        = "C:/Program Files/Java/jdk-11")
```

## Configure Spark connections

```r
library(sparklyr)
library(dplyr)

# 1. Verify Kerberos ticket directly from R
ticket_status <- system("klist", intern = TRUE)
message("Kerberos Ticket Status:\n", paste(head(ticket_status, 4), collapse = "\n"))

# 2. Build Spark configuration
conf <- spark_config()

# YARN Deployment Mode
config$spark.master <- "yarn"
config$spark.submit.deployMode <- "client" # Driver runs on Windows Server

# Resource Allocation Settings
config$spark.executor.instances <- 4
config$spark.executor.cores     <- 2
config$spark.executor.memory    <- "4g"
config$spark.driver.memory      <- "4g"

# Dynamic Allocation (disable if manually specifying executor instances)
config$spark.dynamicAllocation.enabled <- "false"

# Kerberos HDFS/Hive Token Renewal
config$spark.yarn.security.tokens.hdfs.enabled <- "true"
config$spark.yarn.security.tokens.hive.enabled <- "true"

# Network timeouts (crucial for remote Windows-to-YARN latency)
config$spark.network.timeout <- "800s"
config$spark.executor.heartbeatInterval <- "60s"

# 3. Establish the connection
sc <- spark_connect(config = config)
```

The version of Midares

```r
install.packages("sparklyr")
install.packages("dplyr")

library(sparklyr)
library(dplyr)

conf <- spark_config()

config["spark.executor.instances"] <- 2
config["spark.executor.cores"]     <- 1
config["spark.executor.memory"]    <- "4g"
config["spark.driver.memory"]      <- "4g"

sc <- spark_connect(master="yarn", config = config)

hdfs_path <- "hdfs:///data/production/sales_events_parquet"
sales_tbl <- spark_read_parquet(sc, path = hdfs_path, memory=FALSE)
head(sales_tbl, n=5)
```

## Process hdfs data

```r
# Read Parquet dataset directly from HDFS
hdfs_path <- "hdfs:///data/production/sales_events_parquet"
sales_tbl <- spark_read_parquet(sc, path = hdfs_path, memory=FALSE)

# Apply lazy transformations (executed on Spark, not in R memory)
sales_summary <- sales_tbl %>%
  filter(year == 2025, status == "COMPLETED") %>%
  group_by(region, product_category) %>%
  summarise(
    total_revenue = sum(amount, na.rm = TRUE),
    transaction_count = n(),
    .groups = "drop"
  ) %>%
  filter(transaction_count > 100)

# Inspect the generated Spark SQL execution plan
show_query(sales_summary)

# Cache intermediate result in Spark Executor RAM (not Windows RAM)
sales_summary_cached <- compute(sales_summary, name = "sales_summary_cached")

# Collect only the final aggregated dataset back to local R memory
local_df <- collect(sales_summary_cached)

print(head(local_df))

# close spark session
spark_disconnect(sc)
```

> - Keep `winutils.exe` in mind: On Windows, Spark client libraries require `winutils.exe` inside %HADOOP_HOME%\bin (
    e.g., C:\hadoop\bin\winutils.exe)
    > to manage local temporary file permissions during YARN submits.
> - Lazy Evaluation First: Never call collect() on raw HDFS tables. Always filter, aggregate, and reduce data on Spark
    worker nodes first.
> - Network Latency: In YARN client mode, shuffle metadata and driver-to-executor coordination travel over the network
    between Windows and the Hadoop cluster. Ensure your Windows Server has a high-bandwidth connection (10 Gbps
    recommended) to the cluster subnet.


## To connect to spark 4.1 

If you use sparklyr to connect to spark 4.*, you need to pay attention of the below points:
- JDK version
- spark and hadoop version of the driver must be the same as the cluster
- sparklyr version
- ANSI SQL behavior
- 

### JDK version

For Spark 4.x, `JDK 17+` is Now Mandatory. Support for Java 8 and Java 11 is completely dropped. 
On your driver machine, your `JAVA_HOME` environment variable must point to `JDK 17+`
```r
Sys.setenv(JAVA_HOME = "C:/Program Files/Java/jdk-17") 
```

> If you keep Java 8 or 11 in JAVA_HOME, driver initialization will crash with an `UnsupportedClassVersionError`.
> 
### Spark and Hadoop version
The version of spark and hadoop in driver must be identical of the cluster

### Sparklyr version

For spark 4.x, sparklyr Version must be `1.9.0+`. Because Spark 4.x runs exclusively on Scala 2.13 (Scala 2.11 and 2.12 support were removed).
Older versions of sparklyr only contained Scala 2.11/2.12 backend JARs. 

```r
# Check your installed sparklyr version in R
packageVersion("sparklyr") # Must be >= 1.9.0

# If needed, update sparklyr from CRAN
install.packages("sparklyr")
```


### Strict ANSI SQL behavior

`Spark 4.x enabls Strict ANSI SQL Behavior` by default `(spark.sql.ansi.enabled = true)`.Under strict ANSI SQL rules, 
operations like dividing by zero, invalid string-to-number casts, or array index out-of-bounds `throw an runtime exception rather than returning NULL`. 

If you prefer Spark 3.x's legacy lenient behavior, set this explicitly in your config
```text
config$`spark.sql.ansi.enabled` <- "false"

```

## How Spark Loads Configuration Under the Hood

When you execute `spark_connect(master = "yarn")` in R, sparklyr does not create a Spark cluster from scratch, 
it launches a local `Scala/Java gateway process` using the binaries located at your `SPARK_HOME`.

```text
[ R Session ] 
      │
      ▼ spark_connect(master = "yarn")
[ sparklyr Java Gateway ]
      │
      ▼ Looks for $SPARK_HOME/conf/spark-defaults.conf
[ Reads Key-Value Properties ]
      │
      ▼ Builds SparkConf JVM Object
[ Submits YARN Client Application ]
```

During initialization, Spark automatically checks `$SPARK_HOME/conf/spark-defaults.conf`. Any key-value pair 
inside that file is injected into the `driver's SparkConf object` before the connection to YARN is established.


In your Windows Spark client folder, navigate to `C:\path\to\spark-4.1.0\conf\`.

Create a file named `spark-defaults.conf` (if it only contains spark-defaults.conf.template, copy or rename it) 
and add your properties using standard key-value whitespace format:

```ini
# ===================================================================
# SPARK & YARN DEPLOYMENT
# ===================================================================
spark.master                             yarn
spark.submit.deployMode                  client

# ===================================================================
# RESOURCE ALLOCATION
# ===================================================================
spark.driver.memory                      4g
spark.executor.memory                    4g
spark.executor.cores                     2
spark.executor.instances                 4

# ===================================================================
# PATHS & DISK STORAGE (Prevent C:\ disk spillage)
# ===================================================================
spark.local.dir                          D:/spark_scratch
spark.yarn.stagingDir                    hdfs:///tmp/spark_staging
spark.sql.warehouse.dir                  hdfs:///user/hive/warehouse

# ===================================================================
# METASTORE & SECURITY
# ===================================================================
spark.hadoop.hive.metastore.uris         thrift://your-hive-metastore:9083
spark.yarn.security.tokens.hdfs.enabled  true
spark.yarn.security.tokens.hive.enabled  true

# Network & Stability
spark.network.timeout                    800s
spark.executor.heartbeatInterval         60s
```

> If users set value in the config of the sparklyr session, the default values will be overwritten.