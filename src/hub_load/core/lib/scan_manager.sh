#!/bin/bash
#
# scan_manager.sh - Scan execution and management
#

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/parallel_manager.sh"
source "$(dirname "${BASH_SOURCE[0]}")/file_manager.sh"

# Scan type counters - using regular variables for compatibility
SIGNATURE_SCAN_COUNT=0
BINARY_SCAN_COUNT=0
CONTAINER_SCAN_COUNT=0
SNIPPET_SCAN_COUNT=0

# Size-specific counters
SIGNATURE_SCAN_SMALL_COUNT=0
SIGNATURE_SCAN_MEDIUM_COUNT=0
SIGNATURE_SCAN_LARGE_COUNT=0
SIGNATURE_SCAN_XLARGE_COUNT=0
BINARY_SCAN_SMALL_COUNT=0
BINARY_SCAN_MEDIUM_COUNT=0
BINARY_SCAN_LARGE_COUNT=0
BINARY_SCAN_XLARGE_COUNT=0
CONTAINER_SCAN_SMALL_COUNT=0
CONTAINER_SCAN_MEDIUM_COUNT=0
CONTAINER_SCAN_LARGE_COUNT=0
CONTAINER_SCAN_XLARGE_COUNT=0
SNIPPET_SCAN_SMALL_COUNT=0
SNIPPET_SCAN_MEDIUM_COUNT=0
SNIPPET_SCAN_LARGE_COUNT=0
SNIPPET_SCAN_XLARGE_COUNT=0

# Initialize scan manager
init_scan_manager() {
    log_info "Initializing scan manager"
    
    # Reset counters
    SIGNATURE_SCAN_COUNT=0
    BINARY_SCAN_COUNT=0
    CONTAINER_SCAN_COUNT=0
    SNIPPET_SCAN_COUNT=0
    
    SIGNATURE_SCAN_SMALL_COUNT=0
    SIGNATURE_SCAN_MEDIUM_COUNT=0
    SIGNATURE_SCAN_LARGE_COUNT=0
    SIGNATURE_SCAN_XLARGE_COUNT=0
    BINARY_SCAN_SMALL_COUNT=0
    BINARY_SCAN_MEDIUM_COUNT=0
    BINARY_SCAN_LARGE_COUNT=0
    BINARY_SCAN_XLARGE_COUNT=0
    CONTAINER_SCAN_SMALL_COUNT=0
    CONTAINER_SCAN_MEDIUM_COUNT=0
    CONTAINER_SCAN_LARGE_COUNT=0
    CONTAINER_SCAN_XLARGE_COUNT=0
    SNIPPET_SCAN_SMALL_COUNT=0
    SNIPPET_SCAN_MEDIUM_COUNT=0
    SNIPPET_SCAN_LARGE_COUNT=0
    SNIPPET_SCAN_XLARGE_COUNT=0
    
    # Initialize parallel manager if needed
    if [ "${PARALLEL_SCANS}" == "yes" ]; then
        init_parallel_manager
    fi
    
    return 0
}

