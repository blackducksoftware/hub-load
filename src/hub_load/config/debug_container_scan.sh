#!/bin/bash
#
# Debug Configuration: CONTAINER_SCAN Only
# Use this to test container scan functionality in isolation
#
# Usage (Modular Architecture):
#   source src/hub_load/config/debug_container_scan.sh
#   USE_GCS=no MAX_SCANS=3 ./src/hub_load/core/hub_load_main.sh
#
# Note: This uses the modular hub_load_main.sh, NOT the legacy submit_scans_fixed.sh
#

echo "$(date '+%Y-%m-%d %H:%M:%S') - 🐛 DEBUG MODE: CONTAINER_SCAN Only" >&2

# Override multi-scan configuration to use ONLY container scans
# 100% CONTAINER_SCAN_SMALL for maximum simplicity and debugging
export MULTI_SCAN_CONFIG="CONTAINER_SCAN_SMALL:100"
#export SMALL_SCAN_CONFIG="CONTAINER_SCAN_SMALL:100"
export SMALL_SCAN_CONFIG="CONTAINER_SCAN_SMALL:25,CONTAINER_SCAN_MEDIUM:25,CONTAINER_SCAN_LARGE:25,CONTAINER_SCAN_XLARGE:25"

# Force enhanced multi-scan mode
export ENABLE_ENHANCED_MULTI_SCAN=yes
export ENABLE_MULTI_SCAN=yes

# Debug settings
export DEBUG=no
export TEST_DURATION=0.05  # Short duration for quick debugging
export SCAN_TYPE=CONTAINER_SCAN

# Recommended settings for debugging
export MAX_SCANS=${MAX_SCANS:-4}
export SYNCHRONOUS_SCANS=${SYNCHRONOUS_SCANS:-no}
export PARALLEL_SCANS=${PARALLEL_SCANS:-no}
export USE_GCS=${USE_GCS:-no}
export LOCAL_TEST_DATA_DIR="/Users/karth/Library/CloudStorage/OneDrive-BlackDuckSoftware/Documents/Automation/blackducksoftware/test-data"
export DEBUG=no


# Container-specific settings
export FIXED_COMPONENTS=1  # Container scans typically use 1 file
export TEST_DURATION=0.1  # Short duration for quick debugging

echo "$(date '+%Y-%m-%d %H:%M:%S') - Configuration:" >&2
echo "$(date '+%Y-%m-%d %H:%M:%S') -   SCAN_TYPE: $SCAN_TYPE" >&2
echo "$(date '+%Y-%m-%d %H:%M:%S') -   MAX_SCANS: $MAX_SCANS" >&2
echo "$(date '+%Y-%m-%d %H:%M:%S') -   MULTI_SCAN_CONFIG: $MULTI_SCAN_CONFIG" >&2
echo "$(date '+%Y-%m-%d %H:%M:%S') -   SYNCHRONOUS_SCANS: $SYNCHRONOUS_SCANS" >&2
echo "$(date '+%Y-%m-%d %H:%M:%S') -   USE_GCS: $USE_GCS" >&2
echo "$(date '+%Y-%m-%d %H:%M:%S') -   LOCAL_TEST_DATA_DIR: $LOCAL_TEST_DATA_DIR" >&2
echo "$(date '+%Y-%m-%d %H:%M:%S') -   ENABLE_ENHANCED_MULTI_SCAN: $ENABLE_ENHANCED_MULTI_SCAN" >&2
echo "$(date '+%Y-%m-%d %H:%M:%S') -   ENABLE_MULTI_SCAN: $ENABLE_MULTI_SCAN" >&2
echo "$(date '+%Y-%m-%d %H:%M:%S') -   FIXED_COMPONENTS: $FIXED_COMPONENTS" >&2
echo "$(date '+%Y-%m-%d %H:%M:%S') -   DEBUG: $DEBUG" >&2
echo "$(date '+%Y-%m-%d %H:%M:%S') - Expected files: *.tar in container directories" >&2
echo "$(date '+%Y-%m-%d %H:%M:%S') - Test data location: \$LOCAL_TEST_DATA_DIR/SCASS/SCA_NON_BDIOS_CONTAINER_SM_MEDIUM/" >&2
