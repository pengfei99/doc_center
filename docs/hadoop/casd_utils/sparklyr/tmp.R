library(sparklyr)
library(dplyr)

# ==============================================================================
# 1. Build Cluster Configuration & Network Settings
# ==============================================================================
config <- spark_config()

# YARN Resource Allocation
config$spark.executor.instances <- 2
config$spark.executor.cores     <- 1
config$spark.executor.memory    <- "2g"
config$spark.driver.memory      <- "2g"

# Driver Network Settings (Windows Driver -> YARN Worker return path)
config$spark.env.SPARK_LOCAL_IP <- NULL
config$spark.driver.host        <- "10.100.20.45"  # Replace with your actual Windows IP
config$spark.driver.bindAddress <- "0.0.0.0"
config$spark.submit.deployMode  <- "client"

# Connect to YARN
sc <- spark_connect(master = "yarn", config = config)

# ==============================================================================
# 2. Read Input File from HDFS
# ==============================================================================
hdfs_csv_path <- "hdfs:///data/production/sales_data.csv"

raw_tbl <- spark_read_csv(
  sc,
  name         = "raw_population",
  path         = hdfs_csv_path,
  header       = TRUE,
  infer_schema = TRUE,
  memory       = FALSE,  # Keeps data lazy; does not load entire CSV into RAM
  overwrite    = TRUE
)

# FIX 1: Passed 'raw_tbl' into head() and collected to inspect input rows
sample_raw <- head(raw_tbl, n = 5) %>% collect()
print("--- Raw Data Sample (First 5 Rows) ---")
print(sample_raw)

# ==============================================================================
# 3. Apply Lazy Transformations (Translation to Spark SQL)
# ==============================================================================
summary_tbl <- raw_tbl %>%
  filter(!is.na(age), age > 0) %>%
  group_by(sex) %>%
  summarise(
    total_count = n(),
    avg_age     = mean(age, na.rm = TRUE),
    .groups     = "drop"
  ) %>%
  arrange(desc(total_count))

# ==============================================================================
# 4. Write Results Back to HDFS
# ==============================================================================
# BEST PRACTICE: Write as Parquet for columnar compression and fast read performance
hdfs_output_parquet <- "hdfs:///data/production/summary_age_by_sex_parquet"

spark_write_parquet(
  x         = summary_tbl,
  path      = hdfs_output_parquet,
  mode      = "overwrite"
)

# ALTERNATIVE: Write as CSV if explicitly required by downstream legacy systems
hdfs_output_csv <- "hdfs:///data/production/summary_age_by_sex_csv"

spark_write_csv(
  x         = summary_tbl,
  path      = hdfs_output_csv,
  header    = TRUE,
  mode      = "overwrite"
)

message("Successfully written results to HDFS:\n - Parquet: ", hdfs_output_parquet, "\n - CSV: ", hdfs_output_csv)

# ==============================================================================
# 5. Fetch Final Results to R Memory & Clean Disconnect
# ==============================================================================
results <- summary_tbl %>% collect()
print("--- Final Aggregated Results ---")
print(results)

# Cleanly release YARN application containers
spark_disconnect(sc)