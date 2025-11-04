#!/bin/bash
#
# Hub Load Test Runner
# Usage: ./run_load_test.sh [background|foreground]
#

set -e  # Exit on error

# Determine run mode
RUN_MODE="${1:-foreground}"

# Load debug configuration
source src/hub_load/config/debug_mixed_scans.sh

# Set test parameters
export API_TOKEN="${API_TOKEN:?Error: API_TOKEN must be set}"
export BD_HUB_URL="${BD_HUB_URL:?Error: BD_HUB_URL must be set}"
export PARALLEL_SCANS=yes
export MAX_PARALLEL_JOBS=4
export MAX_SCANS=480
export TEST_DURATION=8

echo "==============================================="
echo "Hub Load Test Configuration"
echo "==============================================="
echo "Mode: $RUN_MODE"
echo "Hub URL: $BD_HUB_URL"
echo "Max Scans: $MAX_SCANS"
echo "Max Parallel: $MAX_PARALLEL_JOBS"
echo "Test Duration: ${TEST_DURATION}h"
echo "==============================================="

# Run based on mode
if [ "$RUN_MODE" == "background" ]; then
    echo "Starting in background mode..."
    nohup ./src/hub_load/core/hub_load_main.sh > scans.log 2>&1 &
    PID=$!
    echo "Started with PID: $PID"
    echo "Monitor with: tail -f scans.log"
    echo "Stop with: kill $PID"
else
    echo "Starting in foreground mode..."
    ./src/hub_load/core/hub_load_main.sh 2>&1 | tee scans.log
fi
