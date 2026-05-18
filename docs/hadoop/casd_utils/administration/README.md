# D1MUTUA administration

The projet `D1MUTUA` has a Windows server, users already have groups defined in AD and associated projet data directory
hierarchy defined in the Windows server. 

For the administrator, you have three main tasks:
1. apply user identity and groups of the Windows server(AD) to the Linux servers.
2. configure `D1MUTUA` Windows server to allow user to connect and transferring data to the Linux servers
The second is to create the same projet data directory hierarchy on HDFS and set the same ACL on HDFS as in the Windows server.

## User auth and groups synchronization

The `user authentication` is done via `ticket Kerberos`. For example when user connect to linux server via ssh,
The authentication process `ssh client -> sshd -> PAM -> sssd -> Kerberos -> AD`

The groups synchronization is done via `sssd` and `Name Service Switch (NSS)`. When a user is connected, a user 
lookup will be initiated to get user groups. By default, without NSS, the system checks `/etc/passwd` only. With NSS, 
the system can do `user lookup -> files(/etc/passwd) -> sssd -> ldap/AD -> …`

## HDFS folder setup

In HDFS, we will create two types of folders:
- user home folder: user personal folder to store private data
- projet folder: project data folder shared between all users of the project

> For now, we decided all users in group `d1mutua` are allowed to use the hdfs folder (e.g. ssh access, hdfs home folder)


```shell
# get members of a given group
> getent group casd-ds

# output example
casd-ds:*:300001:toto,pliu-ad,titi,tata
```
```shell
#!/bin/bash

# This function first checks if the user exists in the AD. If not abort.
# If the user exists, it checks if the user already have a home folder or not. If not abort.
# If the user does not have a home dir in the hdfs cluster, it creates a home dir for the user
# Then it applies the folder acl and default acl on the user home dir
apply_hdfs_policy() {
    local USER=$1
    # default home dir path
    local DIR="/users/$USER"
    # default principal group of the acl
    local GROUP="hadoop"
    # user::rwx (Owner)
    # group::r-x (Hadoop group can browse/read)
    # other::--- (Strictly no access for others)
    # mask::---  (The ceiling for non-owners)
    local ACL="user::rwx,group::r-x,other::---,mask::---,default:user::rwx,default:group::r-x,default:other::---,default:mask::---"

    # 1. Check if user exists in the system
    if ! getent passwd "$USER" > /dev/null 2>&1; then
        echo "Error: User '$USER' does not exist in the AD. Skipping the home directory creation."
        return 1
    fi

    # 2. check if the user home directory exist or not
    if hdfs dfs -test -d "$DIR"; then
            echo "Error: The user directory '$DIR' exit already. Skipping user home creation for '$USER'"
            return 1
    fi

    echo "--- Processing User: $USER ---"

    # 3. Create directory
    if ! hdfs dfs -mkdir -p "$DIR"; then
        echo "Error: Failed to create HDFS directory $DIR"
        return 1
    fi

    # 4. Set Ownership (User:AdminGroup)
    hdfs dfs -chown "$USER:$GROUP" "$DIR"

    # 5. Set Base Permissions (750)
    hdfs dfs -chmod 750 "$DIR"

    # 6. Apply ACLs and Default ACLs

    hdfs dfs -setfacl -m "$ACL" "$DIR"
    echo "INFO: ACL policy applied successfully for $USER."
}

# Main script usage example
# bash create_home_dir.sh -n pengfei
# bash create_home_dir.sh -f users.txt
# The users.txt contains only one column which is the user name without header
# Parse Arguments
while getopts "n:f:" opt; do
  case $opt in
    n)
      apply_hdfs_policy "$OPTARG"
      ;;
    f)
      if [[ -f "$OPTARG" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
          # Skip empty lines or comments
          [[ -z "$line" || "$line" =~ ^# ]] && continue
          apply_hdfs_policy "$line"
        done < "$OPTARG"
      else
        echo "Error: File $OPTARG not found."
        exit 1
      fi
      ;;
    *)
      echo "Usage: $0 [-n username] [-f filename]"
      exit 1
      ;;
  esac
done

# If no arguments provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 [-n username] [-f filename]"
    exit 1
fi



```