# Execute a single scan
execute_scan() {
    local scan_config="$1"
    local scan_id="$2"

    if [ -z "$scan_config" ]; then
        log_error "execute_scan requires scan_config parameter"
        return 1
    fi

    # Parse scan configuration
    local scan_type project_name scan_size scan_type_size
    IFS='|' read -r scan_type project_name scan_size scan_type_size <<< "$scan_config"

    log_info "Executing scan: $scan_type for project $project_name (size: $scan_size)"

    # Discover files from test data directories if enhanced mode is enabled
    if [ "${ENHANCED_MULTI_SCAN}" == "yes" ] && [ -n "$scan_type_size" ]; then
        log_info "🔍 Discovering files for $scan_type_size from test data directories"

        # Determine project root for file discovery
        local project_root="${LOCAL_TEST_DATA_DIR}/SCASS"
        if [ -n "$scan_type_size" ] && command -v get_local_directory_for_scan_type >/dev/null 2>&1; then
            project_root=$(get_local_directory_for_scan_type "$scan_type_size")
        fi

        # Discover files based on scan type and size
        if discover_scan_files "$scan_type" "$scan_type_size" "$project_root" "${SNIPPETS:-no}"; then
            log_success "File discovery completed: ${#DISCOVERED_FILES[@]} files available"

            # Select files for this specific scan
            if select_files_for_scan "$scan_type" "$scan_type_size" "${RANDOM_SCANS:-no}"; then
                log_info "Selected ${#SELECTED_PROJECT_FILES[@]} files for scan"
            else
                log_warning "File selection failed, falling back to file preparation"
            fi
        else
            log_warning "File discovery failed, falling back to file preparation"
        fi
    fi

    # Prepare scan environment
    local scan_dir="/tmp/scan_${scan_id}_$$"
    mkdir -p "$scan_dir"

    # If files were discovered and selected, use them directly
    if [ -n "${SELECTED_PROJECT_FILES[*]}" ] && [ ${#SELECTED_PROJECT_FILES[@]} -gt 0 ]; then
        log_info "Using discovered files for scan (${#SELECTED_PROJECT_FILES[@]} files)"

        # Create symbolic links or copy files to scan directory
        local linked_count=0
        for source_file in "${SELECTED_PROJECT_FILES[@]}"; do
            if [ -f "$source_file" ]; then
                local filename=$(basename "$source_file")
                if ln -sf "$source_file" "$scan_dir/$filename" 2>/dev/null; then
                    ((linked_count++))
                fi
            fi
        done

        if [ "$linked_count" -gt 0 ]; then
            log_success "Prepared $linked_count files using symbolic links"
        else
            log_error "Failed to link discovered files, falling back to file preparation"
            if ! prepare_scan_files "$scan_dir" "$scan_type" "$scan_size" "$scan_type_size"; then
                log_error "Failed to prepare scan files"
                return 1
            fi
        fi
    else
        # Fallback to synthetic file preparation
        if ! prepare_scan_files "$scan_dir" "$scan_type" "$scan_size" "$scan_type_size"; then
            log_error "Failed to prepare scan files"
            return 1
        fi
    fi

    # Generate scan command
    local scan_command
    scan_command=$(generate_scan_command "$scan_type" "$project_name" "$scan_dir")
    
    if [ "${PARALLEL_SCANS}" == "yes" ]; then
        # Execute in parallel
        local job_name="${scan_type}_${project_name}_${scan_id}"
        local log_file="${PARALLEL_LOG_DIR}/${job_name}.log"
        
        start_parallel_job "$job_name" "$scan_command" "$log_file"
    else
        # Execute synchronously
        log_info "Starting synchronous scan execution"
        local start_time=$(date +%s)
        
        if eval "$scan_command"; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            log_success "Scan completed successfully in ${duration}s"
            
            # Update counters
            case "$scan_type" in
                SIGNATURE_SCAN) ((SIGNATURE_SCAN_COUNT++)) ;;
                BINARY_SCAN) ((BINARY_SCAN_COUNT++)) ;;
                CONTAINER_SCAN) ((CONTAINER_SCAN_COUNT++)) ;;
                SNIPPET_SCAN) ((SNIPPET_SCAN_COUNT++)) ;;
            esac
            
            if [ -n "$scan_size" ]; then
                case "${scan_type}_${scan_size}" in
                    SIGNATURE_SCAN_SMALL) ((SIGNATURE_SCAN_SMALL_COUNT++)) ;;
                    SIGNATURE_SCAN_MEDIUM) ((SIGNATURE_SCAN_MEDIUM_COUNT++)) ;;
                    SIGNATURE_SCAN_LARGE) ((SIGNATURE_SCAN_LARGE_COUNT++)) ;;
                    SIGNATURE_SCAN_XLARGE) ((SIGNATURE_SCAN_XLARGE_COUNT++)) ;;
                    BINARY_SCAN_SMALL) ((BINARY_SCAN_SMALL_COUNT++)) ;;
                    BINARY_SCAN_MEDIUM) ((BINARY_SCAN_MEDIUM_COUNT++)) ;;
                    BINARY_SCAN_LARGE) ((BINARY_SCAN_LARGE_COUNT++)) ;;
                    BINARY_SCAN_XLARGE) ((BINARY_SCAN_XLARGE_COUNT++)) ;;
                    CONTAINER_SCAN_SMALL) ((CONTAINER_SCAN_SMALL_COUNT++)) ;;
                    CONTAINER_SCAN_MEDIUM) ((CONTAINER_SCAN_MEDIUM_COUNT++)) ;;
                    CONTAINER_SCAN_LARGE) ((CONTAINER_SCAN_LARGE_COUNT++)) ;;
                    CONTAINER_SCAN_XLARGE) ((CONTAINER_SCAN_XLARGE_COUNT++)) ;;
                    SNIPPET_SCAN_SMALL) ((SNIPPET_SCAN_SMALL_COUNT++)) ;;
                    SNIPPET_SCAN_MEDIUM) ((SNIPPET_SCAN_MEDIUM_COUNT++)) ;;
                    SNIPPET_SCAN_LARGE) ((SNIPPET_SCAN_LARGE_COUNT++)) ;;
                    SNIPPET_SCAN_XLARGE) ((SNIPPET_SCAN_XLARGE_COUNT++)) ;;
                esac
            fi
        else
            log_error "Scan failed"
            return 1
        fi
    fi
    
    return 0
}

