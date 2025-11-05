#!/bin/bash
#
# run_multiple_tests.sh - Run multiple load test instances in parallel
#
# Usage:
#   ./run_multiple_tests.sh <num_instances>
#
# Example:
#   ./run_multiple_tests.sh 3    # Runs 3 instances in parallel
#

set -euo pipefail

NUM_INSTANCES=${1:-1}

# Common configuration
API_TOKEN="${API_TOKEN:-NTE2MmI0OTktZWYzYS00MDM0LWI2ZTQtNWRlMDg3ZjNmNjUyOjI1ZGFjNTI4LTBmZjYtNDAyNi04YjJlLTkyNDZmZmQwNjJlOQ==}"
BD_HUB_URL="${BD_HUB_URL:-https://rg-250sph-2025-7-1.saas-staging.blackduck.com}"
LOCAL_TEST_DATA_DIR="${LOCAL_TEST_DATA_DIR:-/netapp/eng/perflab/SCA_DATA/SCASS}"
MAX_SCANS="${MAX_SCANS:-480}"
MAX_PARALLEL_JOBS="${MAX_PARALLEL_JOBS:-4}"
TEST_DURATION="${TEST_DURATION:-8}"

echo "==============================================="
echo "🚀 STARTING MULTIPLE LOAD TEST INSTANCES"
echo "==============================================="
echo ""
echo "Configuration:"
echo "  • Number of instances: $NUM_INSTANCES"
echo "  • Scans per instance:  $MAX_SCANS"
echo "  • Parallel jobs:       $MAX_PARALLEL_JOBS"
echo "  • Test duration:       ${TEST_DURATION}h"
echo "  • Hub URL:             $BD_HUB_URL"
echo "  • Test data:           $LOCAL_TEST_DATA_DIR"
echo ""

# Create logs directory
LOGS_DIR="./test_runs/$(date '+%Y%m%d-%H%M%S')"
mkdir -p "$LOGS_DIR"

echo "Test Run Logs: $LOGS_DIR"
echo ""

# Track PIDs for cleanup
pids=()

# Start each instance
for i in $(seq 1 "$NUM_INSTANCES"); do
    INSTANCE_ID="test-instance-${i}"
    LOG_FILE="${LOGS_DIR}/instance-${i}.log"

    echo "[$i/$NUM_INSTANCES] Starting instance: $INSTANCE_ID"
    echo "           Log file: $LOG_FILE"

    # Start instance in background
    nohup bash -c "
        source src/hub_load/config/debug_mixed_scans.sh
        export INSTANCE_ID='$INSTANCE_ID'
        export API_TOKEN='$API_TOKEN'
        export BD_HUB_URL='$BD_HUB_URL'
        export MAX_PARALLEL_JOBS=$MAX_PARALLEL_JOBS
        export MAX_SCANS=$MAX_SCANS
        export TEST_DURATION=$TEST_DURATION
        export LOCAL_TEST_DATA_DIR='$LOCAL_TEST_DATA_DIR'
        export USE_GCS=no
        ./src/hub_load/core/hub_load_main.sh
    " > "$LOG_FILE" 2>&1 &

    pids+=($!)
    echo "           PID: ${pids[$((i-1))]}"
    echo ""

    # Small delay between starts to avoid startup conflicts
    sleep 2
done

echo "==============================================="
echo "✅ ALL INSTANCES STARTED"
echo "==============================================="
echo ""
echo "Instance PIDs: ${pids[*]}"
echo ""
echo "Monitor progress with:"
echo "  tail -f $LOGS_DIR/instance-*.log"
echo ""
echo "Check running instances:"
echo "  ps aux | grep hub_load_main.sh"
echo ""
echo "Wait for all to complete:"
echo "  wait ${pids[*]}"
echo ""
echo "View results per instance:"
for i in $(seq 1 "$NUM_INSTANCES"); do
    echo "  # Instance $i logs:"
    echo "  ls -lh /tmp/hub_load_logs/test-instance-${i}/parallel/"
    echo ""
done
echo "==============================================="
