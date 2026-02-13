# Enable sasl rpc in hadoop cluster

When you integrate kerberos into Hadoop cluster, the datanode will be started in `secure mode`. To run data node in 
secure mode, you need to configure one of following options(not both):
- privileged resources: Legacy solution, not recommended
- SASL RPC data transfer with non-privileged ports: recommended solution.

For more details, you can visit this [page](https://cwiki.apache.org/confluence/display/HADOOP/Secure+DataNode).

As a result, we must set up all the required config to run SASL. 


## Generate certificate and key store for name node

In this tutorial, we choose to use an internal CA. Then we use the CA certificate to signe the certificate for the three nodes.

```shell
# generate root CA certificate
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.pem


# generate private key and csr for the name node
keytool -genkeypair \
  -alias nn \
  -keyalg RSA \
  -keysize 2048 \
  -storetype PKCS12 \
  -keystore keystore.p12 \
  -validity 365 \
  -storepass casd2026 \
  -keypass casd2026 \
  -dname "CN=deb13-spark1.casdds.casd, OU=Hadoop, O=Cluster, C=FR"

# export the csr from the keystore
keytool -certreq \
  -alias nn \
  -keystore keystore.p12 \
  -storetype PKCS12 \
  -file nn.csr \
  -storepass casd2026

# sign the csr with root ca
openssl x509 -req -in nn.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out nn.crt -days 1365 -sha256

# import root ca to the keystore
keytool -import \
  -alias cluster-ca \
  -file ca.pem \
  -keystore keystore.p12 \
  -storetype PKCS12 \
  -storepass casd2026

# import the name node certificate into the keystore
keytool -import \
  -alias nn \
  -file nn.crt \
  -keystore keystore.p12 \
  -storetype PKCS12 \
  -storepass casd2026

# you can check the keystore conetent with 
keytool -list -v -keystore keystore.p12 -storetype PKCS12


```

## Generate certificate and key store for data node 1

Generate keystore for datanode1 (deb13-spark2.casdds.casd)

```shell
# generate private key and csr for the name node
keytool -genkeypair \
  -alias dn1 \
  -keyalg RSA \
  -keysize 2048 \
  -storetype PKCS12 \
  -keystore keystore-dn1.p12 \
  -validity 365 \
  -storepass casd2026 \
  -keypass casd2026 \
  -dname "CN=deb13-spark2.casdds.casd, OU=Hadoop, O=Cluster, C=FR"

# export the csr from the keystore
keytool -certreq \
  -alias dn1 \
  -keystore keystore-dn1.p12 \
  -storetype PKCS12 \
  -file dn1.csr \
  -storepass casd2026

# sign the csr with root ca
openssl x509 -req -in dn1.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out dn1.crt -days 1365 -sha256

# import root ca to the keystore
keytool -import \
  -alias cluster-ca \
  -file ca.pem \
  -keystore keystore-dn1.p12 \
  -storetype PKCS12 \
  -storepass casd2026

# import the name node certificate into the keystore
keytool -import \
  -alias dn1 \
  -file dn1.crt \
  -keystore keystore-dn1.p12 \
  -storetype PKCS12 \
  -storepass casd2026

# you can check the keystore conetent with 
keytool -list -v -keystore keystore-dn1.p12 -storetype PKCS12


```
## Generate certificate and key store for data node 2

Generate keystore for datanode2 (deb13-spark3.casdds.casd)

```shell
# generate private key and csr for the name node
keytool -genkeypair \
  -alias dn2 \
  -keyalg RSA \
  -keysize 2048 \
  -storetype PKCS12 \
  -keystore keystore-dn2.p12 \
  -validity 365 \
  -storepass casd2026 \
  -keypass casd2026 \
  -dname "CN=deb13-spark3.casdds.casd, OU=Hadoop, O=Cluster, C=FR"

# export the csr from the keystore
keytool -certreq \
  -alias dn2 \
  -keystore keystore-dn2.p12 \
  -storetype PKCS12 \
  -file dn2.csr \
  -storepass casd2026

# sign the csr with root ca
openssl x509 -req -in dn2.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out dn2.crt -days 1365 -sha256

# import root ca to the keystore
keytool -import \
  -alias cluster-ca \
  -file ca.pem \
  -keystore keystore-dn2.p12 \
  -storetype PKCS12 \
  -storepass casd2026

# import the name node certificate into the keystore
keytool -import \
  -alias dn2 \
  -file dn2.crt \
  -keystore keystore-dn2.p12 \
  -storetype PKCS12 \
  -storepass casd2026

# you can check the keystore conetent with 
keytool -list -v -keystore keystore-dn2.p12 -storetype PKCS12


```
## Convert certificate to java keystore