# Generate scan command based on type
generate_scan_command() {
    local scan_type="$1"
    local project_name="$2"
    local scan_dir="$3"
    
    local base_command="cd '$scan_dir' && "
    
    case "$scan_type" in
        SIGNATURE_SCAN)
            base_command+="bash <(curl -s -L https://detect.blackduck.com/detect.sh)"
            base_command+=" --blackduck.url='$BD_HUB_URL'"
            base_command+=" --blackduck.api.token='$API_TOKEN'"
            base_command+=" --detect.project.name='$project_name'"
            base_command+=" --detect.project.version.name='1.0'"
            ;;
        BINARY_SCAN)
            # Get first binary file from scan directory (follow symlinks with -L)
            local binary_file=$(find -L "$scan_dir" -type f \( -name "*.exe" -o -name "*.dmg" -o -name "*.msi" -o -name "*.deb" -o -name "*.rpm" -o -name "*.pkg" -o -name "*.lib" -o -name "*.cab" -o -name "*.img" -o -name "*.iso" -o -name "*.vmdk" -o -name "*.ova" -o -name "*.vdi" -o -name "*.ubifs" \) 2>/dev/null | head -1)

            base_command+="bash <(curl -s -L https://detect.blackduck.com/detect.sh)"
            base_command+=" --blackduck.url='$BD_HUB_URL'"
            base_command+=" --blackduck.api.token='$API_TOKEN'"
            base_command+=" --detect.project.name='$project_name'"
            base_command+=" --detect.project.version.name='1.0'"
            base_command+=" --detect.tools='BINARY_SCAN'"

            # Add binary scan file path if found
            if [ -n "$binary_file" ]; then
                base_command+=" --detect.binary.scan.file.path='$binary_file'"
                log_debug "Binary scan will upload: $binary_file"
            else
                log_warning "No binary file found in $scan_dir for binary scan"
            fi
            ;;
        CONTAINER_SCAN)
            # Get first container tar file from scan directory (follow symlinks with -L)
            local container_file=$(find -L "$scan_dir" -type f -name "*.tar" 2>/dev/null | head -1)

            base_command+="bash <(curl -s -L https://detect.blackduck.com/detect.sh)"
            base_command+=" --blackduck.url='$BD_HUB_URL'"
            base_command+=" --blackduck.api.token='$API_TOKEN'"
            base_command+=" --detect.project.name='$project_name'"
            base_command+=" --detect.project.version.name='1.0'"
            base_command+=" --detect.tools='CONTAINER_SCAN'"

            # Add container image path if found
            if [ -n "$container_file" ]; then
                base_command+=" --detect.docker.tar='$container_file'"
                log_debug "Container scan will analyze: $container_file"
            else
                log_warning "No container tar file found in $scan_dir for container scan"
            fi
            ;;
        *)
            log_error "Unknown scan type: $scan_type"
            return 1
            ;;
    esac
    
    echo "$base_command"
}

