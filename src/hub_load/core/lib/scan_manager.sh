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
    log_debug "📍 Function: init_scan_manager() [scan_manager.sh:35]"

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

# Execute a single scan with support for multiple versions and codelocations
execute_scan() {
    log_debug "📍 Function: execute_scan() [scan_manager.sh:71]"

    local scan_config="$1"
    local scan_id="$2"

    if [ -z "$scan_config" ]; then
        log_error "execute_scan requires scan_config parameter"
        return 1
    fi

    # Parse scan configuration (now includes snippets flag)
    local scan_type project_name scan_size scan_type_size snippets
    IFS='|' read -r scan_type project_name scan_size scan_type_size snippets <<< "$scan_config"

    # Set snippets flag (default to "no" if not provided for backward compatibility)
    snippets="${snippets:-no}"

    # Determine number of versions to create (matching legacy behavior)
    local num_versions=${MAX_VERSIONS:-1}

    # Discover files from test data directories if enhanced mode is enabled
    if [ "${ENHANCED_MULTI_SCAN}" == "yes" ] && [ -n "$scan_type_size" ]; then
        if [ "${DEBUG}" == "yes" ]; then
            log_info "🔍 Discovering files for $scan_type_size from test data directories (snippets: $snippets)"
        fi

        # Determine project root for file discovery
        local project_root="${LOCAL_TEST_DATA_DIR}/SCASS"
        if [ -n "$scan_type_size" ] && command -v get_local_directory_for_scan_type >/dev/null 2>&1; then
            project_root=$(get_local_directory_for_scan_type "$scan_type_size")
        fi

        # Discover files based on scan type and size, passing the snippets flag
        if discover_scan_files "$scan_type" "$scan_type_size" "$project_root" "$snippets"; then
            if [ "${DEBUG}" == "yes" ]; then
                log_success "File discovery completed: ${#DISCOVERED_FILES[@]} files available"
            fi

            # Select files for this specific scan
            if select_files_for_scan "$scan_type" "$scan_type_size" "${RANDOM_SCANS:-no}"; then
                if [ "${DEBUG}" == "yes" ]; then
                    log_info "Selected ${#SELECTED_PROJECT_FILES[@]} files for scan"
                fi
            else
                log_warning "File selection failed, falling back to file preparation"
            fi
        else
            log_warning "File discovery failed, falling back to file preparation"
        fi
    fi

    # Loop through versions (matching legacy script behavior)
    for ((version=1; version<=num_versions; version++)); do
        if [ "$num_versions" -gt 1 ] && [ "${DEBUG}" == "yes" ]; then
            log_info "Processing version $version of $num_versions"
        fi

        # Loop through codelocations (matching legacy script behavior)
        local num_codelocations=${MAX_CODELOCATIONS:-1}
        for ((cl=1; cl<=num_codelocations; cl++)); do
            if [ "$num_codelocations" -gt 1 ] && [ "${DEBUG}" == "yes" ]; then
                log_info "Processing codelocation $cl of $num_codelocations"
            fi

            # Execute single scan for this version/codelocation combination
            execute_single_scan "$scan_config" "$scan_id" "$version" "$cl" "$snippets"
        done
    done

    return 0
}

# Write scan metadata to file for later reporting
write_scan_metadata() {
    local metadata_file="$1"
    local scan_id="$2"
    local project_name="$3"
    local version_name="$4"
    local cl_name="$5"
    local scan_type_size="$6"
    local files_list="$7"
    local scan_start_time="$8"

    cat > "$metadata_file" <<EOF
SCAN_ID=$scan_id
PROJECT_NAME=$project_name
VERSION_NAME=$version_name
CODELOCATION_NAME=$cl_name
SCAN_TYPE_SIZE=$scan_type_size
FILES_USED=$files_list
SCAN_START_TIME=$scan_start_time
SCAN_START_TIMESTAMP=$(date -r "$scan_start_time" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -d "@$scan_start_time" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "N/A")
EOF
}

