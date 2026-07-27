# Common problems

## Firewall

If you run the spark session in `mode client`, the `spark driver` runs on the server where the spark session is initiated.

The `spark driver` requires specific firewall configuration. To understand why, let's check how the spark session
is created.

```text
[ Windows Machine ]                                [ YARN Master Node ]                              [ YARN Worker Node ]
 10.50.5.10                                           10.50.5.20                                       10.50.5.20
  +-----------------------+                        +-------------------+                             +-------------------+
  | Jupyter Kernel (R)    |                        | YARN Scheduler    |                             | YARN Container    |
  | Spark Driver JVM      |                        |                   |                             | Spark Executor    |
  +-----------------------+                        +-------------------+                             +-------------------+
             |                                               |                                                  |
             |  1. "Launch a spark session with 4 executors" | 2. Yarn checks the cluster ressources,           |
             |---------------------------------------------->| if resources ok, Yarn send job request           |
             |                                               | to worker node (driver ip:  10.50.5.10,          |
             |                                               | driver port: 7077, blockManager port: 7078 )     |                 |
             |                                               | ------------------------------------------------>|
             |                                               |                                                  |
             |                                               |   3. Executor attempts connection to             |
             |                                               |           spark driver (10.50.5.10)              |
             |                                               |       on port 7077, and 7078                     |
             X <------------------------------------------------------------------------------------------------+
```

> If the worker can not connect to the driver, you will see the below error message 
> `initial job has not accepted any resources; check your cluster UI to ensure that workers have sufficient resources`
> This is because when no worker can connect to the driver, driver thinks there is no worker available, because not enough resource.
> 
> 
In your spark-defaults.conf, you can change how spark driver connect to the spark workers

```text
# 1. Tell YARN worker nodes exact IP to reach back to Windows Driver
spark.driver.host  10.50.5.10
spark.driver.bindAddress 0.0.0.0

# 2. Lock driver and block manager ports to specific ports so Windows Firewall can allow them
spark.driver.port 7077
spark.blockManager.port 7078
```