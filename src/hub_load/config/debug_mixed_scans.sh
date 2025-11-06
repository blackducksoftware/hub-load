#!/bin/bash
#
# Debug Configuration: Mixed Scan Types (Simple Distribution)
# Use this to test multiple scan types with a simple distribution
#
# Usage (Modular Architecture):
#   source src/hub_load/config/debug_mixed_scans.sh
#   USE_GCS=no MAX_SCANS=10 ./src/hub_load/core/hub_load_main.sh
#
# Note: This uses the modular hub_load_main.sh, NOT the legacy submit_scans_fixed.sh
#

echo "$(date '+%Y-%m-%d %H:%M:%S') - 🐛 DEBUG MODE: Mixed Scan Types (Simple)" >&2

# Simple mixed distribution: 3 scan types, easy percentages
# 40% Binary, 40% Signature, 20% Container
#export MULTI_SCAN_CONFIG="BINARY_SCAN_SMALL:50,BINARY_SCAN_MEDIUM:30,BINARY_SCAN_LARGE:15,BINARY_SCAN_XLARGE:5,SIGNATURE_SCAN_SMALL:20,SIGNATURE_SCAN_MEDIUM:12,SIGNATURE_SCAN_LARGE:8,SIGNATURE_SCAN_XLARGE:3,SNIPPET_SCAN:5,CONTAINER_SCAN_SMALL:8,CONTAINER_SCAN_MEDIUM:5,CONTAINER_SCAN_LARGE:3,CONTAINER_SCAN_XLARGE:1"
export MULTI_SCAN_CONFIG="BINARY_SCAN_SMALL:35,BINARY_SCAN_MEDIUM:30,BINARY_SCAN_LARGE:5,BINARY_SCAN_XLARGE:1,SIGNATURE_SCAN_SMALL:3,SIGNATURE_SCAN_MEDIUM:2,SNIPPET_SCAN:2,CONTAINER_SCAN_SMALL:10,CONTAINER_SCAN_MEDIUM:8,CONTAINER_SCAN_LARGE:3,CONTAINER_SCAN_XLARGE:1"
#export SMALL_SCAN_CONFIG="BINARY_SCAN_SMALL:40,SIGNATURE_SCAN_SMALL:40,CONTAINER_SCAN_SMALL:20"
export SMALL_SCAN_CONFIG="BINARY_SCAN_SMALL:58,BINARY_SCAN_MEDIUM:20,BINARY_SCAN_LARGE:2,SIGNATURE_SCAN_SMALL:3,SIGNATURE_SCAN_MEDIUM:2,SNIPPET_SCAN:2,CONTAINER_SCAN_SMALL:7,CONTAINER_SCAN_MEDIUM:5,CONTAINER_SCAN_LARGE:1"

# Force enhanced multi-scan mode
export ENABLE_ENHANCED_MULTI_SCAN=yes
export ENABLE_MULTI_SCAN=yes

# Debug settings
export DEBUG=no
export TEST_DURATION=1  # Short duration for quick debugging

# Recommended settings for debugging
export MAX_SCANS=${MAX_SCANS:-60}
export SYNCHRONOUS_SCANS=${SYNCHRONOUS_SCANS:-no}
export PARALLEL_SCANS=${PARALLEL_SCANS:-yes}
export USE_GCS=${USE_GCS:-no}
export LOCAL_TEST_DATA_DIR="${LOCAL_TEST_DATA_DIR:-/Users/karth/Library/CloudStorage/OneDrive-BlackDuckSoftware/Documents/Automation/blackducksoftware/test-data}"
export FIXED_COMPONENTS=${FIXED_COMPONENTS:-2}  # Number of files per signature scan

# Determine which config will be used based on scan count
SCAN_COUNT_THRESHOLD=${SCAN_COUNT_THRESHOLD:-50}
if [ "$MAX_SCANS" -lt "$SCAN_COUNT_THRESHOLD" ]; then
    ACTIVE_CONFIG="SMALL_SCAN_CONFIG"
    ACTIVE_CONFIG_VALUE="$SMALL_SCAN_CONFIG"
else
    ACTIVE_CONFIG="MULTI_SCAN_CONFIG"
    ACTIVE_CONFIG_VALUE="$MULTI_SCAN_CONFIG"
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Configuration:" >&2
echo "$(date '+%Y-%m-%d %H:%M:%S') -   MAX_SCANS: $MAX_SCANS" >&2
echo "$(date '+%Y-%m-%d %H:%M:%S') -   ACTIVE_CONFIG: $ACTIVE_CONFIG (threshold: $SCAN_COUNT_THRESHOLD)" >&2
echo "$(date '+%Y-%m-%d %H:%M:%S') -   CONFIG_VALUE: $ACTIVE_CONFIG_VALUE" >&2
echo "$(date '+%Y-%m-%d %H:%M:%S') -   SYNCHRONOUS_SCANS: $SYNCHRONOUS_SCANS" >&2
echo "$(date '+%Y-%m-%d %H:%M:%S') -   USE_GCS: $USE_GCS" >&2
echo "$(date '+%Y-%m-%d %H:%M:%S') -   LOCAL_TEST_DATA_DIR: $LOCAL_TEST_DATA_DIR" >&2
echo "$(date '+%Y-%m-%d %H:%M:%S') -   ENABLE_ENHANCED_MULTI_SCAN: $ENABLE_ENHANCED_MULTI_SCAN" >&2
echo "$(date '+%Y-%m-%d %H:%M:%S') -   ENABLE_MULTI_SCAN: $ENABLE_MULTI_SCAN" >&2
echo "$(date '+%Y-%m-%d %H:%M:%S') -   DEBUG: $DEBUG" >&2
echo "$(date '+%Y-%m-%d %H:%M:%S') - " >&2

