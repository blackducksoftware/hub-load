#!/bin/bash
#
# reset_env.sh - Unset all hub-load environment variables
#
# Usage:
#   source src/hub_load/config/reset_env.sh
#
# This will unset all environment variables set by debug configs and load_config()
#

# Check if script is being sourced (not executed)
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ ERROR: This script must be SOURCED, not executed!" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') - " >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ Wrong:  ./src/hub_load/config/reset_env.sh" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Correct: source src/hub_load/config/reset_env.sh" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') - " >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Why? Executing in a subshell won't unset variables in your current shell." >&2
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - 🔄 Resetting hub-load environment variables..." >&2

# Core configuration variables
unset BD_HUB_URL
unset API_TOKEN
unset API_TIMEOUT
unset MAX_SCANS
unset MAX_CODELOCATIONS
unset MAX_COMPONENTS
unset MIN_COMPONENTS
unset MAX_VERSIONS
unset SYNCHRONOUS_SCANS
unset PARALLEL_SCANS
unset MAX_PARALLEL_JOBS
unset REPEAT_SCAN
unset RANDOM_SCANS
unset DETECT_VERSION
unset FAIL_ON_SEVERITIES
unset INSECURE_CURL
unset STRING_SEARCH
unset DEBUG
unset DRY_RUN
unset SCAN_TYPE
unset SNIPPETS
unset FIXED_COMPONENTS
unset WAIT_TIME

# Test duration and timing
unset TEST_DURATION
unset TEST_DURATION_HOURS
unset TARGET_DURATION

# Data source configuration
unset USE_MEMORY_MAPPING
unset USE_GCS
unset GCS_BUCKET
unset GCS_PREFIX
unset LOCAL_TEST_DATA_DIR
unset GCS_MOUNT_POINT
unset GCS_CACHE_SIZE
unset GCS_CACHE_DIR
unset LOG_DIR

# Multi-scan configuration
unset ENABLE_MULTI_SCAN
unset ENABLE_ENHANCED_MULTI_SCAN
unset ENHANCED_MULTI_SCAN
unset MULTI_SCAN_CONFIG
unset SMALL_SCAN_CONFIG
unset MULTI_GCS_CONFIG
unset SCAN_COUNT_THRESHOLD

# Project defaults
unset PROJECT
unset TIMESTAMP

# Parallel execution
unset PARALLEL_LOG_DIR
unset CADENCE_WAIT_FOR_SLOT

# Enhanced multi-scan internal variables
unset SCAN_COUNTER_FILE
unset SCAN_SEQUENCE_FILE
unset SCAN_SEQUENCE_INIT_FLAG
unset TARGZ_SOURCE_DIR
unset TARGZ_FILE_COUNT
unset ENABLE_TARGZ_FILES

# Library paths (usually safe to keep, but unset if needed)
unset HUB_LOAD_LIB_DIR
unset CONFIG_DIR

# Detect environment variables
unset DETECT_LATEST_RELEASE_VERSION
unset DETECT_CURL_OPTS

echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Environment variables reset" >&2
echo "$(date '+%Y-%m-%d %H:%M:%S') - 💡 Tip: Start a fresh shell or re-source a debug config to continue" >&2
