# Project maintenance

## 1. Create user home folder in hdfs

We provide a bash script `create_home_dir.sh` to generate user home folder in hdfs. You can change it to adapt it for your requirements.

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

To use this script

```shell
# for a single user
bash create_home_dir.sh -n pengfei

# for a list of users
bash create_home_dir.sh -f users.txt
```

The `users.txt` can be edited manually. If they are belongs to a `group`, you can use the following script `get_users_of_group.sh` to generate
the users.txt

```shell
#!/bin/bash

# Function to show how to use the script
usage() {
    echo "Usage: $0 -g <group_name>"
    exit 1
}

# Parse the -g option
while getopts "g:" opt; do
    case $opt in
        g) GROUP_NAME="$OPTARG" ;;
        *) usage ;;
    esac
done

# Check if group name was provided
if [ -z "$GROUP_NAME" ]; then
    usage
fi

# Fetch group info
GROUP_DATA=$(getent group "$GROUP_NAME")

# Check if the group exists
if [ -z "$GROUP_DATA" ]; then
    echo "Error: Group '$GROUP_NAME' not found."
    exit 1
fi

# Parse the output:
# -F'[:,]' sets delimiters to both colon and comma
# The loop starts at field 4 (the user list)
echo "$GROUP_DATA" | awk -F'[:,]' '{
    for (i = 4; i <= NF; i++) {
        if ($i != "") print $i
    }
}'
```

To use the `get_users_of_group.sh`,

```shell
# show the users list
# 
bash get_users_of_group.sh -g <group-name>

# save the results in a file
bash get_users_of_group.sh -g <group-name> > users.txt
```


## 2. Create project dir in hdfs

## 3. Configure client ssh and scp under windows

## 4. 

