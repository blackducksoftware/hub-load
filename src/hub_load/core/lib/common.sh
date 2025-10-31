#!/bin/bash
#
# common.sh - Common utilities and configuration
#

# Global variables and defaults
export HUB_LOAD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CONFIG_DIR="$(dirname "$(dirname "$HUB_LOAD_LIB_DIR")")/config"

# Default configuration
export DEFAULT_MAX_SCANS=3
export DEFAULT_MAX_PARALLEL_JOBS=3
export DEFAULT_SCAN_TYPE="SIGNATURE_SCAN"
export DEFAULT_TARGET_DURATION=600
export DEFAULT_TEST_DURATION=1

# Logging functions
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ℹ️  $*" >&2
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ $*" >&2
}

log_warning() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ⚠️  $*" >&2
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ $*" >&2
}

log_debug() {
    if [ "${DEBUG}" == "yes" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 🔍 DEBUG: $*" >&2
    fi
}

# Validation functions
validate_required_vars() {
    local missing_vars=()
    
    # Check required environment variables
    [ -z "$BD_HUB_URL" ] && missing_vars+=("BD_HUB_URL")
    [ -z "$API_TOKEN" ] && missing_vars+=("API_TOKEN")
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi
    
    return 0
}

validate_scan_type() {
    local scan_type="$1"
    case "$scan_type" in
        SIGNATURE_SCAN|BINARY_SCAN|CONTAINER_SCAN|SNIPPET_SCAN)
            return 0
            ;;
        *)
            log_error "Invalid scan type: $scan_type"
            return 1
            ;;
    esac
}

# Configuration loading and validation
load_config() {
    # Load enhanced multi-scan configuration first (optional)
    if [ "${ENHANCED_MULTI_SCAN:-yes}" == "yes" ]; then
        load_enhanced_config
    fi
    
    # Set defaults
    export SCAN_TYPE="${SCAN_TYPE:-$DEFAULT_SCAN_TYPE}"
    export MAX_SCANS="${MAX_SCANS:-$DEFAULT_MAX_SCANS}"
    export MAX_PARALLEL_JOBS="${MAX_PARALLEL_JOBS:-$DEFAULT_MAX_PARALLEL_JOBS}"
    export PARALLEL_SCANS="${PARALLEL_SCANS:-no}"
    export DEBUG="${DEBUG:-no}"
    export USE_MEMORY_MAPPING="${USE_MEMORY_MAPPING:-yes}"
    export DRY_RUN="${DRY_RUN:-no}"
    export SYNCHRONOUS_SCANS="${SYNCHRONOUS_SCANS:-yes}"
    export TEST_DURATION="${TEST_DURATION:-$DEFAULT_TEST_DURATION}"
    
    # Calculate scan cadence timing
    calculate_scan_timing
    
    # Validate required parameters
    if [ -n "$BD_HUB_URL" ] && [ -n "$API_TOKEN" ]; then
        log_debug "MAX_SCANS=$MAX_SCANS, SCAN_TYPE=$SCAN_TYPE, PARALLEL_SCANS=$PARALLEL_SCANS"
        return 0
    elif [ "$DRY_RUN" == "yes" ]; then
        log_warning "DRY_RUN mode: using default Hub URL and API token"
        export BD_HUB_URL="${BD_HUB_URL:-https://test-hub.example.com}"
        export API_TOKEN="${API_TOKEN:-test-token}"
        return 0
    else
        log_error "BD_HUB_URL and API_TOKEN are required (or set DRY_RUN=yes)"
        return 1
    fi
}

