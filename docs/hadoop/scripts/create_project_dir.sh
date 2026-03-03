#!/bin/bash

# This function first checks if the project group exists in the AD. If not abort. If exist, it creates a
# project dir for the given project name
# The it applies the folder acl and default acl
apply_hdfs_policy() {
    local PROJECT=$1
    local DIR="/projects/$PROJECT"
    local USER="hadoop"
    local GROUP=$1
    # user::rwx (Owner)
    # group::r-x (Hadoop group can browse/read)
    # other::--- (Strictly no access for others)
    # mask::---  (The ceiling for non-owners)
    local ACL="user::rwx,group::rwx,other::---,default:user::rwx,default:group::rwx,default:other::---"

    # 1. Check if user exists in the system
    if ! getent group "$GROUP" > /dev/null 2>&1; then
        echo "Error: GROUP '$GROUP' does not exist in the AD. Skipping the project directory creation."
        return 1
    fi

    echo "--- Creating Project directory: $PROJECT ---"

    # 2. Create directory
    if ! hdfs dfs -mkdir -p "$DIR"; then
        echo "Error: Failed to create HDFS directory $DIR"
        return 1
    fi

    # 3. Set Ownership (User:AdminGroup)
    hdfs dfs -chown "$USER:$GROUP" "$DIR"

    # 4. Set Base Permissions (750)
    hdfs dfs -chmod 770 "$DIR"

    # 5. Apply ACLs and Default ACLs

    hdfs dfs -setfacl -m "$ACL" "$DIR"

    echo "ACL policy applied successfully for project $PROJECT"
}

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

# usage example
# bash create_home_dir.sh -n pengfei
# bash create_home_dir.sh -f users.txt