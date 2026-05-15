#!/bin/bash

GROUP="hadoop"
OUTFILE="hadoop_users.txt"

ENTRY=$(getent group "$GROUP")

if [ -z "$ENTRY" ]; then
    echo "Group $GROUP not found"
    exit 1
fi

MEMBERS=$(echo "$ENTRY" | cut -d: -f4)

: > "$OUTFILE"

if [ -n "$MEMBERS" ]; then
    echo "$MEMBERS" | tr ',' '\n' >> "$OUTFILE"
fi

echo "User list saved to $OUTFILE"