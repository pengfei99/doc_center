# Submit spark/pyspark job to the spark cluster

Spark allows user to submit native spark job(.jar) or pyspark job(.py) to the spark cluster.

In this tutorial, we only show how to submit pyspark jobs.



## 1. Check local spark env

First check if you have spark installed in your environment. Go to `d1mutua-client.casd.fr` and run the below commands. 

```shell
# check current spark runtime version
spark-submit --version

# check if you have kerberos ticket
klist

# create your first spark job
nano job1.py
```

> Put the below code in the `job1.py` file

```python
from pyspark.sql import SparkSession

def main():
    # Create Spark session
    spark = SparkSession.builder \
        .appName("my_test") \
        .getOrCreate()

    # For a basic test, create a small DataFrame
    df = spark.createDataFrame([
        ("Alice", 25),
        ("Bob", 30),
        ("Charlie", 35)
    ], ["name", "age"])

    df.show()

    # Just for validation: print row count
    print(f"Total rows: {df.count()}")

    spark.stop()

if __name__ == "__main__":
    main()
```

> use `ctrl+o` for saving file. ctrl+x for exiting.

When we submit the spark job to the cluster, we need to specify the resources with the below command
```shell
spark-submit \
  --name=test_job \
   job1.py
```
After the above command, You should see your spark job in [yarn web UI](https://d1mutua-m01.casd.fr:8090/cluster) with status running.
The job will take about 1 min to finish, after finish you can check the output logs. If this works, it means your spark client configuration is correct
If not, contact `service@casd.eu`

## 2. Customize spark session configuration.

You can customize your spark session configurations in four ways:

1. `SparkSession.builder.config()` (in your PySpark job script)
2. `spark-submit` command-line flags (e.g., --executor-memory 4G)
3. `spark-submit --properties-file` (Your custom .conf file)
4. `spark-defaults.conf` (The global cluster-wide default configuration file which CASD defined)


### 2.1 Specify configuration in builder

Below is an example how to specify spark session configuration in `spark session builder`

```python
from pyspark.sql import SparkSession

def main():
    # Create Spark session
    spark = SparkSession.builder \
        .("spark.submit.deployMode","client") \
        .("spark.executor.instances","4") \
        .appName("sumbit_test") \
        .getOrCreate()
```

### 2.2 Specify configuration in spark-submit command

Below is an example of how to specify spark session configuration in `spark-submit command`

```shell
spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --num-executors 2 \
  --driver-memory 4G \
  --driver-cores 2 \ 
  --executor-memory 4G \
  --executor-cores 2 \
  --name=test_job \
   job1.py
```
The command option meaning:
- `--master yarn`: The spark cluster resource manager is yarn
- `--deploy-mode cluster`: the spark deploy mode is cluster mode
- `--num-executors 2`: number of worker
- `--driver-memory 4G`: the memory of driver
- `--driver-cores 2`: the vCore of the driver
- `--executor-memory 4G` the memory of worker
- `--executor-cores 2`: the vCore of the worker


### 2.3 Specify configuration in Conf files

Below is an example of how to specify spark session configuration in `conf file`

```shell
spark.master yarn
spark.submit.deployMode cluster
spark.yarn.archive hdfs:///utils/spark-libs/spark-3.5.7.zip
spark.yarn.stagingDir hdfs:///users

spark.serializer org.apache.spark.serializer.KryoSerializer
spark.rdd.compress true

spark.authenticate true
spark.network.crypto.enabled true
spark.io.encryption.enabled true

spark.executor.instances 2
spark.executor.cores 2
spark.executor.memory 2g
spark.executor.memoryOverhead 384m

spark.driver.cores 1
spark.driver.memory 1g
spark.driver.memoryOverhead 384m

spark.sql.adaptive.enabled true
spark.sql.adaptive.coalescePartitions.enabled true
spark.sql.autoBroadcastJoinThreshold 32m

spark.network.timeout 600s
spark.executor.heartbeatInterval 60s

```

If you want to use a custom conf file you can specify the conf file path in the spark-submit command

```shell
spark-submit \
  --properties-file /path/to/my-spark.conf \
  --name=test_job \
   job1.py
```

> The global `spark-defaults.conf` is controlled by CASD administrator, the end users do not have access and can not modify it.

### 2.4 Conflit resolution between config

You can notice that we may have different configuration values in each configuration way, to solve conflicts, spark introduces a priority system.

1. `SparkSession.builder.config()` (in your PySpark job script)
2. `spark-submit` command-line flags (e.g., --executor-memory 4G)
3. `spark-submit --properties-file` (Your custom .conf file)
4. `spark-defaults.conf` (The global cluster-wide default configuration file which CASD defined)

The above order is the exact order of priority Spark uses to resolve conflicts between configuration, from highest to lowest:

For example, if I have the `("spark.submit.deployMode","client")` in my job1.py, and run the spark-submit with `--deploy-mode cluster`. 
The deployment mode of my spark job will be `client` instead of `cluster`
Because `SparkSession.builder` configuration has higher priority than the `spark-submit` command configuration.





### 2.5 Configuration Optimization in CASD

To avoid users specify all the options during `spark-submit`, CASD has predefined a default configuration for all spark jobs.
As a result, if user does not overwrite the default values, all submitted jobs will use the default values.
The below file shows the spark default configuration values
```shell
spark.master yarn
spark.submit.deployMode cluster
spark.yarn.archive hdfs:///utils/spark-libs/spark-3.5.7.zip
spark.yarn.stagingDir hdfs:///users

spark.serializer org.apache.spark.serializer.KryoSerializer
spark.rdd.compress true

spark.authenticate true
spark.network.crypto.enabled true
spark.io.encryption.enabled true

spark.executor.instances 2
spark.executor.cores 2
spark.executor.memory 2g
spark.executor.memoryOverhead 384m

spark.driver.cores 1
spark.driver.memory 1g
spark.driver.memoryOverhead 384m

spark.sql.adaptive.enabled true
spark.sql.adaptive.coalescePartitions.enabled true
spark.sql.autoBroadcastJoinThreshold 32m

spark.network.timeout 600s
spark.executor.heartbeatInterval 60s

```

> We only recommend users to overwrite values such as:
> - spark.executor.instances 2 
> - spark.executor.cores 2 
> - spark.executor.memory 2g
> - spark.driver.cores 1 
> - spark.driver.memory 1g
> to make your spark job more efficient.

> We **do not** recommend you to overwrite other values unless you know what you are doing. 
> 
> 
### 2.6 Mode client vs Mode cluster

Spark jobs has two deploy mode:
- client :`spark.submit.deployMode client`
- cluster : `spark.submit.deployMode cluster`

If your spark jobs run in `client mode`, the spark driver runs inside the `local machine` not in the spark cluster. This mode
is suitable for `interactive spark session such as jupyterLab, sparklyr`. But the downside is you need to install all the python dependencies
in your local machine(e.g. pyspark, pandas, etc.). In the case of d1mutua, the driver will run in `d1mutua-client.casd.fr`. As a result, 
you do need to install python environment and pyspark in `d1mutua-client.casd.fr`.


If your spark jobs run in `cluster mode`, nothing runs inside the `local machine`, all(e.g. driver and worker) run 
in the spark cluster. This mode is suitable for `spark-submit`. As nothing runs locally, you do not need to install any
python or python dependencies.


## 3. CASD recommendation

To make you have best experience with the spark cluster, if your code is mature, and you run spark jobs with `spark-submit`,
use `cluster mode`. If you are exploring data are test some new workflow, use `jupyter or sparklyr` with `client mode`.

If you use `cluster mode`, make your `SparkSession.builder` as small as possible, so your code is portable and reusable.
Below is the `SparkSession.builder` recommended by CASD.
```python
# Create Spark session
spark = SparkSession.builder \
    .appName("sumbit_test") \
    .getOrCreate()
```

If you want to overwrite the below configurations, do it in spark-submit command

> - spark.executor.instances 2 
> - spark.executor.cores 2 
> - spark.executor.memory 2g
> - spark.driver.cores 1 
> - spark.driver.memory 1g

For example, you can use the below command

```shell
spark-submit \
  --num-executors 2 \
  --driver-memory 4G \
  --driver-cores 2 \ 
  --executor-memory 4G \
  --executor-cores 2 \
  --name=test_job \
   job1.py
```

> This job takes 1 driver(2vCore, 4GB), 2 workers(2vCore, 4GB), in total 6vCore, 12GB mem of the cluster.
> We have configured the spark deploy mode as `cluster`. So all the 6vCore, adn 12GB memory will be consumed as the 
> resource of the cluster. If the cluster does not have enough resource available, your job will never run
> 
> 
## 4. Other restriction

For now, we only have 3 datanodes with 8 vCore, and 16G mem, we only allow users to use 11.72GB mem to avoid server over
booking, because there are other process(e.g. HDFS, yarn, system monitoring, etc.) runs on the same server. 

For each executor, the `max Vcore is 4`, the `max memory is 12GB`. so if you have the below spark-submit command, it will fail
```shell
spark-submit \
  --executor-memory 14G \
  --executor-cores 6 \
  --name=test_job \
   job1.py
```


