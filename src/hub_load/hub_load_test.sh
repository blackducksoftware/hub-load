#!/bin/bash
#
# Hub Load Testing - Main Entry Point
# Modular Black Duck SCA Load Testing System
# Supports 4 scan types: SIGNATURE_SCAN, BINARY_SCAN, CONTAINER_SCAN, and TAR.GZ file handling
#

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set module paths
CORE_DIR="${SCRIPT_DIR}/core"
CONFIG_DIR="${SCRIPT_DIR}/config"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
MEMORY_MAPPING_DIR="${SCRIPT_DIR}/memory_mapping"
DOCKER_DIR="${SCRIPT_DIR}/docker"

# Source the configuration
if [ -f "${CONFIG_DIR}/enhanced_multi_scan_config.sh" ]; then
    source "${CONFIG_DIR}/enhanced_multi_scan_config.sh"
fi

# Export paths for use by other scripts
export CORE_DIR CONFIG_DIR SCRIPTS_DIR MEMORY_MAPPING_DIR DOCKER_DIR

# Execute the modular main load testing script
# NOTE: Using hub_load_main.sh (modular architecture), NOT submit_scans_fixed.sh (legacy with known issues)
exec "${CORE_DIR}/hub_load_main.sh" "$@"