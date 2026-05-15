#!/bin/bash
# ==============================================================================
# Script Name : create_hdfs_project_dir.sh
# Description : Provision secure HDFS directories mapped to Active Directory groups
# OS Target   : Debian 13 (Bookworm) / Enterprise Linux
# ==============================================================================

# Fail immediately if any command in a pipeline fails, or if an unset variable is used.
set -euo pipefail

# --- Configuration Constants ---
ADMIN_USER="hadoop"
HDFS_BASE_DIR="/projects"

# --- Structured Logging Helpers ---
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

print_usage() {
    echo "Usage Error:" >&2
    echo "  Single Project: $0 -p <project_name> -g <group_name>" >&2
    echo "  Batch Mode    : $0 -f <csv_file>     (Format: project,group)" >&2
    exit 1
}

# --- Core Business Logic ---
apply_hdfs_policy() {
    local PROJECT=$1
    local GROUP=$2
    local DIR="${HDFS_BASE_DIR}/${PROJECT}"

    # user::rwx (Owner)
    # group::rwx (project group have all rights)
    # other::--- (Strictly no access for others)
    # Mask is set to rwx to guarantee the group permissions are fully effective.
    local ACL_SPEC="user::rwx,group::rwx,other::---,mask::rwx,default:user::rwx,default:group::rwx,default:other::---,default:mask::rwx"

    log_info "Starting provisioning for project '${PROJECT}' mapped to group '${GROUP}'"

    # 1. Active Directory / OS Group Validation
    if ! getent group "$GROUP" > /dev/null 2>&1; then
        log_error "AD Group '${GROUP}' does not exist on this host. Skipping project '${PROJECT}'."
        return 1
    fi

    # 2. Existing Directory Check
    if hdfs dfs -test -d "$DIR" 2>/dev/null; then
        log_error "HDFS path '${DIR}' already exists. Skipping allocation to avoid clobbering permissions."
        return 1
    fi

    # 3. Directory Creation
    if ! hdfs dfs -mkdir -p "$DIR"; then
        log_error "Failed to create HDFS directory structure: ${DIR}"
        return 1
    fi

    # 4. Secure Ownership Assignment (Atomic Rollback Guard)
    if ! hdfs dfs -chown "$ADMIN_USER:$GROUP" "$DIR"; then
        log_error "Failed to set ownership to ${ADMIN_USER}:${GROUP} on ${DIR}. Rolling back..."
        hdfs dfs -rmdir "$DIR" 2>/dev/null || log_error "Rollback failed! Manual cleanup required for ${DIR}"
        return 1
    fi

    # 5. Base Permissions Enforcement (770)
    if ! hdfs dfs -chmod 770 "$DIR"; then
        log_error "Failed to enforce base permissions (770) on ${DIR}."
        return 1
    fi

    # 6. ACL and Inheritance Matrix Configuration
    if ! hdfs dfs -setfacl -m "$ACL_SPEC" "$DIR"; then
        log_error "Failed to apply Extended and Default ACL matrices on ${DIR}."
        return 1
    fi

    log_info "Successfully provisioned and hardened project space: ${DIR}"
    return 0
}

# --- Environment Pre-flight Validation ---
for cmd in getent hdfs; do
    if ! command -v "$cmd" &> /dev/null; then
        log_error "Missing required system binary: '$cmd'. Ensure Hadoop environment is sourced. Aborting."
        exit 1
    fi
done

# --- Initialization & Argument Parsing ---
PROJ_NAME=""
GROUP_NAME=""
FILE_PATH=""

while getopts "p:g:f:" opt; do
    case $opt in
        p) PROJ_NAME="$OPTARG" ;;
        g) GROUP_NAME="$OPTARG" ;;
        f) FILE_PATH="$OPTARG" ;;
        *) print_usage ;;
    esac
done

# --- Main script Execution Entrypoint ---
# Main script usage example
# bash create_project_dir.sh -p project1 -g project1-group
# bash create_project_dir.sh -f projects.csv
# in the file projects.csv file, each row is a project entry, the 1st column is the project name, the 2nd column is the
# project group.
# if a row has error, the row will be skipped. the script continues with the next row.

# Scenario A: Single Mode Execution
if [[ -n "$PROJ_NAME" && -n "$GROUP_NAME" ]]; then
    # Direct input cleanup
    p_clean=$(echo "$PROJ_NAME" | tr -d '[:space:]\r')
    g_clean=$(echo "$GROUP_NAME" | tr -d '[:space:]\r')

    apply_hdfs_policy "$p_clean" "$g_clean"

# Scenario B: Batch CSV Processing Mode
elif [[ -n "$FILE_PATH" ]]; then
    if [[ ! -f "$FILE_PATH" ]]; then
        log_error "Target batch file not found: ${FILE_PATH}"
        exit 1
    fi

    ROW_COUNT=0
    while IFS=',' read -r raw_project raw_group || [[ -n "$raw_project" ]]; do
        ((ROW_COUNT++))

        # Thoroughly sanitize strings from trailing white spaces, tabs, and Windows CR (\r)
        p_clean=$(echo "$raw_project" | tr -d '[:space:]\r')
        g_clean=$(echo "$raw_group"    | tr -d '[:space:]\r')

        # 1. Skip comments and empty entries safely
        [[ -z "$p_clean" || "$p_clean" =~ ^# ]] && continue

        # 2. Automatically skip standard CSV header rows dynamically
        if [[ "$ROW_COUNT" -eq 1 && "${p_clean,,}" == "project" && "${g_clean,,}" == "group" ]]; then
            log_info "CSV Header row detected and skipped successfully."
            continue
        fi

        # 3. Protect against malformed data arrays (e.g., missing comma)
        if [[ -z "$p_clean" || -z "$g_clean" ]]; then
            log_error "Malformed CSV entry at line ${ROW_COUNT}: Raw='${raw_project},${raw_group}'. Skipping."
            continue
        fi

        apply_hdfs_policy "$p_clean" "$g_clean"
        echo "------------------------------------------------========================"
    done < "$FILE_PATH"

# Scenario C: Invalid Usage Options
else
    print_usage
fi