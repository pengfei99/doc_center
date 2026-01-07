s3_endpoint=https://minio.casd.local
access_key=minio
secret_key=changeMe

mc alias set s3 $s3_endpoint $access_key $secret_key --api S3v4

