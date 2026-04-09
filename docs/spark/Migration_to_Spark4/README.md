# Migration from spark 3.5 to spark 4

## JDK 

Spark 4 requires `jdk 17 or 21` to run. If you have other packages which needs to run with spark, you may
choose jdk 17 for better compatibility. If you want performance, you can use 21.

> Here we recommend zulu jdk build. 

## Hadoop

If you use linux, you only need to install a hadoop 3.4.1+. If you use windows you also need to download
`winutils.exe` and `hadoop.dll`.

## Pyspark

If you use pyspark, the python version must be 3.10+. And the pyspark version must match exactly
the spark version.

There is an official migration page https://spark.apache.org/docs/latest/api/python/migration_guide/pyspark_upgrade.html

### Sparklyr

Sparklyr does not support spark 4.1 officially yet. You can check this issue page https://github.com/sparklyr/sparklyr/issues/3511

If it's not really crucial, we don't recommend you to use sparklyr with spark 4.1

## Some warning message

```powershell
spark-submit --version
WARNING: Using incubator modules: jdk.incubator.vector
```