# Run multiple scans based on configuration
run_scan_batch() {
    local max_scans=${MAX_SCANS:-3}
    local current_scan=0
    local batch_start_time=$(date +%s)
    local last_scan_start_time=$batch_start_time
    local skipped_scans=0
    
    log_info "==============================================="
    log_info "📋 LOAD TEST EXECUTION PLAN"
    log_info "==============================================="
    log_info ""
    log_info "Test Configuration:"
    log_info "  • Total Scans: $max_scans"
    log_info "  • Test Duration: ${TEST_DURATION_HOURS}h (${TEST_DURATION}s)"
    log_info "  • Target Cadence: ${TARGET_DURATION}s per scan"
    log_info "  • Black Duck Hub: ${BD_HUB_URL}"
    log_info ""

    if [ "${PARALLEL_SCANS}" == "yes" ]; then
        local max_jobs=${MAX_PARALLEL_JOBS:-3}
        local wait_for_slot=${CADENCE_WAIT_FOR_SLOT:-0}
        log_info "Execution Mode:"
        log_info "  • Mode: SEQUENTIAL WITH OVERFLOW"
        log_info "  • Primary: One scan at a time (sequential)"
        log_info "  • Overflow: Use parallel slots when main scan blocks next cadence"
        log_info "  • Max overflow slots: $max_jobs"
        log_info "  • Cadence interval: ${TARGET_DURATION}s"
        log_info "  • Strategy: No skipping - all scans execute"
    else
        log_info "Execution Mode:"
        log_info "  • Mode: PURE SEQUENTIAL"
        log_info "  • Wait for each scan to complete before starting next"
    fi
    log_info ""

    # Show expected distribution if enhanced mode is enabled
    if [ "${ENHANCED_MULTI_SCAN}" == "yes" ] && command -v get_expected_distribution >/dev/null 2>&1; then
        log_info "Expected Scan Type Distribution:"
        log_info "$(get_expected_distribution $max_scans | sed 's/^/  /')"
    fi

    log_info "Scan Results Tracking:"
    log_info "  • Scan logs: ${PARALLEL_LOG_DIR}/"
    log_info "  • Results summary will be displayed at completion"
    log_info ""
    log_info "==============================================="
    log_info "🚀 STARTING SCAN EXECUTION"
    log_info "==============================================="
    log_info ""
    
    while [ $current_scan -lt $max_scans ]; do
        ((current_scan++))
        local current_time=$(date +%s)

        log_info "Preparing scan $current_scan/$max_scans"

        # Generate scan configuration
        local scan_config
        scan_config=$(generate_scan_config)

        if [ "${PARALLEL_SCANS}" == "yes" ]; then
            # SEQUENTIAL WITH OVERFLOW MODE
            # Strategy: Run scans one at a time, but use parallel slots if main scan would block cadence

            # Calculate when this scan should start based on cadence
            local expected_start_time=$((last_scan_start_time + TARGET_DURATION))
            local time_until_start=$((expected_start_time - current_time))

            # If not the first scan, wait for cadence interval
            if [ "$current_scan" -gt 1 ] && [ "$time_until_start" -gt 0 ]; then
                log_info "⏱️  Cadence wait: ${time_until_start}s until scan $current_scan starts"
                smart_sleep "$time_until_start" "Maintaining ${TARGET_DURATION}s scan cadence" "$current_scan"
                current_time=$(date +%s)
            fi

            # Mark when this scan attempt starts
            last_scan_start_time=$(date +%s)

            # Check if there are any running background scans from previous overflow
            local running_count=$(get_running_job_count)
            if [ "$running_count" -gt 0 ]; then
                log_info "📊 Background scans running: $running_count"
            fi

            # Determine if we should run this scan in foreground (sequential) or background (overflow)
            # Strategy: Always try foreground first, use background only if we'd block the next cadence

            local use_overflow=false
            local next_scan_expected=$((current_time + TARGET_DURATION))

            # Check if there's a next scan coming and estimate if this scan might block it
            if [ "$current_scan" -lt "$max_scans" ]; then
                # If we have overflow capacity AND might block next cadence, use overflow slot
                if [ "$running_count" -lt "${MAX_PARALLEL_JOBS:-3}" ]; then
                    # We have overflow capacity available
                    # Decision: Use overflow slot so we don't block the main sequential flow
                    if [ "$running_count" -gt 0 ]; then
                        # Already have background scans, add this one to background too
                        use_overflow=true
                        log_info "🔀 Overflow mode: Running scan $current_scan in background (freeing main thread)"
                    else
                        # No background scans yet - run in foreground (sequential)
                        use_overflow=false
                        log_info "▶️  Sequential mode: Running scan $current_scan in foreground"
                    fi
                else
                    # All overflow slots full - MUST wait for one to complete
                    log_warning "⏸️  All overflow slots full ($running_count/${MAX_PARALLEL_JOBS:-3})"
                    log_info "⏳ Waiting for overflow slot to free up (no skipping)"
                    wait_for_parallel_slot 0  # Wait indefinitely - no timeout, no skipping
                    running_count=$(get_running_job_count)
                    log_info "✅ Overflow slot freed - continuing"
                    use_overflow=false  # Run in foreground now
                    log_info "▶️  Sequential mode: Running scan $current_scan in foreground"
                fi
            else
                # Last scan - run in foreground
                use_overflow=false
                log_info "▶️  Final scan: Running scan $current_scan in foreground"
            fi

            # Execute based on decision
            local scan_id="scan_${current_scan}"
            if [ "$use_overflow" = true ]; then
                # Use overflow: execute in background (parallel slot)
                log_info "🚀 Starting scan $current_scan in background overflow slot"
                if ! execute_scan "$scan_config" "$scan_id"; then
                    log_error "Scan $current_scan failed to start"
                fi
                # Continue immediately to next scan (overflow scan runs in background)
            else
                # Sequential: execute in foreground and WAIT for completion
                log_info "🚀 Starting scan $current_scan in foreground (sequential)"

                # Temporarily disable parallel mode to force synchronous execution
                local saved_parallel="${PARALLEL_SCANS}"
                PARALLEL_SCANS="no"

                if ! execute_scan "$scan_config" "$scan_id"; then
                    log_error "Scan $current_scan failed"
                fi

                # Restore parallel mode
                PARALLEL_SCANS="$saved_parallel"

                log_success "Scan $current_scan completed"
            fi
        else
            # PURE SEQUENTIAL MODE - original behavior
            local scan_id="scan_${current_scan}"
            if ! execute_scan "$scan_config" "$scan_id"; then
                log_error "Scan $current_scan failed"
                return 1
            fi

            # Handle scan cadence
            handle_scan_cadence "$current_scan" "$scan_start_time" "$max_scans"
        fi
    done
    
    # Wait for all parallel/overflow scans to complete
    if [ "${PARALLEL_SCANS}" == "yes" ]; then
        local active_scans=$(get_running_job_count)
        if [ "$active_scans" -gt 0 ]; then
            log_info "⏳ Waiting for $active_scans remaining overflow scans to complete..."
            wait_for_all_jobs
            extract_job_results
        fi

        # Report final statistics (no scans skipped in overflow mode)
        log_success "✅ Scan batch completed: $current_scan scans executed (0 skipped)"
        log_info "   Sequential-with-overflow mode ensured all scans executed"
    else
        log_success "Scan batch completed: $current_scan scans processed sequentially"
    fi
    
    return 0
}

