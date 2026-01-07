# Toolbox

The `Rook Toolbox` is a tool that helps you get the current state of your Ceph deployment and troubleshoot problems when they arise. It also allows you to change your Ceph configurations like enabling certain modules, creating users, or pools.

You can find the official doc [here](https://rook.io/docs/rook/v1.3/ceph-toolbox.html).

The toolbox can be started by deploying the [toolbox.yaml](../../resources/rook-ceph/toolbox.yaml) file, which is in the `rook/deploy/examples/` directory.

```shell
# deploy the pod
kubectl apply -f toolbox.yaml

# check the status of the pod
kubectl -n rook-ceph get pod -l "app=rook-ceph-tools"

# get a bash shell of the toolbox pod
kubectl -n rook-ceph exec -it $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') bash
```
Now you can run the `ceph` command inside this shell

```shell
# get the staus of the cluster
ceph status

# get the status of the osd
ceph osd status

```

## Dashboard access

https://rook.io/docs/rook/v1.10/Storage-Configuration/Monitoring/ceph-dashboard/#ingress-controller

Rook automatically enables the Ceph dashboard within the cluster when deployed. However, when hosting multiple VMs in a dev environment, it is difficult to directly access it.

Thankfully, the Datalab cluster has an Ingress controller and load-balancer set up, easing the process.

This tutorial walks us through the required steps to make the dashboard accessible in a web browser of your host machine running the Datalab cluster.

### Ingress creation


To create an Ingress resource associated with the dashboard service, create a manifest named `rook-dashboard-ingress.yaml`. Insert the following content in it:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rook-ceph-mgr-dashboard
  namespace: rook-ceph # namespace:cluster
  annotations:
    kubernetes.io/tls-acme: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/server-snippet: |
      proxy_ssl_verify off;
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - rook-ceph.casd.local
  rules:
    - host: rook-ceph.casd.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: rook-ceph-mgr-dashboard
                port:
                  name: https-dashboard
```

You may encounter this error
```text
Error from server (BadRequest): error when creating "rook-dashboard-ingress.yaml": admission webhook "validate.nginx.ingress.kubernetes.io" denied the request: nginx.ingress.kubernetes.io/server-snippet annotation cannot be used. Snippet directives are disabled by the Ingress administrator
```

You can disable the nginx admission webrook as a work around (not recommended for production)

```shell
kubectl delete -A ValidatingWebhookConfiguration ingress-nginx-admission
```

Apply this manifest with the following command:

```bash
kubectl apply -f dashboard-ingress-https.yaml
```

Then check the Ingresses to verify that it has been created successfully and that the load-balancer's IP has been attributed to it:

```bash
kubectl get ing -n rook-ceph
```

The host machine redirecting the `*.casd.local` wildcard domain to its own IP, it is now possible to access the dashboard from it.

### Accessing the dashboard

To access the dashboard on your host machine's web browser, the cluster's CA certificate must be trusted. Doing so is described [in the Onyxia usage steps](/en/datalab/datalab-install/onyxia#usage).

Open up a web browser and access `https://rook-ceph.casd.local`. You are then brought to a log-in screen for the Ceph dashboard.

### Dashboard login

The default admin account is enough to access the dashboard in a dev environment, using the following credentials:

- username: `admin`

The automatically generated default password is obtained with the following command:

```bash
kubectl -n rook-ceph get secret rook-ceph-dashboard-password \
 -o jsonpath="{['data']['password']}" | base64 --decode && echo
```

The default credentials are then displayed. Copy and paste them, then log in. Access to the dashboard is then granted.

## In-depth configuration of the Ceph dashboard

It is possible to enable additional dashboard configuration:

- To set Rook as Ceph's orchestrator in Ceph to let the dashboard display Kubernetes-specific info;
- To modify the admin dashboard password.

Both of those steps make use of the toolbox pod, we deploy it as follows.

### Toolbox pod

The toolbox pod is preconfigured to modify dashboard settings easily.

Deploy the toolbox pod using its manifest. This is automatically done in the Datalab cluster. The manifest is available from [the official Rook repository](https://github.com/rook/rook/blob/master/deploy/examples/toolbox.yaml):

```bash
curl -fsSL -o toolbox.yaml https://raw.githubusercontent.com/rook/rook/master/deploy/examples/toolbox.yaml
kubectl create -f toolbox.yaml
```

The toolbox pod allow us to use `ceph` commands, useful for troubleshooting (`ceph status`) or for dashboard configuration.

Access the toolbox pod using the following command:

```bash
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- bash
```

#### Common Ceph commands

 Once inside the toolbox pod, you can interact with Ceph clusters and run commands. Here is a list of useful commands to check the status of your cluster.

##### Check the status of the cluster

 ```shell
 bash-4.4$ ceph status


  cluster:
    id:     793aa423-c779-48d0-a784-efbae1199bd3
    health: HEALTH_OK

  services:
    mon: 1 daemons, quorum a (age 5d)
    mgr: a(active, since 5h)
    mds: 1/1 daemons up, 1 hot standby
    osd: 1 osds: 1 up (since 5d), 1 in (since 5d)

  data:
    volumes: 1/1 healthy
    pools:   4 pools, 81 pgs
    objects: 129 objects, 186 MiB
    usage:   560 MiB used, 511 GiB / 512 GiB avail
    pgs:     81 active+clean

  io:
    client:   1.2 KiB/s rd, 2 op/s rd, 0 op/s wr

 ```
##### Detailed Health status
This is useful for identifying bad physical groups that need repairs.

```shell
bash-4.4$ ceph health detail


HEALTH_OK

```

##### Status of all OSDs

 ```shell
bash-4.4$ ceph osd status


ID  HOST      USED  AVAIL  WR OPS  WR DATA  RD OPS  RD DATA  STATE
 0  worker1   559M   511G      0        0       2      106   exists,up

 ```
##### Ceph Pool details

```shell
bash-4.4$ ceph osd pool ls detail


pool 1 '.mgr' replicated size 1 min_size 1 crush_rule 0 object_hash rjenkins pg_num 1 pgp_num 1 autoscale_mode on last_change 10 flags hashpspool stripe_width 0 pg_num_max 32 pg_num_min 1 application mgr
pool 2 'myfs-metadata' replicated size 1 min_size 1 crush_rule 2 object_hash rjenkins pg_num 16 pgp_num 16 autoscale_mode on last_change 37 lfor 0/0/21 flags hashpspool stripe_width 0 pg_autoscale_bias 4 pg_num_min 16 recovery_priority 5 application cephfs
pool 3 'myfs-replicated' replicated size 1 min_size 1 crush_rule 3 object_hash rjenkins pg_num 32 pgp_num 32 autoscale_mode on last_change 23 lfor 0/0/21 flags hashpspool stripe_width 0 application cephfs
pool 4 'replicapool' replicated size 1 min_size 1 crush_rule 4 object_hash rjenkins pg_num 32 pgp_num 32 autoscale_mode on last_change 49 lfor 0/0/47 flags hashpspool,selfmanaged_snaps stripe_width 0 application rbd

```

##### Show Pool and total usage
```shell 
bash-4.4$ rados df


POOL_NAME           USED  OBJECTS  CLONES  COPIES  MISSING_ON_PRIMARY  UNFOUND  DEGRADED  RD_OPS       RD  WR_OPS       WR  USED COMPR  UNDER COMPR
.mgr             452 KiB        2       0       2                   0        0         0     672  1.2 MiB     297  2.9 MiB         0 B          0 B
myfs-metadata     40 KiB       22       0      22                   0        0         0  863979  422 MiB      34   30 KiB         0 B          0 B
myfs-replicated      0 B        0       0       0                   0        0         0       0      0 B       0      0 B         0 B          0 B
replicapool      146 MiB      105       0     105                   0        0         0    3578   19 MiB   44680  450 MiB         0 B          0 B

total_objects    129
total_used       560 MiB
total_avail      511 GiB
total_space      512 GiB
```

### Setting the Ceph Orchestrator

It is possible to set Rook as the Ceph Orchestrator backend, allowing the dashboard to provide more complete Kubernetes cluster-related information.

In the toolbox pod, simply run the following

```bash
ceph mgr module enable rook
ceph orch set backend rook
```

From the dashboard, it is now possible to access the `Services` tab, or to display the name of the OSD's node.

### Dashboard password modification

From the toolbox pod, begin by moving into the home folder and creating a file containing the password you wish to use:

```bash
cd
echo p@ssword123 > psswd
ceph dashboard ac-user-set-password admin -i psswd
```

This set of operations stores the password you desire to use in a local file, as the `ac-user-set-password` command sets the new password from a file. Change the content of the `psswd` file to a password of your choosing.

- This password must be secure enough to be accepted by the dashboard tool, with default settings.

It is now possible to access the dashboard using the updated credentials.