# Calculate scan timing and cadence
# Calculate scan timing parameters
# TEST_DURATION is expected to be in HOURS (user input)
# This function converts it to seconds for internal use
calculate_scan_timing() {
    local test_duration_hours="${TEST_DURATION:-$DEFAULT_TEST_DURATION}"

    # Validate that TEST_DURATION is a valid number
    if ! [[ "$test_duration_hours" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        log_warning "TEST_DURATION must be a number (in hours), using default: 1 hour"
        test_duration_hours=1
    fi

    # Convert TEST_DURATION from hours to seconds
    # Support fractional hours (e.g., 0.1 = 6 minutes, 0.5 = 30 minutes)
    TEST_DURATION=$(echo "$test_duration_hours * 3600" | bc | cut -d. -f1)

    # Validate result
    if [ -z "$TEST_DURATION" ] || [ "$TEST_DURATION" -le 0 ]; then
        log_warning "Invalid TEST_DURATION calculation, using default: 1 hour (3600s)"
        TEST_DURATION=3600
    fi

    # Calculate target duration per scan
    if [ -n "$MAX_SCANS" ] && [ "$MAX_SCANS" -gt 0 ] && [ -n "$TEST_DURATION" ] && [ "$TEST_DURATION" -gt 0 ]; then
        TARGET_DURATION=$((TEST_DURATION / MAX_SCANS))
    else
        log_warning "Using default target duration: 600s per scan"
        TARGET_DURATION=600
    fi

    # Export both seconds (for calculations) and hours (for display)
    export TEST_DURATION TEST_DURATION_HOURS="$test_duration_hours" TARGET_DURATION

    log_debug "Timing calculation: TEST_DURATION=${test_duration_hours}h = ${TEST_DURATION}s, TARGET_DURATION=${TARGET_DURATION}s for ${MAX_SCANS} scans"
}

# Load enhanced multi-scan configuration
load_enhanced_config() {
    local enhanced_config_path="$CONFIG_DIR/enhanced_multi_scan_config.sh"
    
    if [ -f "$enhanced_config_path" ]; then
        log_info "Loading enhanced multi-scan configuration..."
        source "$enhanced_config_path"
        
        # Set enhanced mode flag
        export ENHANCED_MULTI_SCAN=yes
        export ENABLE_ENHANCED_MULTI_SCAN=yes
        
        log_debug "Enhanced multi-scan configuration loaded successfully"
        
        # Display configuration summary
        if [ "${DEBUG}" == "yes" ]; then
            log_debug "Scan Count Threshold: ${SCAN_COUNT_THRESHOLD:-50}"
            log_debug "Local Test Data Dir: ${LOCAL_TEST_DATA_DIR:-not set}"
        fi
        
        return 0
    else
        log_warning "Enhanced multi-scan config not found: $enhanced_config_path"
        log_info "Using simplified scan configuration"
        return 1
    fi
}

# Enhanced sleep management with progress reporting
smart_sleep() {
    local sleep_duration="$1"
    local description="${2:-Waiting}"
    local scan_number="${3:-}"
    
    if [ "$DRY_RUN" == "yes" ]; then
        log_info "⏭️  Skipping sleep in DRY_RUN mode ($description)"
        return 0
    fi
    
    if [ "$sleep_duration" -le 0 ]; then
        log_info "⚡ No sleep needed ($description)"
        return 0
    fi
    
    log_info "⏱️  $description for ${sleep_duration}s"
    
    # For long sleeps, show periodic progress updates
    if [ "$sleep_duration" -gt 60 ]; then
        for ((i=0; i<sleep_duration; i+=60)); do
            if [ $i -gt 0 ]; then
                local remaining=$((sleep_duration - i))
                local progress_msg="⏳ $description: ${remaining}s remaining"
                if [ -n "$scan_number" ]; then
                    progress_msg="$progress_msg (scan $scan_number)"
                fi
                log_info "$progress_msg"
            fi
            local sleep_time=$((sleep_duration - i > 60 ? 60 : sleep_duration - i))
            sleep "$sleep_time"
        done
    else
        sleep "$sleep_duration"
    fi
}

# Calculate wait time for scan cadence
calculate_wait_time() {
    local start_time="$1"
    local target_duration="$2"
    
    local current_time=$(date +%s)
    local elapsed_time=$((current_time - start_time))
    local wait_time=$((target_duration - elapsed_time))
    
    if [ "$wait_time" -lt 0 ]; then
        wait_time=0
    fi
    
    echo "$wait_time"
}

# Java detection and setup
check_java() {
    if ! command -v java >/dev/null 2>&1; then
        log_warning "Java not found in PATH, attempting to locate and configure Java..."
        
        # Common Java installation paths (prioritizing JDK 17)
        local java_paths=(
            "/usr/lib/jvm/java-17-openjdk-amd64/bin/java"
            "/usr/lib/jvm/java-17-openjdk/bin/java"
            "/usr/lib/jvm/jdk-17/bin/java"
            "/usr/lib/jvm/openjdk-17/bin/java"
            "/opt/java/openjdk-17/bin/java"
            "/usr/lib/jvm/java-21-openjdk-amd64/bin/java"
            "/usr/lib/jvm/java-11-openjdk-amd64/bin/java"
            "/usr/lib/jvm/java-8-openjdk-amd64/bin/java"
            "/usr/lib/jvm/default-java/bin/java"
            "/usr/bin/java"
            "/opt/java/openjdk/bin/java"
            "/System/Library/Frameworks/JavaVM.framework/Versions/Current/Commands/java"  # macOS
            "/usr/libexec/java_home"  # macOS java_home utility
        )
        
        local java_found=""
        for java_path in "${java_paths[@]}"; do
            if [ -x "$java_path" ]; then
                java_found="$java_path"
                log_success "Found Java at: $java_path"
                break
            fi
        done
        
        # macOS specific: try java_home utility
        if [ -z "$java_found" ] && command -v /usr/libexec/java_home >/dev/null 2>&1; then
            local java_home_path
            java_home_path=$(/usr/libexec/java_home 2>/dev/null)
            if [ -n "$java_home_path" ] && [ -x "$java_home_path/bin/java" ]; then
                java_found="$java_home_path/bin/java"
                log_success "Found Java via java_home: $java_found"
            fi
        fi
        
        if [ -n "$java_found" ]; then
            # Add Java directory to PATH
            export PATH="$(dirname "$java_found"):$PATH"
            export JAVA_HOME="$(dirname "$(dirname "$java_found")")"
            log_success "Added to PATH: $(dirname "$java_found")"
            log_success "Set JAVA_HOME: $JAVA_HOME"
        else
            log_error "Java not found. Please install JDK 17:"
            log_error "  Ubuntu/Debian: sudo apt-get update && sudo apt-get install openjdk-17-jdk"
            log_error "  RHEL/CentOS: sudo yum install java-17-openjdk-devel"
            log_error "  macOS: brew install openjdk@17"
            return 1
        fi
    else
        log_success "Java found: $(java -version 2>&1 | head -n 1)"
    fi
    
    return 0
}

# Error handling
handle_error() {
    local exit_code=$1
    local line_number=$2
    local command="$3"
    
    log_error "Command failed with exit code $exit_code at line $line_number: $command"
    
    # Cleanup on error
    cleanup_on_error
    exit $exit_code
}

cleanup_on_error() {
    log_info "Performing cleanup after error..."
    # Add cleanup logic here
    # - Kill running processes
    # - Remove temporary files
    # - Log final status
}

# Set up error handling (only when not in test mode)
if [ "${TEST_MODE}" != "yes" ]; then
    set -eE
    trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR
fi