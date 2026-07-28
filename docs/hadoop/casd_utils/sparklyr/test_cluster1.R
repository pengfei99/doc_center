install.packages("sparklyr")
install.packages("dplyr")

library(sparklyr)
library(dplyr)

# 1. Build configuration
config <- spark_config()

# Use $ or [[]] for list assignment in R
config$spark.executor.instances <- 2
config$spark.executor.cores     <- 1
config$spark.executor.memory    <- "2g"
config$spark.driver.memory      <- "2g"
config$spark.env.SPARK_LOCAL_IP  <- NULL
config$spark.driver.host <- "IP_ADD_OF_YOUR_SERVER"
config$spark.driver.bindAddress <- "0.0.0.0"
config$spark.submit.deployMode <- "client"

# 2. Establish connection to YARN
sc <- spark_connect(master = "yarn", config = config)

# 3. Generate a synthetic dataset directly on the cluster (No HDFS file needed!)
test_tbl <- sdf_len(sc, 1000) %>%
  group_by(is_even = id %% 2 ==0) %>%
  summarise(total_rows = n()) %>%
  collect()

# 4. Trigger cluster computation and fetch sample results
results <- head(test_tbl, n = 5)
print(results)

# 5. Release YARN containers
spark_disconnect(sc)