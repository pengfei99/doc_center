#!/bin/bash

# This function first checks if the provided group exists in the AD. If not abort. If exist, it creates a
# project dir with the given project name. Then it sets ownership as hadoop:group.
# Then it applies the folder acl and default acl
apply_hdfs_policy() {
    local PROJECT=$1
    local GROUP=$2
    local DIR="/projects/$PROJECT"
    local ADMIN_USER="hadoop"
    # user::rwx (Owner)
    # group::rwx (project group have all rights)
    # other::--- (Strictly no access for others)
    # We include 'mask' to ensure the group 'rwx' is actually effective.
    local ACL_SPEC="user::rwx,group::rwx,other::---,mask::rwx,default:user::rwx,default:group::rwx,default:other::---,default:mask::rwx"

    # 1. Check if the AD Group exists
    if ! getent group "$GROUP" > /dev/null 2>&1; then
        echo "Error: Group '$GROUP' not found in AD/System. Skipping project '$PROJECT' creation."
        return 1
    fi

    echo "--- Provisioning Project: $PROJECT (Group: $GROUP) ---"

    # 2. Create the directory
    if ! hdfs dfs -mkdir -p "$DIR"; then
        echo "Error: Failed to create HDFS directory $DIR. Exiting program"
        return 1
    fi

    # 3. Set Ownership (hadoop:project_group)
    hdfs dfs -chown "$ADMIN_USER:$GROUP" "$DIR"

    # 4. Set Base Permissions (770)
    hdfs dfs -chmod 770 "$DIR"

    # 5. Apply ACLs and Default ACLs
    if hdfs dfs -setfacl -m "$ACL_SPEC" "$DIR"; then
        echo "Successfully configured $DIR for group $GROUP"
    else
        echo "Error: Failed to set ACLs on $DIR"
        return 1
    fi
}

# Variable initialization for getopts
PROJ_NAME=""
GROUP_NAME=""

# Parse Arguments
while getopts "p:g:f:" opt; do
  case $opt in
    p) PROJ_NAME="$OPTARG" ;;
    g) GROUP_NAME="$OPTARG" ;;
    f) FILE_PATH="$OPTARG" ;;
    *) echo "Usage: $0 [-p project -g group] | [-f csv_file]"; exit 1 ;;
  esac
done

# Logic for Single Project (-p and -g)
if [[ -n "$PROJ_NAME" && -n "$GROUP_NAME" ]]; then
    apply_hdfs_policy "$PROJ_NAME" "$GROUP_NAME"

# Logic for File Input (-f)
elif [[ -n "$FILE_PATH" ]]; then
    if [[ -f "$FILE_PATH" ]]; then
        while IFS=',' read -r f_project f_group || [[ -n "$f_project" ]]; do
            # Strip whitespace and carriage returns
            p_clean=$(echo "$f_project" | tr -d '\r' | xargs)
            g_clean=$(echo "$f_group" | tr -d '\r'
            | xargs)

            # Skip comments or empty project names
            [[ -z "$p_clean" || "$p_clean" =~ ^# ]] && continue

            apply_hdfs_policy "$p_clean" "$g_clean"
        done < "$FILE_PATH"
    else
        echo "Error: File $FILE_PATH not found."
        exit 1
    fi

# Fallback for missing arguments
else
    echo "Usage Error:"
    echo "  Single: $0 -p <project_name> -g <group_name>"
    echo "  Batch:  $0 -f <csv_file> (Format: project,group)"
    exit 1
fi

# usage example
# bash create_project_dir.sh -p project1 -g project1-group
# bash create_project_dir.sh -f projects.csv
# in the file projects.csv file, each row is a project entry, the 1st column is the project name, the 2nd column is the
# project group.
# if a row has error, the row will be skipped. the script continues with the next row.