# Generate scan configuration using enhanced multi-scan config
generate_scan_config() {
    # Source the enhanced multi-scan configuration
    local config_path="${CONFIG_DIR}/enhanced_multi_scan_config.sh"
    if [ -f "$config_path" ]; then
        source "$config_path"
        
        # Use the sophisticated scan type selection (preserve logging to stderr)
        local scan_type_size
        scan_type_size=$(select_scan_type_with_size)
        
        if [ "$scan_type_size" == "NO_FILES_AVAILABLE" ]; then
            log_warning "No files available for enhanced multi-scan, falling back to default"
            local scan_type="${SCAN_TYPE:-SIGNATURE_SCAN}"
            local project_name="test-project-$(date +%s)-$$"
            local scan_size="MEDIUM"
            echo "${scan_type}|${project_name}|${scan_size}"
            return
        fi
        
        # Parse the enhanced scan type selection
        local scan_info=($(parse_scan_type_and_size "$scan_type_size"))
        local scan_type="${scan_info[0]}"
        local scan_size="${scan_info[1]}"
        
        # Handle snippet scans (they use SIGNATURE_SCAN as base)
        if [[ "$scan_type_size" == "SNIPPET_SCAN"* ]]; then
            scan_type="SIGNATURE_SCAN"
            export SNIPPETS="yes"
            export ENABLE_ENHANCED_MULTI_SCAN="yes"
        else
            export SNIPPETS="no"
        fi
        
        local project_name="enhanced-$(echo "$scan_type_size" | tr '[:upper:]' '[:lower:]')-$(date +%s)-$$"
        
        log_debug "Enhanced scan config: $scan_type_size -> $scan_type/$scan_size"
        echo "${scan_type}|${project_name}|${scan_size}|${scan_type_size}"
    else
        log_warning "Enhanced multi-scan config not found, using basic configuration"
        local scan_type="${SCAN_TYPE:-SIGNATURE_SCAN}"
        local project_name="test-project-$(date +%s)-$$"
        local scan_size="MEDIUM"
        echo "${scan_type}|${project_name}|${scan_size}"
    fi
}

