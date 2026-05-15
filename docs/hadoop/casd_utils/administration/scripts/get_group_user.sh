#!/bin/bash
# ==============================================================================
# Script Name : list_group_members.sh
# Description : Efficiently resolve all members of a group (Primary & Supplementary)
# OS Target   : Debian 13 (Bookworm)
# ==============================================================================

# Hardening: Exit on error, treat unset variables as errors, fail pipelines early
set -euo pipefail

# --- Helper Functions ---

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

print_usage() {
    echo "Usage: $0 -g <group_name>" >&2
    exit 1
}

# --- Initialization & Argument Parsing ---

GROUP_NAME=""

while getopts "g:" opt; do
    case "$opt" in
        g) GROUP_NAME="$OPTARG" ;;
        *) print_usage ;;
    esac
done

# Ensure group argument is not empty
if [[ -z "$GROUP_NAME" ]]; then
    print_usage
fi

# Ensure critical system binaries are present
for cmd in getent awk; do
    if ! command -v "$cmd" &> /dev/null; then
        log_error "Required system utility '$cmd' is missing from PATH."
        exit 1
    fi
done

# --- Core Logic ---

# 1. Fetch group database record safely
if ! GROUP_DATA=$(getent group "$GROUP_NAME"); then
    log_error "Group '$GROUP_NAME' not found in system databases (Local/NSS)."
    exit 1
fi

# Extract the numeric Group ID (GID) from the 3rd field
GID=$(echo "$GROUP_DATA" | cut -d: -f3)

# Extract the raw CSV supplementary user list from the 4th field
SUPPLEMENTARY_RAW=$(echo "$GROUP_DATA" | cut -d: -f4)

# Use an associative array to guarantee a unique, deduplicated list of users
declare -A UNIQUE_MEMBERS

# 2. Process Supplementary Members (Users explicitly listed in the group record)
if [[ -n "$SUPPLEMENTARY_RAW" ]]; then
    # Convert comma-separated string into a native Bash array safely
    IFS=',' read -r -a supp_users <<< "$SUPPLEMENTARY_RAW"
    for user in "${supp_users[@]}"; do
        # Clean up any accidental leading/trailing whitespace using regex stripping
        user_clean=$(echo "$user" | tr -d '[:space:]')
        if [[ -n "$user_clean" ]]; then
            UNIQUE_MEMBERS["$user_clean"]=1
        fi
    done
fi

# 3. Process Primary Members (Users who have this GID as their default login group)
# We scan passwd entries where the 4th field matches our GID
while IFS=: read -r passwd_user _ _ user_gid _; do
    if [[ "$user_gid" == "$GID" ]]; then
        UNIQUE_MEMBERS["$passwd_user"]=1
    fi
done < <(getent passwd)

# --- Output Generation ---

# Print out the deduplicated results sorted alphabetically
if [[ ${#UNIQUE_MEMBERS[@]} -eq 0 ]]; then
    echo "Group '$GROUP_NAME' exists, but contains no active users."
else
    printf '%s\n' "${!UNIQUE_MEMBERS[@]}" | sort
fi