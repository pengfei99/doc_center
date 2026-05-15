#!/usr/bin/env bash

# check if jupyter lab exists
if ! command -v jupyter >/dev/null 2>&1; then
    echo "Error: jupyter command not found. JupyterLab is not installed or not in PATH."
    echo "Error: If your jupyter is installed in a virtual environment, you need to activate the virtual env first"
    exit 1
fi

# verify jupyter lab subcommand exists
if ! jupyter lab --version >/dev/null 2>&1; then
    echo "Error: JupyterLab is not installed."
    echo "Error: If your jupyter is installed in a virtual environment, you need to activate the virtual env first"
    exit 1
fi

PORT=8888

# find first available port
while ss -lnt | awk '{print $4}' | grep -q ":$PORT$"; do
    echo "INFO: $PORT is used by another service."
    ((PORT++))
done

echo "INFO: Using port: $PORT"

jupyter lab --ip=0.0.0.0 --port="$PORT" --notebook-dir="$HOME" 2>&1 | while read -r line; do
    if [[ "$line" =~ http://[^[:space:]]+ ]]; then
        URL=$(echo "$line" | grep -o "http://[^[:space:]]*")

        # ignore localhost URL
        if [[ ! "$URL" =~ 127\.0\.0\.1 ]]; then
            echo "INFO: JupyterLab server runs with URL: $URL"
            echo "INFO: To stop the JupyterLab, use ctrl+C or close the terminal."
        fi
#    else
#      echo "$line"
    fi
done