# Execute a single scan for a specific version and codelocation
execute_single_scan() {
    local scan_config="$1"
    local scan_id="$2"
    local version="$3"
    local codelocation_num="$4"
    local snippets="$5"

    # Parse scan configuration
    local scan_type project_name scan_size scan_type_size
    IFS='|' read -r scan_type project_name scan_size scan_type_size _ <<< "$scan_config"

    # Generate timestamp for this specific scan (HHMMSS format for tracking)
    local scan_timestamp=$(date '+%H%M%S')
    local scan_date=$(date '+%d%m%Y')
    local full_timestamp=$(date '+%Y%m%d-%H%M%S')
    local scan_start_epoch=$(date +%s)

    # Generate version name with timestamp for easy tracking (format: v1-YYYYMMDD-HHMMSS)
    local version_name="v${version}-${full_timestamp}"

    # Determine log file path for this scan with detailed timestamp
    local log_dir="${PARALLEL_LOG_DIR:-${LOG_DIR:-/app/logs}/parallel}"

    # Ensure log directory exists before writing files
    mkdir -p "$log_dir"

    local log_file="${log_dir}/${scan_id}_v${version}_cl${codelocation_num}_${scan_timestamp}_${scan_type_size}.log"
    local metadata_file="${log_dir}/${scan_id}_v${version}_cl${codelocation_num}_${scan_timestamp}_${scan_type_size}.meta"

    # Generate codelocation name with randomization and timestamp for easy tracking
    local cl_random=$RANDOM
    local container_id=$(hostname 2>/dev/null || echo "local")
    local cl_name
    if [ "${scan_type}" == "BINARY_SCAN" ]; then
        cl_name="${container_id}-binary-cl-${codelocation_num}-${cl_random}-${scan_date}"
    elif [ "${scan_type}" == "CONTAINER_SCAN" ]; then
        cl_name="${container_id}-container-cl-${codelocation_num}-${cl_random}-${scan_date}"
    else
        cl_name="${container_id}-cl-${codelocation_num}-${cl_random}-${scan_date}"
    fi

    # Concise summary logged only when NOT in DEBUG mode
    if [ "${DEBUG}" != "yes" ]; then
        log_info "🚀 Scan: $scan_type_size | Project: $project_name | Version: $version_name | CL: $cl_name"
        echo "$(date '+%Y-%m-%d %H:%M:%S') -    📄 Log: $log_file"
    else
        log_info "Executing scan: $scan_type for project $project_name (version: $version_name, codelocation: $cl_name, size: $scan_size, snippets: $snippets)"
        log_info "Log file: $log_file"
    fi

    # Prepare scan environment with Project/cl-X/source structure
    local base_scan_dir="/tmp/scan_${scan_id}_$$"
    local scan_dir="${base_scan_dir}/${project_name}/cl-${codelocation_num}/source"
    mkdir -p "$scan_dir"

    # If files were discovered and selected, use them directly
    if [ -n "${SELECTED_PROJECT_FILES[*]}" ] && [ ${#SELECTED_PROJECT_FILES[@]} -gt 0 ]; then
        if [ "${DEBUG}" == "yes" ]; then
            log_info "Using discovered files for scan (${#SELECTED_PROJECT_FILES[@]} files)"
        fi

        # Create symbolic links or copy files to scan directory
        local linked_count=0
        local total_size_bytes=0
        local file_list=()
        for source_file in "${SELECTED_PROJECT_FILES[@]}"; do
            if [ -f "$source_file" ]; then
                local filename=$(basename "$source_file")
                if ln -sf "$source_file" "$scan_dir/$filename" 2>/dev/null; then
                    ((linked_count++))
                    # Calculate file size (cross-platform)
                    local file_size
                    if command -v stat >/dev/null 2>&1; then
                        # Try macOS format first, then Linux format
                        file_size=$(stat -f%z "$source_file" 2>/dev/null || stat -c%s "$source_file" 2>/dev/null || echo 0)
                    else
                        file_size=0
                    fi
                    total_size_bytes=$((total_size_bytes + file_size))

                    # Store filename and path for logging
                    if [ "${DEBUG}" == "yes" ]; then
                        file_list+=("$source_file")
                    else
                        file_list+=("$filename")
                    fi
                fi
            fi
        done

        if [ "$linked_count" -gt 0 ]; then
            # Format size for display (human-readable)
            local total_size_display
            if [ "$total_size_bytes" -ge 1073741824 ]; then
                # GB
                total_size_display="$(awk "BEGIN {printf \"%.2f\", $total_size_bytes/1073741824}")GB"
            elif [ "$total_size_bytes" -ge 1048576 ]; then
                # MB
                total_size_display="$(awk "BEGIN {printf \"%.2f\", $total_size_bytes/1048576}")MB"
            elif [ "$total_size_bytes" -ge 1024 ]; then
                # KB
                total_size_display="$(awk "BEGIN {printf \"%.2f\", $total_size_bytes/1024}")KB"
            else
                # Bytes
                total_size_display="${total_size_bytes}B"
            fi

            # Prepare file list for metadata (comma-separated basenames)
            local files_metadata=$(printf ",%s" "${file_list[@]}")
            files_metadata="${files_metadata:1}"  # Remove leading comma

            # Write scan metadata for later reporting
            write_scan_metadata "$metadata_file" "$scan_id" "$project_name" "$version_name" "$cl_name" "$scan_type_size" "$files_metadata" "$scan_start_epoch"

            # Concise summary for non-DEBUG mode
            if [ "${DEBUG}" != "yes" ]; then
                log_info "   Files: $linked_count ($total_size_display) | Code location: $scan_dir"
                # List filenames concisely
                local file_names_str=$(printf ", %s" "${file_list[@]}")
                file_names_str=${file_names_str:2}  # Remove leading ", "
                log_info "   └─ Files: $file_names_str"
            else
                log_success "Prepared $linked_count files using symbolic links (Total size: $total_size_display)"
                # List full paths in DEBUG mode
                log_info "Selected files:"
                for file_path in "${file_list[@]}"; do
                    log_info "  • $file_path"
                done
            fi
        else
            log_error "═══════════════════════════════════════════════════════════"
            log_error "❌ SCAN FAILED: Unable to link discovered files to scan directory"
            log_error "═══════════════════════════════════════════════════════════"
            log_error "Scan Type: ${scan_type_size}"
            log_error "Scan Directory: ${scan_dir}"
            log_error ""
            log_error "This usually indicates:"
            log_error "  • File permission issues"
            log_error "  • Filesystem doesn't support symbolic links"
            log_error "  • Source files were deleted or moved"
            log_error ""
            log_error "Check file permissions and ensure test data is accessible"
            log_error "═══════════════════════════════════════════════════════════"
            return 1
        fi
    else
        # No files were discovered/selected
        log_error "═══════════════════════════════════════════════════════════"
        log_error "❌ SCAN FAILED: No test data files found"
        log_error "═══════════════════════════════════════════════════════════"
        log_error "Scan Type: ${scan_type_size}"
        log_error "Scan Type Base: ${scan_type}"
        log_error "LOCAL_TEST_DATA_DIR: ${LOCAL_TEST_DATA_DIR}"
        log_error ""
        log_error "Expected test data location:"
        local expected_dir=$(get_local_directory_for_scan_type "$scan_type_size" 2>/dev/null || echo "${LOCAL_TEST_DATA_DIR}")
        log_error "  ${expected_dir}"
        log_error ""
        log_error "Troubleshooting steps:"
        log_error "  1. Verify LOCAL_TEST_DATA_DIR is set correctly"
        log_error "  2. Check that test data directories exist:"
        log_error "     ls -la ${LOCAL_TEST_DATA_DIR}/"
        log_error "  3. Ensure test data files are present:"
        log_error "     ls -la ${expected_dir}/"
        log_error "  4. Verify file extensions match scan type (.tar for container, etc.)"
        log_error "═══════════════════════════════════════════════════════════"
        return 1
    fi

    # Generate scan command with version and codelocation info
    # For signature scans, use codelocation-level directory; for binary/container, use source directory
    local cl_dir="${base_scan_dir}/${project_name}/cl-${codelocation_num}"
    local scan_command
    scan_command=$(generate_scan_command "$scan_type" "$project_name" "$scan_dir" "$cl_dir" "$version_name" "$cl_name")

    # Print the complete Detect command for visibility
    echo ""
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ═══════════════════════════════════════════════════════════"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 🔧 DETECT COMMAND ARGUMENTS:"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ═══════════════════════════════════════════════════════════"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ℹ️  SYNCHRONOUS_SCANS='${SYNCHRONOUS_SCANS}'"
    echo "$scan_command" | sed 's/ --/\n  --/g'
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ═══════════════════════════════════════════════════════════"
    echo ""

    if [ "${PARALLEL_SCANS}" == "yes" ]; then
        # Execute in parallel
        local job_name="${scan_type}_${project_name}_${scan_id}"
        local log_file="${PARALLEL_LOG_DIR}/${job_name}.log"

        start_parallel_job "$job_name" "$scan_command" "$log_file"
    else
        # Execute synchronously
        if [ "${DEBUG}" == "yes" ]; then
            log_info "Starting synchronous scan execution"
        fi
        local start_time=$(date +%s)

        if eval "$scan_command"; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            # Send success message to stdout for pipeline processing
            echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Scan completed successfully in ${duration}s"

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
    log_debug "📍 Function: generate_scan_command() [scan_manager.sh:374]"

    local scan_type="$1"
    local project_name="$2"
    local scan_dir="$3"
    local cl_dir="$4"
    local version="$5"
    local cl_name="$6"

    # Change to codelocation directory for execution (matching legacy script)
    local base_command="cd '$cl_dir' && "

    case "$scan_type" in
        SIGNATURE_SCAN)
            base_command+="bash <(curl -s -L https://detect.blackduck.com/detect.sh)"
            base_command+=" --blackduck.url='$BD_HUB_URL'"
            base_command+=" --blackduck.api.token='$API_TOKEN'"
            base_command+=" --blackduck.trust.cert=true"
            base_command+=" --detect.project.name='$project_name'"
            base_command+=" --detect.project.version.name='$version'"
            base_command+=" --detect.code.location.name='$cl_name'"
            base_command+=" --detect.timeout='$API_TIMEOUT'"
            base_command+=" --detect.tools='SIGNATURE_SCAN'"
            base_command+=" --detect.parallel.processors=-1"
            base_command+=" --detect.source.path='$scan_dir'"
            base_command+=" --detect.cleanup=true"

            # Add snippet-specific parameters if this is a snippet scan
            if [ "${SNIPPETS:-no}" == "yes" ]; then
                base_command+=" --detect.blackduck.signature.scanner.snippet.matching=SNIPPET_MATCHING"
                base_command+=" --detect.blackduck.signature.scanner.upload.source.mode=true"
                log_debug "Snippet scan parameters added: snippet.matching=SNIPPET_MATCHING, upload.source.mode=true"
            fi

            if [ "${STRING_SEARCH}" == "yes" ]; then
                base_command+=" --detect.blackduck.signature.scanner.license.search=true"
                base_command+=" --detect.blackduck.signature.scanner.copyright.search=true"
            fi

            # Add debug logging if enabled
            if [ "${DEBUG}" == "yes" ]; then
                base_command+=" --logging.level.detect=TRACE"
            fi
            ;;
        BINARY_SCAN)
            # Get first binary file from scan directory (follow symlinks with -L)
            local binary_file=$(find -L "$scan_dir" -type f \( -name "*.exe" -o -name "*.dmg" -o -name "*.msi" -o -name "*.deb" -o -name "*.rpm" -o -name "*.pkg" -o -name "*.lib" -o -name "*.cab" -o -name "*.img" -o -name "*.iso" -o -name "*.vmdk" -o -name "*.ova" -o -name "*.vdi" -o -name "*.ubifs" -o -name "*.tar.gz" -o -name "*.tgz" \) 2>/dev/null | head -1)

            base_command+="bash <(curl -s -L https://detect.blackduck.com/detect.sh)"
            base_command+=" --blackduck.url='$BD_HUB_URL'"
            base_command+=" --blackduck.api.token='$API_TOKEN'"
            base_command+=" --blackduck.trust.cert=true"
            base_command+=" --detect.project.name='$project_name'"
            base_command+=" --detect.project.version.name='$version'"
            base_command+=" --detect.code.location.name='$cl_name'"
            base_command+=" --detect.timeout='$API_TIMEOUT'"
            base_command+=" --detect.tools='BINARY_SCAN'"
            base_command+=" --detect.parallel.processors=-1"
            base_command+=" --detect.cleanup=true"

            # Add binary scan file path if found
            if [ -n "$binary_file" ]; then
                base_command+=" --detect.binary.scan.file.path='$binary_file'"
                log_debug "Binary scan will upload: $binary_file"
            else
                log_warning "No binary file found in $scan_dir for binary scan"
            fi

            # Add debug logging if enabled
            if [ "${DEBUG}" == "yes" ]; then
                base_command+=" --logging.level.detect=TRACE"
            fi
            ;;
        CONTAINER_SCAN)
            # Get first container tar file from scan directory (follow symlinks with -L)
            local container_file=$(find -L "$scan_dir" -type f -name "*.tar" 2>/dev/null | head -1)

            base_command+="bash <(curl -s -L https://detect.blackduck.com/detect.sh)"
            base_command+=" --blackduck.url='$BD_HUB_URL'"
            base_command+=" --blackduck.api.token='$API_TOKEN'"
            base_command+=" --blackduck.trust.cert=true"
            base_command+=" --detect.project.name='$project_name'"
            base_command+=" --detect.project.version.name='$version'"
            base_command+=" --detect.timeout='$API_TIMEOUT'"
            base_command+=" --detect.tools='CONTAINER_SCAN'"
            base_command+=" --detect.cleanup=true"

            # Add container image path if found (using legacy parameter name)
            if [ -n "$container_file" ]; then
                base_command+=" --detect.container.scan.file.path='$container_file'"
                log_debug "Container scan will analyze: $container_file"
            else
                log_warning "No container tar file found in $scan_dir for container scan"
            fi

            # Add debug logging if enabled
            if [ "${DEBUG}" == "yes" ]; then
                base_command+=" --logging.level.detect=TRACE"
                base_command+=" --detect.diagnostic=true"
            fi
            ;;
        *)
            log_error "Unknown scan type: $scan_type"
            return 1
            ;;
    esac

    # Add synchronous scan support (common to all scan types)
    if [ "${SYNCHRONOUS_SCANS}" == "yes" ]; then
        base_command+=" --detect.wait.for.results=true"
    fi

    # Add failure on severities if specified (common to all scan types)
    if [ "${FAIL_ON_SEVERITIES}" != "NONE" ] && [ -n "${FAIL_ON_SEVERITIES}" ]; then
        base_command+=" --detect.policy.check.fail.on.severities='$FAIL_ON_SEVERITIES'"
    fi

    echo "$base_command"
}

