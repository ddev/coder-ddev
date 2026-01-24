#!/bin/bash
# Simple test to see what headers Coder forwards to the workspace
# This will listen on port 80 and dump all incoming HTTP headers

PORT=${1:-80}

echo "=== Coder Host Header Test ==="
echo ""
echo "This script will listen on port $PORT and show you the HTTP headers"
echo "that Coder forwards when you access the port via Coder's app URL."
echo ""
echo "Steps:"
echo "1. Make sure DDEV is stopped: ddev stop --all"
echo "2. This script will start listening on port $PORT"
echo "3. Open your Coder dashboard and click the 'DDEV Web' app"
echo "4. The headers will be displayed below"
echo "5. Press Ctrl+C to stop"
echo ""

# Check if port is already in use
if sudo lsof -i :"$PORT" >/dev/null 2>&1; then
    echo "ERROR: Port $PORT is already in use!"
    echo ""
    echo "Running processes on port $PORT:"
    sudo lsof -i :"$PORT"
    echo ""
    echo "To stop DDEV: ddev stop --all"
    echo "To stop all containers: docker stop \$(docker ps -q)"
    exit 1
fi

echo "Starting listener on port $PORT..."
echo "=========================================="
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Run the Python server
if [ "$PORT" -lt 1024 ]; then
    sudo python3 "$SCRIPT_DIR/header-test-server.py" "$PORT"
else
    python3 "$SCRIPT_DIR/header-test-server.py" "$PORT"
fi
