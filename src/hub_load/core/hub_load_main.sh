#!/bin/bash
#
# hub_load_main.sh - Main entry point for modular hub load testing
#

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Source required modules
source "$LIB_DIR/common.sh"
source "$LIB_DIR/parallel_manager.sh"
source "$LIB_DIR/scan_manager.sh"
source "$LIB_DIR/file_manager.sh"

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [options]

Environment Variables (compatible with submit_scans_fixed.sh):

  Basic Configuration:
    SCAN_TYPE=<type>           Scan type: SIGNATURE_SCAN, BINARY_SCAN, or CONTAINER_SCAN (default: SIGNATURE_SCAN)
    BD_HUB_URL=<url>           Black Duck Hub URL (required)
    API_TOKEN=<token>          API token for authentication (required)
    MAX_SCANS=<number>         Maximum number of scans to submit (default: 3)
    API_TIMEOUT=<seconds>      Synopsys Detect timeout value (default: 300)

  Scan Behavior:
    SYNCHRONOUS_SCANS=<yes/no> Wait for scan results (default: yes)
    SNIPPETS=<yes/no>          For SIGNATURE_SCAN: Enable snippet scanning (default: no)
    STRING_SEARCH=<yes/no>     For SIGNATURE_SCAN: Enable license/copyright search (default: no)
    REPEAT_SCAN=<yes/no>       Repeat scan with same components (default: no)
    RANDOM_SCANS=<yes/no>      Use random component selection (default: no)

  Component Selection:
    MIN_COMPONENTS=<number>    For SIGNATURE_SCAN: Min random components (default: 200)
    MAX_COMPONENTS=<number>    For SIGNATURE_SCAN: Max random components (default: 400)
    FIXED_COMPONENTS=<number>  Fixed components per scan (default: 100 signature, 1 binary/container)
    MAX_VERSIONS=<number>      Max versions per project (default: 1)
    MAX_CODELOCATIONS=<number> Max code locations per version (default: 1)

  Parallel Execution:
    PARALLEL_SCANS=<yes/no>    Enable parallel scan execution with cadence intervals (default: no)
    MAX_PARALLEL_JOBS=<num>    Max concurrent parallel scans (default: 3)
    TEST_DURATION=<hours>      Test duration in hours (default: 1)

  Detect Configuration:
    DETECT_VERSION=<version>   Synopsys Detect version (default: LATEST)
    FAIL_ON_SEVERITIES=<list>  Policy check severity levels (default: NONE)
    INSECURE_CURL=<yes/no>     Use curl --insecure mode (default: no)

  Data Source:
    USE_GCS=<yes/no>           Use Google Cloud Storage for test data (default: no)
    GCS_BUCKET=<bucket>        GCS bucket name (required if USE_GCS=yes)
    GCS_PREFIX=<prefix>        GCS prefix/folder path (optional)
    GCS_MOUNT_POINT=<path>     Local GCS mount point (default: /mnt/gcs-data)
    LOCAL_TEST_DATA_DIR=<path> Local test data directory (for USE_GCS=no)

  Enhanced Features:
    ENABLE_ENHANCED_MULTI_SCAN=<yes/no> Enable multi-type scan distribution (default: no)
    USE_MEMORY_MAPPING=<yes/no> Use memory mapping for 27.5% faster file access (default: yes)

  Debugging:
    DEBUG=<yes/no>             Enable debug logging (default: no)
    DRY_RUN=<yes/no>           Test mode without actual scans (default: no)

Examples:
  # Single scan type
  SCAN_TYPE=SIGNATURE_SCAN BD_HUB_URL=https://hub.example.com API_TOKEN=abc123 $0

  # Binary scans
  SCAN_TYPE=BINARY_SCAN MAX_SCANS=5 $0

  # Parallel execution
  PARALLEL_SCANS=yes MAX_PARALLEL_JOBS=3 MAX_SCANS=10 $0

  # Enhanced multi-scan with parallel execution
  PARALLEL_SCANS=yes ENABLE_ENHANCED_MULTI_SCAN=yes MAX_SCANS=100 $0

  # Snippet scanning
  SCAN_TYPE=SIGNATURE_SCAN SNIPPETS=yes MAX_SCANS=5 $0

Modular Architecture Benefits:
  • Easy debugging - each module can be tested independently
  • Better maintainability - changes are isolated to specific modules
  • Improved reliability - syntax errors don't cascade across the entire system
  • Enhanced testability - unit tests can be written for each module
  • Collaborative development - multiple developers can work on different modules

Module Structure:
  • common.sh         - Shared utilities, logging, configuration, error handling
  • parallel_manager.sh - Parallel execution management and job tracking
  • scan_manager.sh   - Scan execution, configuration, and statistics
  • file_manager.sh   - File preparation, creation, and cleanup
  • hub_load_main.sh  - Main orchestration and entry point

EOF
    exit 1
}

# Main execution function
main() {
    log_info "==============================================="
    log_info "🚀 STARTING MODULAR HUB LOAD TESTING"
    log_info "==============================================="
    
    # Check for help
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_usage
        return 0
    fi
    
    # Load and validate configuration
    if ! load_config; then
        log_error "Configuration validation failed"
        exit 1
    fi
    
    # Ensure Java is available
    log_info "Checking Java environment..."
    check_java
    
    # Display configuration
    log_info "Configuration:"
    if [ "${ENHANCED_MULTI_SCAN}" == "yes" ] || [ "${ENABLE_ENHANCED_MULTI_SCAN}" == "yes" ]; then
        log_info "  • Scan Mode: ENHANCED MULTI-SCAN (automatic distribution)"
    else
        log_info "  • Scan Type: $SCAN_TYPE"
    fi
    log_info "  • Max Scans: $MAX_SCANS"
    log_info "  • Parallel Mode: $PARALLEL_SCANS"
    if [ "$PARALLEL_SCANS" == "yes" ]; then
        log_info "  • Max Parallel Jobs: $MAX_PARALLEL_JOBS"
    fi
    log_info "  • Debug Mode: $DEBUG"
    log_info "  • Hub URL: ${BD_HUB_URL:0:30}..."
    log_info ""
    
    # Initialize managers
    log_info "Initializing system components..."
    
    if ! init_scan_manager; then
        log_error "Failed to initialize scan manager"
        exit 1
    fi
    
    log_success "System initialization completed"
    log_info ""
    
    # Execute scan batch
    local start_time=$(date +%s)
    
    if run_scan_batch; then
        local end_time=$(date +%s)
        local total_duration=$((end_time - start_time))
        
        log_success "Scan batch completed successfully"
        log_info "Total execution time: ${total_duration}s"
        
        # Print final statistics
        print_scan_statistics
        
        log_info "==============================================="
        log_success "🎉 MODULAR HUB LOAD TESTING COMPLETED"
        log_info "==============================================="
        
        exit 0
    else
        log_error "Scan batch failed"
        
        log_info "==============================================="
        log_error "❌ MODULAR HUB LOAD TESTING FAILED"
        log_info "==============================================="
        
        exit 1
    fi
}

# Execute main function with all arguments
main "$@"