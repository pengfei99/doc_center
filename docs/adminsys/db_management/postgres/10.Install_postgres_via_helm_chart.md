# 10. Deploy PostgreSQL Using Helm
Helm gives you a quick and easy way to deploy a PostgreSQL instance on your cluster.

## 10.1 Add Helm Repository

Search [Artifact Hub](https://artifacthub.io/) for a PostgreSQL Helm chart that you want to use. Add the chart's repository to your local Helm installation by typing:

```shell
# general form
helm repo add [repository-name] [repository-address]

# In this tutorial, we will use the chart of `Bitnami`.
helm repo add bitnami https://charts.bitnami.com/bitnami

# update your local repo
helm repo update
```

## 10.2 Create and Apply Persistent Storage Volume

**This step can be ommitted if you use storageClass such as rook-ceph-block. You can create a pvc, a corresponding pv will be created automatically**
Manifest for creating the PV: `postgres-pv.yaml`.

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgresql-pv
  labels:
    type: local
spec:
  storageClassName: rook-ceph-block
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteOnce
```

Apply the configuration with kubectl:

```shell
kubectl apply -f postgres-pv.yaml
```

> PV creation requires admin right, and it's a cluster level resource which can be consumed by PVC

## 10.3 Create and Apply Persistent Volume Claim

Create a Persistent Volume Claim (PVC) to request the storage allocated in the previous step.

Manifest for creating the PVC: `postgres-pvc.yaml`

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgresql-pv-claim
spec:
  storageClassName: rook-ceph-block
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
```

Apply the configuration with kubectl:

```shell
kubectl apply -f postgres-pvc.yaml

# check the created pvc
kubectl ger pvc
```

> PVC is a namespaced resource, it needs to be created and used in a specific namespace

## 10.4 Install postgres via Helm chart

You need to modify the default chart configuration [values.yaml](https://github.com/bitnami/charts/blob/main/bitnami/postgresql/values.yaml).

```yaml
global:
  postgresql:
    auth:
      postgresPassword: "postgres"
      username: "keycloak"
      password: "changeMe"
      database: "keycloak"

```

```shell
helm install keycloak-postgres bitnami/postgresql --set persistence.existingClaim=postgresql-pv-claim --set volumePermissions.enabled=true --values values.yaml -n keycloak
```

This helm chart should create below resources:
```shell
kubectl get all -n keycloak

# one statefulset
NAME                                            READY   AGE
statefulset.apps/keycloak-postgres-postgresql   1/1     47m

# one pod of the statefulset
NAME                                 READY   STATUS    RESTARTS   AGE
pod/keycloak-postgres-postgresql-0   1/1     Running   0          47m

# two services
NAME                                      TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
service/keycloak-postgres-postgresql      ClusterIP   10.233.36.23   <none>        5432/TCP   47m
service/keycloak-postgres-postgresql-hl   ClusterIP   None           <none>        5432/TCP   47m

kubectl get secret -n keycloak

# It generate also a secret
NAME                                      TYPE                                  DATA   AGE
keycloak-postgres-postgresql              Opaque                                2      46m


```

You can view the content of the secrete with below command

```shell
# get the secret content in yaml format
kubectl get secret -n keycloak keycloak-postgres-postgresql -o yaml

# get the root password
kubectl get secret -n keycloak keycloak-postgres-postgresql -o jsonpath="{.data.postgres-password}" | base64 --decode

# get the password of the user `keycloak`
kubectl get secret -n keycloak keycloak-postgres-postgresql -o jsonpath="{.data.password}" | base64 --decode

# you can create env var
export POSTGRES_ROOT_PASSWORD=$(kubectl get secret -n keycloak keycloak-postgres-postgresql -o jsonpath="{.data.postgres-password}" | base64 --decode)
```

## 10.5 Test installed database
You can use this [repo](https://github.com/pengfei99/psql-client) to create a psql client container.

Copy below content in `pod.yml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: postgresql-client
  labels:
    app: postgresql-client
  annotations:
    cluster-autoscaler.kubernetes.io/safe-to-evict: "true"    
spec:
  securityContext:
    runAsNonRoot: true
    supplementalGroups: [ 10001] 
    fsGroup: 10001    
  containers:
    - name: postgresql-client
      image: liupengfei99/psql-client
      imagePullPolicy: Always
      securityContext:
        runAsUser: 1000      
      stdin: true
      tty: true
      command: ["/bin/sh"]
```

Use below command to deploy the pod
``` bash
# deploy pod
kubectl apply -f pod.yml

# get a shell of the 
kubectl exec -it postgresql-client -- /bin/sh

# general form
psql -h <host_ip_address> -p <port> -U <user> -W

# connect to a postgresql svc (via service ip)
psql -h 10.233.36.23 -U keycloak -W

# via k8s service fqdn
psql -h keycloak-postgres-postgresql.keycloak.svc.cluster.local -U keycloak -W
```