# Handle scan cadence timing
handle_scan_cadence() {
    local scan_number="$1"
    local scan_start_time="$2"
    local total_scans="$3"
    
    # Skip cadence for the last scan
    if [ "$scan_number" -ge "$total_scans" ]; then
        log_info "🏁 Final scan completed - no cadence wait needed"
        return 0
    fi
    
    if [ "${PARALLEL_SCANS}" == "yes" ]; then
        # Parallel mode: use fixed interval between scan starts
        local description="Parallel scan cadence (scan $((scan_number + 1)) start)"
        smart_sleep "$TARGET_DURATION" "$description" "$((scan_number + 1))"
    else
        # Sequential mode: maintain total scan duration
        if [ "$scan_number" -eq 1 ]; then
            log_info "⏭️  Skipping cadence wait for first scan"
            return 0
        fi
        
        local wait_time
        wait_time=$(calculate_wait_time "$scan_start_time" "$TARGET_DURATION")
        
        if [ "$wait_time" -gt 0 ]; then
            local description="Sequential scan cadence (${TARGET_DURATION}s target)"
            smart_sleep "$wait_time" "$description" "$((scan_number + 1))"
        else
            local current_time=$(date +%s)
            local elapsed_time=$((current_time - scan_start_time))
            log_info "⚡ Scan exceeded target duration (${elapsed_time}s > ${TARGET_DURATION}s), no cadence wait needed"
        fi
    fi
    
    # Show progress
    local remaining=$((total_scans - scan_number))
    if [ "$remaining" -gt 0 ]; then
        log_info "🔄 Continuing to next scan: $((scan_number + 1))/$total_scans (${remaining} remaining)"
    fi
}

# Extract scan results from log file
extract_scan_results() {
    local log_file="$1"
    local job_name="$2"

    if [ ! -f "$log_file" ]; then
        echo "STATUS=UNKNOWN|SCAN_ID=N/A|BOM_URL=N/A|PROJECT=N/A"
        return 1
    fi

    local status="UNKNOWN"
    local scan_id="N/A"
    local bom_url="N/A"
    local project_name="N/A"
    local project_version="N/A"

    # Check if scan completed successfully
    if grep -q "✅ JOB COMPLETED SUCCESSFULLY" "$log_file" 2>/dev/null; then
        status="SUCCESS"
    elif grep -q "❌ JOB FAILED" "$log_file" 2>/dev/null; then
        status="FAILED"
    elif kill -0 "$(pgrep -f "$job_name" | head -1)" 2>/dev/null; then
        status="RUNNING"
    fi

    # Extract project name (BSD grep compatible)
    project_name=$(grep -o "detect\.project\.name='[^']*'" "$log_file" 2>/dev/null | head -1 | sed "s/detect.project.name='//;s/'//")
    [ -z "$project_name" ] && project_name="N/A"

    # Extract project version (BSD grep compatible)
    project_version=$(grep -o "detect\.project\.version\.name='[^']*'" "$log_file" 2>/dev/null | head -1 | sed "s/detect.project.version.name='//;s/'//")
    [ -z "$project_version" ] && project_version="N/A"

    # Extract scan ID from Black Duck Detect output (BSD grep compatible)
    scan_id=$(grep -o "[a-f0-9]\{8\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{12\}" "$log_file" 2>/dev/null | head -1)
    [ -z "$scan_id" ] && scan_id="N/A"

    # Extract BOM URL (various patterns from Detect output, BSD grep compatible)
    # Pattern 1: API URL with /api/projects/
    bom_url=$(grep -o "http[s]*://[^[:space:]]*/api/projects/[^[:space:]]*" "$log_file" 2>/dev/null | head -1)
    if [ -z "$bom_url" ]; then
        # Pattern 2: Look for "Project version URL:" line and extract URL
        bom_url=$(grep "Project version URL:" "$log_file" 2>/dev/null | head -1 | sed 's/.*\(http[s]*:\/\/[^[:space:]]*\).*/\1/')
    fi
    if [ -z "$bom_url" ]; then
        # Pattern 3: UI URL with /projects/
        bom_url=$(grep -o "http[s]*://[^[:space:]]*/projects/[^[:space:]]*" "$log_file" 2>/dev/null | head -1)
    fi
    [ -z "$bom_url" ] && bom_url="N/A"

    echo "STATUS=$status|SCAN_ID=$scan_id|BOM_URL=$bom_url|PROJECT=$project_name|VERSION=$project_version"
}

