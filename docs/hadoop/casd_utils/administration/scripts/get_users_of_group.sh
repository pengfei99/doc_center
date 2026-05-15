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