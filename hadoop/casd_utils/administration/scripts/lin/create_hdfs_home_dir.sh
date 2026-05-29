#!/bin/bash
# ==============================================================================
# Script Name : create_hdfs_home_dir.sh
# Description : Multi-mode HDFS home folder provisioner (User, File, or Group)
# OS Target   : Debian 13 (Bookworm) / Enterprise Hadoop Edge Node
# ==============================================================================

# Hardening: Exit immediately if a standalone system command fails, and treat unset variables as an error.
set -euo pipefail

# --- Configuration ---
# the default group of user home folders. by default is the admin group
DEFAULT_GROUP="hadoop"
# the root dir of the user home folders in hdfs
HDFS_BASE_DIR="/users"

# --- Helper Functions ---

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

print_usage() {
    echo "Usage: $0 [-n username] | [-f filename] | [-g groupname]" >&2
    echo "  -n  Process a single OS/AD username"
    echo "  -f  Process a list of users from a file (one username per line)"
    echo "  -g  Process all users belonging to a specific system/AD group"
    exit 1
}

# this function returns all users of a given group as a unique list
# it resolves both primary and supplementary members of a group
resolve_group_members() {
    local TARGET_GROUP=$1
    local GROUP_DATA

    # Fetch group database record from NSS with getent group command
    # but this will not return the users which has target_group as primary group
    if ! GROUP_DATA=$(getent group "$TARGET_GROUP"); then
        log_error "Group '$TARGET_GROUP' not found in system databases or AD."
        return 1
    fi

    # Extract numeric Group ID (GID) and users list from the output of getent
    local GID
    local SUPPLEMENTARY_RAW
    GID=$(echo "$GROUP_DATA" | cut -d: -f3)
    SUPPLEMENTARY_RAW=$(echo "$GROUP_DATA" | cut -d: -f4)

    # Use an associative array locally to guarantee a unique, deduplicated list
    declare -A UNIQUE_MEMBERS

    # parse the raw csv like user list into the UNIQUE_MEMBERS
    if [[ -n "$SUPPLEMENTARY_RAW" ]]; then
        local -a supp_users
        IFS=',' read -r -a supp_users <<< "$SUPPLEMENTARY_RAW"
        for user in "${supp_users[@]}"; do
            local user_clean
            user_clean=$(echo "$user" | tr -d '[:space:]')
            if [[ -n "$user_clean" ]]; then
                UNIQUE_MEMBERS["$user_clean"]=1
            fi
        done
    fi

    # get the users who has target_group as primary group
    while IFS=: read -r passwd_user _ _ user_gid _; do
        if [[ "$user_gid" == "$GID" ]]; then
            UNIQUE_MEMBERS["$passwd_user"]=1
        fi
    done < <(getent passwd)

    # Output the deduplicated usernames separated by spaces
    echo "${!UNIQUE_MEMBERS[@]}"
}

# this function will create user home dir and set up associated ACLs.
apply_hdfs_policy() {
    local USER=$1
    local DIR="${HDFS_BASE_DIR}/${USER}"

    # Secure POSIX/HDFS ACL Definition. Mask must be at least r-x to prevent wiping out group access.
    local ACL="user::rwx,group::r-x,other::---,mask::r-x,default:user::rwx,default:group::r-x,default:other::---,default:mask::r-x"

    log_info "Processing User: $USER"

    # 1. Check if user exists in the system (Local or AD via SSSD)
    if ! getent passwd "$USER" > /dev/null 2>&1; then
        log_error "User '$USER' does not exist in AD/OS. Skipping."
        return 1
    fi

    # 2. Check if the user home directory already exists in HDFS
    if hdfs dfs -test -d "$DIR" 2>/dev/null; then
        log_error "The HDFS directory '$DIR' already exists. Skipping creation."
        return 1
    fi

    # 3. Create directory
    if ! hdfs dfs -mkdir -p "$DIR"; then
        log_error "Failed to create HDFS directory: $DIR"
        return 1
    fi

    # 4. Set Ownership (User:Group)
    if ! hdfs dfs -chown "$USER:$DEFAULT_GROUP" "$DIR"; then
        log_error "Failed to set ownership to $USER:$DEFAULT_GROUP on $DIR. Cleaning up..."
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

# ----- Script entry point ----

# --- 1. Pre-flight Checks ---

# Ensure critical binaries exist before proceeding
for cmd in getent hdfs cut sort; do
    if ! command -v "$cmd" &> /dev/null; then
        log_error "Required system command '$cmd' is missing from PATH. Aborting."
        exit 1
    fi
done

# --- 2. Arguments Checks ---

# If no arguments provided, show usage
if [[ $# -eq 0 ]]; then
    print_usage
fi

# --- 3. Main Argument Parsing ---

SINGLE_USER=""
FILE_PATH=""
GROUP_TARGET=""

while getopts "n:f:g:" opt; do
    case $opt in
        n) SINGLE_USER="$OPTARG" ;;
        f) FILE_PATH="$OPTARG" ;;
        g) GROUP_TARGET="$OPTARG" ;;
        *) print_usage ;;
    esac
done

# --- 4. Execution Path selections ---

# Mode 1: Single User Execution (-n)
if [[ -n "$SINGLE_USER" ]]; then
    CLEAN_USER=$(echo "$SINGLE_USER" | tr -d '[:space:]')
    if [[ -n "$CLEAN_USER" ]]; then
        # For a single user, we let it return its natural exit code
        apply_hdfs_policy "$CLEAN_USER"
    fi

# Mode 2: Batch Group Execution (-g)
elif [[ -n "$GROUP_TARGET" ]]; then
    CLEAN_GROUP=$(echo "$GROUP_TARGET" | tr -d '[:space:]')
    log_info "Resolving membership for system/AD group: $CLEAN_GROUP"

    if RESOLVED_USERS=$(resolve_group_members "$CLEAN_GROUP"); then
        if [[ -z "$RESOLVED_USERS" ]]; then
            log_info "Group '$CLEAN_GROUP' exists but contains no active users. Exiting cleanly."
            exit 0
        fi

        # Iterate over the resolved user array
        for resolved_user in $RESOLVED_USERS; do
            # CRITICAL FIX: Wrapped in an "if" statement.
            # This safely intercepts the 'return 1' from missing users, logging it
            # and allowing the loop to advance without triggering 'set -e'.
            if ! apply_hdfs_policy "$resolved_user"; then
                log_error "Skipping to next user in group due to policy failure on '$resolved_user'."
            fi
            echo "------------------------------------------------"
        done
    else
        log_error "Failed to safely resolve group members for '$CLEAN_GROUP'."
        exit 1
    fi

# Mode 3: Batch Flat File Execution (-f)
elif [[ -n "$FILE_PATH" ]]; then
    if [[ -f "$FILE_PATH" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            CLEAN_LINE=$(echo "$line" | tr -d '[:space:]\r')

            # Skip empty lines or commented-out lines
            [[ -z "$CLEAN_LINE" || "$CLEAN_LINE" =~ ^# ]] && continue

            # CRITICAL FIX: Wrapped in an "if" statement for file processing as well.
            if ! apply_hdfs_policy "$CLEAN_LINE"; then
                log_error "Skipping to next line due to policy failure on '$CLEAN_LINE'."
            fi
            echo "------------------------------------------------"
        done < "$FILE_PATH"
    else
        log_error "Input file '$FILE_PATH' not found."
        exit 1
    fi

else
    print_usage
fi