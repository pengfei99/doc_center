#!/usr/bin/env bash

# Enable Bash strict mode for robust error handling
set -euo pipefail

# --- Configuration ---
DEFAULT_PORT=8888
BIND_IP="0.0.0.0"
NOTEBOOK_DIR="$HOME"
LOG_FILE=$(mktemp /tmp/jupyter_launch.XXXXXX.log)
JUPYTER_PID=0
TAIL_PID=0

# --- Structured Logging Helpers ---
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

# --- Centralized Cleanup Function ---
cleanup() {
    # Preserve the exit status code of the preceding command
    local exit_code=$?

    # Check if a background tail process is active and terminate it cleanly
    if [ -n "${TAIL_PID:-}" ] && [ "$TAIL_PID" -gt 0 ] && kill -0 "$TAIL_PID" 2>/dev/null; then
        kill "$TAIL_PID" 2>/dev/null || true
    fi

    # Check if the primary Jupyter daemon process is active and terminate it
    if [ -n "${JUPYTER_PID:-}" ] && [ "$JUPYTER_PID" -gt 0 ] && kill -0 "$JUPYTER_PID" 2>/dev/null; then
        log_info "Stopping JupyterLab server (PID: $JUPYTER_PID)..."
        kill "$JUPYTER_PID" 2>/dev/null || true
    fi

    # Sweep and purge the runtime temporary logfile from /tmp
    if [ -f "$LOG_FILE" ]; then
        rm -f "$LOG_FILE"
    fi

    exit "$exit_code"
}

# Bind ALL critical termination signals to your centralized cleanup function
trap 'cleanup' INT TERM EXIT


echo "=== JupyterLab Startup Manager ==="

# 1. Dependency & Environment Checks
if ! command -v jupyter >/dev/null 2>&1; then
    log_error "'jupyter' command not found in PATH."
    log_info "Hint: You need to activate virtual env first. Try to run: 'source /path/to/venv/bin/activate'"
    exit 1
fi

if ! jupyter lab --version >/dev/null 2>&1; then
    log_error "'jupyter' is available, but the 'lab' extension is missing."
    exit 1
fi

# 2. Dynamic Port Selection
# Uses 'ss' reliably, handling both IPv4 and IPv6 syntax boundaries safely
PORT=$DEFAULT_PORT
while ss -tlnp 2>/dev/null | grep -qE "(:$PORT |\]:$PORT )"; do
    log_info "Port $PORT is already in use."
    ((PORT++))
done

log_info "Selected available port: $PORT"

# 3. Launching Jupyter Lab Safely
# We redirect stderr/stdout to a logfile so we can parse the token without
# trapping the interactive process in a continuous pipeline.
log_info "Starting JupyterLab..."
jupyter lab --ip="$BIND_IP" --port="$PORT" --notebook-dir="$NOTEBOOK_DIR" --no-browser > "$LOG_FILE" 2>&1 &
JUPYTER_PID=$!

log_info "Details server log can be found at $LOG_FILE"
log_info "The jupyter server pid is: $JUPYTER_PID"


# 4. Extracting Access URL and Token
# Loop until the server writes the URL token block to the log (timeout after 10 seconds)
# counter init value can't be 0, because ((COUNTER++)) will return 1 and cause system to stop
COUNTER=2
URL_FOUND=""
while [ $COUNTER -lt 20 ]; do
    sleep 0.5

    # Check if the file actually has content yet
    if [ -s "$LOG_FILE" ]; then
        # Use awk to find the HTTP URL that DOES NOT contain 127.0.0.1 or localhost
        # This avoids pipeline breaking under 'set -o pipefail'
        URL_FOUND=$(awk '
            /http:\/\/[:/[_a-zA-Z0-9.-]+/ {
                for (i=1; i<=NF; i++) {
                    if ($i ~ /^http:\/\// && $i !~ /127\.0\.0\.1/ && $i !~ /localhost/) {
                        print $i;
                        exit;
                    }
                }
            }
        ' "$LOG_FILE")

        if [ -n "$URL_FOUND" ]; then
            break
        fi
    fi
    ((COUNTER++))
done

# 5. Handover Control to User
if [ -n "$URL_FOUND" ]; then
    echo -e "\n========================================================="
    echo "JupyterLab is running and accessible externally!"
    echo "URL: $URL_FOUND"
    echo "========================================================="
    echo "To stop the server, press Ctrl+C in this terminal."
else
    echo "Warning: Jupyter started, but could not parse the external URL from logs."
    echo "Checking raw logs for tokens..."
    grep -E "http://|token=" "$LOG_FILE" || true
fi

# Asynchronously pipe background runtime error logs out to standard terminal streams
tail -n +1 -f "$LOG_FILE" | grep -i "error" &
TAIL_PID=$!

# Keep script executing in foreground without blocking signals.
# Passing no parameters to 'wait' allows bash traps to process immediately.
while kill -0 "$JUPYTER_PID" 2>/dev/null; do
    wait -n || true
done