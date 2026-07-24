
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
config <- spark_config()

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

## Process hdfs data 

```r
# Read Parquet dataset directly from HDFS
hdfs_path <- "hdfs:///data/production/sales_events_parquet"
sales_tbl <- spark_read_parquet(sc, name = "sales_raw", path = hdfs_path)

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

> - Keep `winutils.exe` in mind: On Windows, Spark client libraries require `winutils.exe` inside %HADOOP_HOME%\bin (e.g., C:\hadoop\bin\winutils.exe) 
> to manage local temporary file permissions during YARN submits.
> - Lazy Evaluation First: Never call collect() on raw HDFS tables. Always filter, aggregate, and reduce data on Spark worker nodes first.
> - Network Latency: In YARN client mode, shuffle metadata and driver-to-executor coordination travel over the network between Windows and the Hadoop cluster. Ensure your Windows Server has a high-bandwidth connection (10 Gbps recommended) to the cluster subnet.