# Run multiple scans based on configuration
run_scan_batch() {
    log_debug "📍 Function: run_scan_batch() [scan_manager.sh:492]"

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
            # Strategy: Use background for ALL scans to maintain cadence control
            # The "sequential with overflow" means we try to have one primary scan, but if it
            # blocks the next cadence, we start the next scan in an overflow slot

            local use_overflow=true  # ALWAYS use background/overflow in this mode
            local next_scan_expected=$((current_time + TARGET_DURATION))

            # Check if there's a next scan coming
            if [ "$current_scan" -lt "$max_scans" ]; then
                # Check if we have overflow capacity
                if [ "$running_count" -lt "${MAX_PARALLEL_JOBS:-3}" ]; then
                    # We have overflow capacity available
                    use_overflow=true
                    if [ "$running_count" -eq 0 ]; then
                        log_info "▶️  Sequential mode: Starting scan $current_scan in background (primary)"
                    else
                        log_info "🔀 Overflow mode: Starting scan $current_scan in background (slot $((running_count + 1))/${MAX_PARALLEL_JOBS:-3})"
                    fi
                else
                    # All overflow slots full - MUST wait for one to complete
                    log_warning "⏸️  All overflow slots full ($running_count/${MAX_PARALLEL_JOBS:-3})"
                    log_info "⏳ Waiting for overflow slot to free up (no skipping)"
                    wait_for_parallel_slot 0  # Wait indefinitely - no timeout, no skipping
                    running_count=$(get_running_job_count)
                    log_info "✅ Overflow slot freed - continuing"
                    use_overflow=true
                    log_info "▶️  Sequential mode: Starting scan $current_scan in background (primary)"
                fi
            else
                # Last scan - still use background for consistency
                use_overflow=true
                log_info "▶️  Final scan: Starting scan $current_scan in background"
            fi

            # Execute in background (overflow slot)
            # Generate scan_id with timestamp and randomization for easy tracking
            local scan_timestamp=$(date '+%Y%m%d-%H%M%S')
            local scan_random=$RANDOM
            local scan_id="scan_${current_scan}_${scan_random}_${scan_timestamp}"
            log_info "🚀 Starting scan $current_scan in background"
            if ! execute_scan "$scan_config" "$scan_id"; then
                log_error "Scan $current_scan failed to start"
            fi
            # Continue immediately to next cadence check (scan runs in background)
        else
            # PURE SEQUENTIAL MODE - original behavior
            # Capture scan start time for cadence calculation
            local scan_start_time=$(date +%s)

            # Generate scan_id with timestamp and randomization for easy tracking
            local scan_timestamp=$(date '+%Y%m%d-%H%M%S')
            local scan_random=$RANDOM
            local scan_id="scan_${current_scan}_${scan_random}_${scan_timestamp}"
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
    # Generate timestamp in format: DDMMYYYY-HHMMSS (matching legacy script)
    local timestamp=$(date '+%d%m%Y-%H%M%S')
    local random_id=$RANDOM

    # Use the enhanced multi-scan configuration (already sourced by common.sh)
    # DO NOT re-source here as it resets global counters!
    if command -v select_scan_type_with_size >/dev/null 2>&1; then
        # Use the sophisticated scan type selection (preserve logging to stderr)
        local scan_type_size
        scan_type_size=$(select_scan_type_with_size)

        if [ "$scan_type_size" == "NO_FILES_AVAILABLE" ]; then
            log_warning "No files available for enhanced multi-scan, falling back to default"
            local scan_type="${SCAN_TYPE:-SIGNATURE_SCAN}"
            local project_name="test-project-${random_id}-on-${timestamp}"
            local scan_size="MEDIUM"
            local snippets="no"
            echo "${scan_type}|${project_name}|${scan_size}||${snippets}"
            return
        fi

        # Parse the enhanced scan type selection
        local scan_info=($(parse_scan_type_and_size "$scan_type_size"))
        local scan_type="${scan_info[0]}"
        local scan_size="${scan_info[1]}"

        # Handle snippet scans (they use SIGNATURE_SCAN as base)
        local snippets="no"
        if [[ "$scan_type_size" == "SNIPPET_SCAN"* ]]; then
            scan_type="SIGNATURE_SCAN"
            snippets="yes"
        fi

        # Generate project name with randomization and timestamp for easy tracking
        local scan_type_lower=$(echo "$scan_type_size" | tr '[:upper:]' '[:lower:]')
        local project_name="enhanced-${scan_type_lower}-${random_id}-on-${timestamp}"

        log_debug "Enhanced scan config: $scan_type_size -> $scan_type/$scan_size (snippets=$snippets)"
        echo "${scan_type}|${project_name}|${scan_size}|${scan_type_size}|${snippets}"
    else
        log_warning "Enhanced multi-scan config not found, using basic configuration"
        local scan_type="${SCAN_TYPE:-SIGNATURE_SCAN}"
        local project_name="test-project-${random_id}-on-${timestamp}"
        local scan_size="MEDIUM"
        local snippets="no"
        echo "${scan_type}|${project_name}|${scan_size}||${snippets}"
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
        local wait_time
        wait_time=$(calculate_wait_time "$scan_start_time" "$TARGET_DURATION")

        if [ "$wait_time" -gt 0 ]; then
            local description="Sequential scan cadence (${TARGET_DURATION}s target, spacing scan $((scan_number + 1)))"
            log_info "⏱️  Cadence wait: ${wait_time}s before scan $((scan_number + 1)) starts"
            smart_sleep "$wait_time" "$description" "$((scan_number + 1))"
        else
            local current_time=$(date +%s)
            local elapsed_time=$((current_time - scan_start_time))
            log_info "⚡ Scan exceeded target duration (${elapsed_time}s > ${TARGET_DURATION}s), starting scan $((scan_number + 1)) immediately"
        fi
    fi
    
    # Show progress
    local remaining=$((total_scans - scan_number))
    if [ "$remaining" -gt 0 ]; then
        log_info "🔄 Continuing to next scan: $((scan_number + 1))/$total_scans (${remaining} remaining)"
    fi
}

