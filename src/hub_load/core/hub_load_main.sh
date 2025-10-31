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

Environment Variables:
  SCAN_TYPE=<type>           Scan type: SIGNATURE_SCAN, BINARY_SCAN, or CONTAINER_SCAN (default: SIGNATURE_SCAN)
  BD_HUB_URL=<url>           Black Duck Hub URL (required)
  API_TOKEN=<token>          API token for authentication (required)
  MAX_SCANS=<number>         Maximum number of scans to submit (default: 3)
  SYNCHRONOUS_SCANS=<yes/no> Wait for scan results (default: yes)
  PARALLEL_SCANS=<yes/no>    Enable parallel scan execution (default: no)
  MAX_PARALLEL_JOBS=<num>    Maximum concurrent parallel scans (default: 3)
  DEBUG=<yes/no>             Enable debug logging (default: no)
  USE_MEMORY_MAPPING=<yes/no> Use memory mapping for efficient file access (default: yes)
  USE_GCS=<yes/no>           Use Google Cloud Storage for test data (default: no)

Examples:
  SCAN_TYPE=SIGNATURE_SCAN BD_HUB_URL=https://hub.example.com API_TOKEN=abc123 $0
  SCAN_TYPE=BINARY_SCAN MAX_SCANS=5 $0
  PARALLEL_SCANS=yes MAX_PARALLEL_JOBS=3 MAX_SCANS=10 $0

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
    log_info "  • Scan Type: $SCAN_TYPE"
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