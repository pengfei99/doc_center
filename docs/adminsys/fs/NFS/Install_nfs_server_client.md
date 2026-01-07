# Set Up an NFS Server and client on Debian 11


**NFS, or Network File System**, is a distributed file system protocol that allows you to mount remote directories on 
your server. This allows you to manage storage space in a different location and write to that space from multiple 
clients. NFS provides a relatively standard and performant way to access remote systems over a network and works 
well in situations where the shared resources must be accessed regularly.

In this guide, we will see how to install the NFS server and client on Debian 11.

## 0. Prerequisites

You need to have two servers:
- server: nfs.casd.local(10.50.5.72)
- client: client.casd.local(10.50.*.*)

## 1. Install the nfs server

```shell
sudo apt update
sudo apt install nfs-kernel-server
```

### 1.1 Create sharing folder
We need to create share folders to host the shared files. In this tutorial, we choose one folder **/nfs/share**.

```shell
sudo mkdir -p /nfs/share
```

Since you’re creating the directory with sudo, the directory is owned by the host’s root user. It's recommended to not 
use root user. So we create a custom account for the share folder

```shell
# add a new group nfs 
sudo groupadd nfs

# add a new user with group nfs
sudo useradd nfs -g nfs

# change folder owner
sudo chown -R nfs:nfs /nfs/share
```

### 1.2 Configuring the NFS Exports on the Host Server

The main configuration file of the nfs server is **/etc/exports**, it defines which folder will be shared, and which
client can access it with which rights.

Below is the explanation of the content of the /etc/exports

```shell
# general form
directory_to_share    client_ip(share_option1,...,share_optionN)

# some example
/nfs/share  10.50.5.108(rw,async)
/nfs/share  10.50.0.0/16(rw,sync,no_root_squash,no_subtree_check)
```

If we only want one client which is able to connect to nfs server, we can use the simple client IP address.

If we want many clients, we can use an ip address with subnet mask. For example 10.50.0.0/16 means all IP within 
`10.50.*.*` is authorized to access the nfs server.

share_options:
- **rw**: This option gives the client computer both read and write access to the volume.
- **sync**: This option forces NFS to write changes to disk before replying. This results in a more stable and 
             consistent environment since the reply reflects the actual state of the remote volume. However, it also 
              reduces the speed of file operations. The counter part option is **async**
- **no_subtree_check**: This option prevents subtree checking, which is a process where the host must check whether 
                the file is actually still available in the exported tree for every request. This can cause many 
                 problems when a file is renamed while the client has it opened. In almost all cases, `it is better to 
                 disable subtree checking`.
- **no_root_squash**: By default, NFS translates requests from a root user remotely into a non-privileged user on 
               the server. This was intended as security feature to prevent a root account on the client from using 
                the file system of the host as root. no_root_squash disables this behavior for certain shares.


After the configuration, you need to restart the service to activate the new configuration

After install, you can manage the nfs-server service with below command(nfs-kernel-server, nfs-server work both)

```shell
sudo systemctl status nfs-server 
sudo systemctl restart nfs-server
sudo systemctl stop nfs-server
```

## 2. Install nfs client on client machine

```shell
# Install nfs client
sudo apt install nfs-common 
```

## 3. Create the mount point folder and mount the nfs share folder

Run the below command on the client machine 
```shell
# Create the mount point folder
sudo mkidr -p /mnt/nfs

# general form mount the nfs share folder
sudo mount nfs_server_url:/path/to/share path/to/mount_pont

# in our example
sudo mount 10.50.5.72:/nfs/share /mnt/nfs

# check the mounted point
df -h
```

## 4. Test the nfs access

```shell
# read the file in nfs mount
cat /mnt/nfs/file1.txt 

# try to write the file
vim /mnt/nfs/file1.txt

# try to delete the file
```

> if you set the no_root_squash option, it means the client with root privilege on the local server can edit the files
  in nfs server. It's not recommended by default 
> 
## 5. Mount nfs at Boot

We can mount the remote NFS shares automatically at boot by adding the nfs config to the **/etc/fstab** file on the 
client machine.

Open the **/etc/fstab** file with root privileges in your text editor.

```shell
# edit the fstab
sudo vim /etc/fstab

# General conf form, here file_system_type is nfs
host_ip:/path/to/host_share_folder    /path/local_mount_folder   file_system_type  nfs_mount_options

# some example
10.50.5.72:/nfs/share /mnt/nfs nfs auto,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0

# you can validate the fstab conf with the below command
sudo mount -a

```

> To get all possible nfs mount options, you can use `man nfs`

## 6. Unmount the nfs file system

```shell
sudo unmount /mnt/nfs
```