# Extract scan results from log file and metadata
extract_scan_results() {
    local log_file="$1"
    local job_name="$2"

    if [ ! -f "$log_file" ]; then
        echo "STATUS=UNKNOWN|SCAN_ID=N/A|BOM_URL=N/A|PROJECT=N/A|VERSION=N/A|CODELOCATION=N/A|SCAN_TYPE_SIZE=N/A|FILES=N/A|START_TIME=N/A|COMPLETION_TIME=N/A"
        return 1
    fi

    local status="UNKNOWN"
    local scan_id="N/A"
    local bom_url="N/A"
    local project_name="N/A"
    local project_version="N/A"
    local codelocation_name="N/A"
    local scan_type_size="N/A"
    local files_used="N/A"
    local start_time="N/A"
    local completion_time="N/A"

    # Check if scan completed successfully
    if grep -q "✅ Scan completed successfully" "$log_file" 2>/dev/null; then
        status="SUCCESS"
        # Extract completion timestamp
        completion_time=$(grep "✅ Scan completed successfully" "$log_file" 2>/dev/null | head -1 | sed 's/^\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\).*/\1/')
    elif grep -q "✅ JOB COMPLETED SUCCESSFULLY" "$log_file" 2>/dev/null; then
        status="SUCCESS"
        completion_time=$(grep "✅ JOB COMPLETED SUCCESSFULLY" "$log_file" 2>/dev/null | head -1 | sed 's/^\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\).*/\1/')
    elif grep -q "❌ JOB FAILED" "$log_file" 2>/dev/null; then
        status="FAILED"
    elif kill -0 "$(pgrep -f "$job_name" | head -1)" 2>/dev/null; then
        status="RUNNING"
    fi

    # Try to read metadata file first (preferred source)
    local metadata_file="${log_file%.log}.meta"
    if [ -f "$metadata_file" ]; then
        # Source metadata file to get variables
        while IFS='=' read -r key value; do
            case "$key" in
                SCAN_ID) scan_id="$value" ;;
                PROJECT_NAME) project_name="$value" ;;
                VERSION_NAME) project_version="$value" ;;
                CODELOCATION_NAME) codelocation_name="$value" ;;
                SCAN_TYPE_SIZE) scan_type_size="$value" ;;
                FILES_USED) files_used="$value" ;;
                SCAN_START_TIMESTAMP) start_time="$value" ;;
            esac
        done < "$metadata_file"
    fi

    # Fallback to extracting from log file if metadata not available
    if [ "$project_name" == "N/A" ]; then
        project_name=$(grep -o "detect\.project\.name='[^']*'" "$log_file" 2>/dev/null | head -1 | sed "s/detect.project.name='//;s/'//")
        [ -z "$project_name" ] && project_name="N/A"
    fi

    if [ "$project_version" == "N/A" ]; then
        project_version=$(grep -o "detect\.project\.version\.name='[^']*'" "$log_file" 2>/dev/null | head -1 | sed "s/detect.project.version.name='//;s/'//")
        [ -z "$project_version" ] && project_version="N/A"
    fi

    if [ "$codelocation_name" == "N/A" ]; then
        codelocation_name=$(grep -o "detect\.code\.location\.name='[^']*'" "$log_file" 2>/dev/null | head -1 | sed "s/detect.code.location.name='//;s/'//")
        [ -z "$codelocation_name" ] && codelocation_name="N/A"
    fi

    # Extract scan ID from Black Duck Detect output (BSD grep compatible)
    if [ "$scan_id" == "N/A" ]; then
        scan_id=$(grep -o "[a-f0-9]\{8\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{12\}" "$log_file" 2>/dev/null | head -1)
        [ -z "$scan_id" ] && scan_id="N/A"
    fi

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

    echo "STATUS=$status|SCAN_ID=$scan_id|BOM_URL=$bom_url|PROJECT=$project_name|VERSION=$project_version|CODELOCATION=$codelocation_name|SCAN_TYPE_SIZE=$scan_type_size|FILES=$files_used|START_TIME=$start_time|COMPLETION_TIME=$completion_time"
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
    if [ "$SIGNATURE_SCAN_SMALL_COUNT" -gt 0 ] || [ "$SIGNATURE_SCAN_MEDIUM_COUNT" -gt 0 ] || [ "$SIGNATURE_SCAN_LARGE_COUNT" -gt 0 ] || [ "$SIGNATURE_SCAN_XLARGE_COUNT" -gt 0 ]; then
        log_info "    ├─ SMALL:  $SIGNATURE_SCAN_SMALL_COUNT"
        log_info "    ├─ MEDIUM: $SIGNATURE_SCAN_MEDIUM_COUNT"
        log_info "    ├─ LARGE:  $SIGNATURE_SCAN_LARGE_COUNT"
        log_info "    └─ XLARGE: $SIGNATURE_SCAN_XLARGE_COUNT"
    fi
    log_info "  • BINARY_SCAN: $BINARY_SCAN_COUNT scans"
    if [ "$BINARY_SCAN_SMALL_COUNT" -gt 0 ] || [ "$BINARY_SCAN_MEDIUM_COUNT" -gt 0 ] || [ "$BINARY_SCAN_LARGE_COUNT" -gt 0 ] || [ "$BINARY_SCAN_XLARGE_COUNT" -gt 0 ]; then
        log_info "    ├─ SMALL:  $BINARY_SCAN_SMALL_COUNT"
        log_info "    ├─ MEDIUM: $BINARY_SCAN_MEDIUM_COUNT"
        log_info "    ├─ LARGE:  $BINARY_SCAN_LARGE_COUNT"
        log_info "    └─ XLARGE: $BINARY_SCAN_XLARGE_COUNT"
    fi
    log_info "  • CONTAINER_SCAN: $CONTAINER_SCAN_COUNT scans"
    if [ "$CONTAINER_SCAN_SMALL_COUNT" -gt 0 ] || [ "$CONTAINER_SCAN_MEDIUM_COUNT" -gt 0 ] || [ "$CONTAINER_SCAN_LARGE_COUNT" -gt 0 ] || [ "$CONTAINER_SCAN_XLARGE_COUNT" -gt 0 ]; then
        log_info "    ├─ SMALL:  $CONTAINER_SCAN_SMALL_COUNT"
        log_info "    ├─ MEDIUM: $CONTAINER_SCAN_MEDIUM_COUNT"
        log_info "    ├─ LARGE:  $CONTAINER_SCAN_LARGE_COUNT"
        log_info "    └─ XLARGE: $CONTAINER_SCAN_XLARGE_COUNT"
    fi
    log_info "  • SNIPPET_SCAN: $SNIPPET_SCAN_COUNT scans"
    if [ "$SNIPPET_SCAN_SMALL_COUNT" -gt 0 ] || [ "$SNIPPET_SCAN_MEDIUM_COUNT" -gt 0 ] || [ "$SNIPPET_SCAN_LARGE_COUNT" -gt 0 ] || [ "$SNIPPET_SCAN_XLARGE_COUNT" -gt 0 ]; then
        log_info "    ├─ SMALL:  $SNIPPET_SCAN_SMALL_COUNT"
        log_info "    ├─ MEDIUM: $SNIPPET_SCAN_MEDIUM_COUNT"
        log_info "    ├─ LARGE:  $SNIPPET_SCAN_LARGE_COUNT"
        log_info "    └─ XLARGE: $SNIPPET_SCAN_XLARGE_COUNT"
    fi
    log_info "  • TOTAL: $total_scans scans"
    log_info ""

    # Print detailed scan results for both sequential and parallel modes
    local log_dir="${PARALLEL_LOG_DIR:-${LOG_DIR:-/app/logs}/parallel}"

    if [ "${PARALLEL_SCANS}" == "yes" ]; then
        log_info "Parallel Execution Results:"
        get_job_status_summary
        log_info ""
    fi

    # Print detailed scan results (works for both sequential and parallel modes)
    if [ -d "$log_dir" ]; then
        log_info "==============================================="
        log_info "📋 DETAILED SCAN RESULTS"
        log_info "==============================================="
        log_info ""

        local success_count=0
        local failed_count=0
        local running_count=0

        # Comprehensive table header
        echo ""
        printf "%-20s %-15s %-10s %-30s %-19s %-19s\n" "SCAN TYPE" "SIZE" "STATUS" "PROJECT" "START TIME" "COMPLETION TIME"
        printf "%-20s %-15s %-10s %-30s %-19s %-19s\n" "--------------------" "---------------" "----------" "------------------------------" "-------------------" "-------------------"

        for log_file in "$log_dir"/*.log; do
            if [ -f "$log_file" ]; then
                local job_name=$(basename "$log_file" .log)
                local result_line=$(extract_scan_results "$log_file" "$job_name")

                # Parse result (BSD grep compatible)
                local status=$(echo "$result_line" | sed -n 's/.*STATUS=\([^|]*\).*/\1/p')
                local scan_id=$(echo "$result_line" | sed -n 's/.*SCAN_ID=\([^|]*\).*/\1/p')
                local bom_url=$(echo "$result_line" | sed -n 's/.*BOM_URL=\([^|]*\).*/\1/p')
                local project=$(echo "$result_line" | sed -n 's/.*PROJECT=\([^|]*\).*/\1/p')
                local version=$(echo "$result_line" | sed -n 's/.*VERSION=\([^|]*\).*/\1/p')
                local codelocation=$(echo "$result_line" | sed -n 's/.*CODELOCATION=\([^|]*\).*/\1/p')
                local scan_type_size=$(echo "$result_line" | sed -n 's/.*SCAN_TYPE_SIZE=\([^|]*\).*/\1/p')
                local files=$(echo "$result_line" | sed -n 's/.*FILES=\([^|]*\).*/\1/p')
                local start_time=$(echo "$result_line" | sed -n 's/.*START_TIME=\([^|]*\).*/\1/p')
                local completion_time=$(echo "$result_line" | sed -n 's/.*COMPLETION_TIME=\([^|]*\).*/\1/p')

                # Parse scan type and size from scan_type_size
                local scan_type_display="N/A"
                local size_display="N/A"
                if [[ "$scan_type_size" =~ ^(BINARY_SCAN|SIGNATURE_SCAN|CONTAINER_SCAN|SNIPPET_SCAN)_(SMALL|MEDIUM|LARGE|XLARGE)$ ]]; then
                    scan_type_display="${BASH_REMATCH[1]}"
                    size_display="${BASH_REMATCH[2]}"
                elif [[ "$scan_type_size" == "SNIPPET_SCAN" ]]; then
                    scan_type_display="SNIPPET_SCAN"
                    size_display="MEDIUM"
                elif [ "$scan_type_size" != "N/A" ]; then
                    scan_type_display="$scan_type_size"
                fi

                # Count by status
                case "$status" in
                    SUCCESS) ((success_count++)) ;;
                    FAILED) ((failed_count++)) ;;
                    RUNNING) ((running_count++)) ;;
                esac

                # Print main row
                printf "%-20s %-15s %-10s %-30s %-19s %-19s\n" \
                    "${scan_type_display:0:20}" \
                    "${size_display:0:15}" \
                    "$status" \
                    "${project:0:30}" \
                    "${start_time:0:19}" \
                    "${completion_time:0:19}"

                # Print additional details as sub-rows
                printf "  Version: %-50s  Codelocation: %s\n" "${version:0:50}" "${codelocation:0:60}"
                printf "  Files: %s\n" "$files"
                if [ "$bom_url" != "N/A" ]; then
                    printf "  BOM URL: %s\n" "$bom_url"
                fi
                printf "  Log: %s\n" "$log_file"
                echo ""
            fi
        done

        log_info ""
        log_info "==============================================="

        # Send status summary to stdout for pipeline processing
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 📊 Status Summary:"
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   ✅ Successful: $success_count"
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   ❌ Failed: $failed_count"
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   🔄 Running: $running_count"
    fi

    log_info ""
    log_info "==============================================="
}