# Print scan statistics
print_scan_statistics() {
    log_info "==============================================="
    log_info "📊 SCAN EXECUTION SUMMARY"
    log_info "==============================================="
    log_info ""

    local total_scans=$((SIGNATURE_SCAN_COUNT + BINARY_SCAN_COUNT + CONTAINER_SCAN_COUNT + SNIPPET_SCAN_COUNT))

    log_info "Scan Type Distribution:"
    log_info "  • SIGNATURE_SCAN: $SIGNATURE_SCAN_COUNT scans"
    log_info "  • BINARY_SCAN: $BINARY_SCAN_COUNT scans"
    log_info "  • CONTAINER_SCAN: $CONTAINER_SCAN_COUNT scans"
    log_info "  • SNIPPET_SCAN: $SNIPPET_SCAN_COUNT scans"
    log_info "  • TOTAL: $total_scans scans"
    log_info ""

    if [ "${PARALLEL_SCANS}" == "yes" ]; then
        log_info "Parallel Execution Results:"
        get_job_status_summary
        log_info ""

        # Print detailed scan results
        if [ -d "${PARALLEL_LOG_DIR}" ]; then
            log_info "==============================================="
            log_info "📋 DETAILED SCAN RESULTS"
            log_info "==============================================="
            log_info ""

            local success_count=0
            local failed_count=0
            local running_count=0

            # Table header
            printf "%-40s %-10s %-38s\n" "PROJECT" "STATUS" "SCAN_ID" >&2
            printf "%-40s %-10s %-38s\n" "----------------------------------------" "----------" "--------------------------------------" >&2

            for log_file in "${PARALLEL_LOG_DIR}"/*.log; do
                if [ -f "$log_file" ]; then
                    local job_name=$(basename "$log_file" .log)
                    local result_line=$(extract_scan_results "$log_file" "$job_name")

                    # Parse result (BSD grep compatible)
                    local status=$(echo "$result_line" | sed -n 's/.*STATUS=\([^|]*\).*/\1/p')
                    local scan_id=$(echo "$result_line" | sed -n 's/.*SCAN_ID=\([^|]*\).*/\1/p')
                    local bom_url=$(echo "$result_line" | sed -n 's/.*BOM_URL=\([^|]*\).*/\1/p')
                    local project=$(echo "$result_line" | sed -n 's/.*PROJECT=\([^|]*\).*/\1/p')

                    # Count by status
                    case "$status" in
                        SUCCESS) ((success_count++)) ;;
                        FAILED) ((failed_count++)) ;;
                        RUNNING) ((running_count++)) ;;
                    esac

                    # Print row
                    printf "%-40s %-10s %-38s\n" "${project:0:40}" "$status" "$scan_id" >&2

                    # Print BOM URL if available
                    if [ "$bom_url" != "N/A" ]; then
                        printf "  └─ BOM: %s\n" "$bom_url" >&2
                    fi
                fi
            done

            log_info ""
            log_info "==============================================="
            log_info "Status Summary:"
            log_info "  ✅ Successful: $success_count"
            log_info "  ❌ Failed: $failed_count"
            log_info "  🔄 Running: $running_count"
        fi
    fi

    log_info ""
    log_info "==============================================="
}