#!/bin/bash
# ==============================================================================
# Script Name : create_hdfs_home_dir.sh
# Description : Provision secure HDFS directories for a given user
# OS Target   : Debian 13 (Bookworm) / Enterprise Linux
# ==============================================================================

# Exit immediately if a pipeline returns a non-zero status.
# Treat unset variables as an error.
set -uo pipefail

# --- Configuration ---
# default principal group of the user home folder, in our config hadoop is the admin group
DEFAULT_GROUP="hadoop"
HDFS_BASE_DIR="/users"

# --- help functions ---

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

print_usage() {
    echo "Usage: $0 [-n username] [-f filename]"
    echo "  -n  Process a single OS/AD username"
    echo "  -f  Process a list of users from a file (one username per line)"
    exit 1
}

# This function first checks if the user exists in the AD. If not abort.
# If the user exists, it checks if the user already have a home folder or not. If not abort.
# If the user does not have a home dir in the hdfs cluster, it creates a home dir for the user
# Then it applies the folder acl and default acl on the user home dir
apply_hdfs_policy() {
    local USER=$1
    # default home dir path
    local DIR="${HDFS_BASE_DIR}/${USER}"
    # user::rwx (Owner)
    # group::r-x (Hadoop group can browse/read)
    # other::--- (Strictly no access for others)
    # mask::r-x  (The ceiling for non-owners)
    local ACL="user::rwx,group::r-x,other::---,mask::r-x,default:user::rwx,default:group::r-x,default:other::---,default:mask::r-x"

    # 1. Check if user exists in the system
    if ! getent passwd "$USER" > /dev/null 2>&1; then
      log_error "User '$USER' does not exist in the AD. Skipping the home directory creation."
      return 1
    fi

    # 2. Check if the user home directory already exists
    if hdfs dfs -test -d "$DIR" 2>/dev/null; then
        log_error "The HDFS directory '$DIR' already exists. Skipping creation."
        return 1
    fi

    # 3. Create directory
    if ! hdfs dfs -mkdir -p "$DIR"; then
        log_error "Failed to create HDFS directory: $DIR"
        return 1
    fi

    # 4. Set Ownership (User:AdminGroup)
    # 4. Set Ownership (User:Group)
    if ! hdfs dfs -chown "$USER:$DEFAULT_GROUP" "$DIR"; then
        log_error "Failed to set ownership to $USER:$DEFAULT_GROUP on $DIR"
        # Attempt cleanup of empty dir to avoid orphaned unassigned states
        hdfs dfs -rmdir "$DIR" 2>/dev/null
        return 1
    fi

    # 5. Set Base Permissions (750)
    if ! hdfs dfs -chmod 750 "$DIR"; then
        log_error "Failed to set chmod 750 on $DIR"
        return 1
    fi

   # 6. Apply ACLs and Default ACLs
    if ! hdfs dfs -setfacl -m "$ACL" "$DIR"; then
        log_error "Failed to apply ACL policies on $DIR"
        return 1
    fi

    log_info "Successfully created and secured home directory for $USER."
    return 0
}

# --- Main Script Execution ---
# Main script usage example
# bash create_home_dir.sh -n pengfei
# bash create_home_dir.sh -f users.txt
# The users.txt contains only one column which is the user name without header
# we can also redirect logs to files
# bash create_home_dir.sh -f users.txt > success.log 2> error.log

# Ensure dependencies exist before running
for cmd in getent hdfs; do
    if ! command -v "$cmd" &> /dev/null; then
        log_error "Required command '$cmd' is missing. Aborting."
        exit 1
    fi
done

# If no arguments provided
if [[ $# -eq 0 ]]; then
    print_usage
fi

# Parse Arguments
while getopts "n:f:" opt; do
  case $opt in
    n)
      # Strip potential leading/trailing whitespace
      CLEAN_USER=$(echo "$OPTARG" | tr -d '[:space:]')
      [[ -n "$CLEAN_USER" ]] && apply_hdfs_policy "$CLEAN_USER"
      ;;
    f)
      if [[ -f "$OPTARG" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
          # 1. Strip Windows CR (\r) and whitespaces
          CLEAN_LINE=$(echo "$line" | tr -d '[:space:]\r')

          # 2. Skip empty lines or comments
          [[ -z "$CLEAN_LINE" || "$CLEAN_LINE" =~ ^# ]] && continue

          apply_hdfs_policy "$CLEAN_LINE"
          echo "------------------------------------------------"
        done < "$OPTARG"
      else
        log_error "File '$OPTARG' not found."
        exit 1
      fi
      ;;
    *)
      print_usage
      ;;
  esac
done


