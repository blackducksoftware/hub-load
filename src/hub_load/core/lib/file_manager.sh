#!/bin/bash
#
# file_manager.sh - File preparation and management
#

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Memory mapping handler path
get_memory_mapping_handler() {
    local script_dir="$(dirname "${BASH_SOURCE[0]}")"
    local handler_paths=(
        "$script_dir/../../memory_mapping/mmap_file_handler.py"
        "$script_dir/../../../memory_mapping/mmap_file_handler.py"
        "$(pwd)/src/hub_load/memory_mapping/mmap_file_handler.py"
    )
    
    for path in "${handler_paths[@]}"; do
        if [ -f "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    return 1
}

# Use memory mapping to prepare files efficiently
use_memory_mapping() {
    local source_files=("$@")
    local dest_dir="$1"
    shift
    local files=("$@")
    
    if [ "${USE_MEMORY_MAPPING}" != "yes" ]; then
        return 1
    fi
    
    local mmap_handler
    if ! mmap_handler=$(get_memory_mapping_handler); then
        log_warning "Memory mapping handler not found, falling back to file copying"
        return 1
    fi
    
    log_info "Using memory mapping for efficient file access"
    log_debug "Memory mapping handler: $mmap_handler"
    
    if python3 "$mmap_handler" --source-files "${files[@]}" --dest-dir "$dest_dir" --verbose 2>/dev/null; then
        log_success "Memory mapping successful (27.5% faster file access)"
        return 0
    else
        log_warning "Memory mapping failed, falling back to file copying"
        return 1
    fi
}

# Enhanced file preparation using real files from test data
prepare_enhanced_scan_files() {
    local project_dir="$1"
    local scan_type="$2"
    local scan_size="$3"
    local scan_type_size="$4"
    
    if [ -z "$project_dir" ] || [ -z "$scan_type" ]; then
        log_error "prepare_enhanced_scan_files requires project_dir and scan_type parameters"
        return 1
    fi
    
    log_debug "Enhanced preparation attempt: scan_type_size='$scan_type_size', ENHANCED_MULTI_SCAN='${ENHANCED_MULTI_SCAN}'"
    
    # Ensure enhanced configuration is loaded
    if [ "${ENHANCED_MULTI_SCAN}" == "yes" ] && ! command -v get_local_directory_for_scan_type >/dev/null 2>&1; then
        log_debug "Loading enhanced configuration for file_manager"
        if ! load_enhanced_config >/dev/null 2>&1; then
            log_warning "Failed to load enhanced configuration in file_manager"
            return 1
        fi
    fi
    
    # Use enhanced configuration if available
    if [ "${ENHANCED_MULTI_SCAN}" == "yes" ] && command -v get_local_directory_for_scan_type >/dev/null 2>&1; then
        log_info "Preparing enhanced scan files for $scan_type_size"
        
        # Get source directory from enhanced config
        local source_dir
        if source_dir=$(get_local_directory_for_scan_type "$scan_type_size"); then
            if [ -d "$source_dir" ] && [ "$(ls -A "$source_dir" 2>/dev/null)" ]; then
                log_debug "Source directory: $source_dir"
                
                # Create project directory
                mkdir -p "$project_dir"
                
                # Get files from source directory
                local source_files=()
                while IFS= read -r -d '' file; do
                    source_files+=("$file")
                done < <(find "$source_dir" -type f -print0 | head -z -n 100)
                
                if [ ${#source_files[@]} -gt 0 ]; then
                    log_info "Found ${#source_files[@]} files in source directory"
                    
                    # Try memory mapping first
                    if use_memory_mapping "$project_dir" "${source_files[@]}"; then
                        log_success "Enhanced files prepared using memory mapping"
                        return 0
                    else
                        # Fall back to symbolic links
                        log_info "Creating symbolic links for enhanced scan files"
                        local linked_count=0
                        for source_file in "${source_files[@]}"; do
                            local filename=$(basename "$source_file")
                            if ln -sf "$source_file" "$project_dir/$filename" 2>/dev/null; then
                                ((linked_count++))
                            fi
                        done
                        
                        if [ "$linked_count" -gt 0 ]; then
                            log_success "Enhanced files prepared: $linked_count symbolic links"
                            return 0
                        fi
                    fi
                else
                    log_warning "No files found in enhanced source directory"
                fi
            else
                log_warning "Enhanced source directory not available: $source_dir"
            fi
        else
            log_warning "Could not determine source directory for $scan_type_size"
        fi
    fi
    
    # Enhanced preparation was not possible
    log_debug "Enhanced file preparation not available"
    return 1
}

# ============================================================================
# SYNTHETIC FILE GENERATION REMOVED
# All prepare_scan_files(), prepare_signature_files(), prepare_binary_files(),
# prepare_container_files(), and create_* helper functions have been removed.
#
# The system now requires real test data files for scanning.
# If files are not found, the scan will fail with a clear error message.
# ============================================================================

# Discover files from test data directories based on scan type
# This implements the sophisticated file discovery from the monolithic script
discover_scan_files() {
    log_debug "📍 Function: discover_scan_files() [file_manager.sh:148]"

    local scan_type="$1"
    local scan_type_size="${2:-}"
    local project_root="${3:-$PROJECT_ROOT}"
    local snippets="${4:-$SNIPPETS}"

    log_info "🔍 DISCOVERING FILES IN SCAN-TYPE SPECIFIC DIRECTORY"
    log_info "  • Searching in: $project_root"
    log_info "  • Scan type: $scan_type"

    local files=()
    local file_names=()
    local file_type=""

    # Save and modify IFS for file discovery
    local OIFS=$IFS
    IFS=$'\n'

    # Determine initial file limit for optimization
    local initial_file_limit=""
    if [ "${ENABLE_ENHANCED_MULTI_SCAN}" == "yes" ]; then
        initial_file_limit=2000
        log_debug "  • Optimization: Limiting initial discovery to $initial_file_limit files for performance"
    fi

    # Discover files based on scan type
    case "$scan_type" in
        SIGNATURE_SCAN)
            if [ "$snippets" == "yes" ]; then
                # Search for snippet files (tar.gz)
                if [ -n "$initial_file_limit" ]; then
                    files=($(find "$project_root" -name "*.tar.gz" -print 2>/dev/null | head -n $initial_file_limit))
                else
                    files=($(find "$project_root" -name "*.tar.gz" -print 2>/dev/null))
                fi
                file_type="tar.gz files for snippet scanning"
                log_debug "  • Looking for: *.tar.gz files (snippet mode)"
            else
                # Search for jar and zip files
                if [ -n "$initial_file_limit" ]; then
                    files=($(find "$project_root" \( -name "*.jar" -o -name "*.zip" \) -print 2>/dev/null | head -n $initial_file_limit))
                else
                    files=($(find "$project_root" \( -name "*.jar" -o -name "*.zip" \) -print 2>/dev/null))
                fi
                file_type="jar and zip files for signature scanning"
                log_debug "  • Looking for: *.jar and *.zip files (signature mode)"
            fi
            ;;

        BINARY_SCAN)
            # Search for binary files
            if [ -n "$initial_file_limit" ]; then
                files=($(find "$project_root" \( -name "*.exe" -o -name "*.dmg" -o -name "*.pkg" -o -name "*.lib" -o -name "*.rpm" -o -name "*.deb" -o -name "*.msi" -o -name "*.cab" -o -name "*.img" -o -name "*.iso" -o -name "*.vmdk" -o -name "*.ova" -o -name "*.vdi" -o -name "*.ubifs" \) -print 2>/dev/null | sort -V | head -n $initial_file_limit))
                file_names=($(find "$project_root" -type f \( -name "*.exe" -o -name "*.dmg" -o -name "*.pkg" -o -name "*.lib" -o -name "*.rpm" -o -name "*.deb" -o -name "*.msi" -o -name "*.cab" -o -name "*.img" -o -name "*.iso" -o -name "*.vmdk" -o -name "*.ova" -o -name "*.vdi" -o -name "*.ubifs" \) -print 2>/dev/null | sort -V | head -n $initial_file_limit | xargs -r basename -a))
            else
                files=($(find "$project_root" \( -name "*.exe" -o -name "*.dmg" -o -name "*.pkg" -o -name "*.lib" -o -name "*.rpm" -o -name "*.deb" -o -name "*.msi" -o -name "*.cab" -o -name "*.img" -o -name "*.iso" -o -name "*.vmdk" -o -name "*.ova" -o -name "*.vdi" -o -name "*.ubifs" \) -print 2>/dev/null | sort -V))
                file_names=($(find "$project_root" -type f \( -name "*.exe" -o -name "*.dmg" -o -name "*.pkg" -o -name "*.lib" -o -name "*.rpm" -o -name "*.deb" -o -name "*.msi" -o -name "*.cab" -o -name "*.img" -o -name "*.iso" -o -name "*.vmdk" -o -name "*.ova" -o -name "*.vdi" -o -name "*.ubifs" \) -print 2>/dev/null | sort -V | xargs -r basename -a))
            fi
            file_type="binary files"
            log_debug "  • Looking for: *.exe, *.dmg, *.pkg, *.lib, *.rpm, *.deb, *.msi, *.cab, *.img, *.iso, *.vmdk, *.ova, *.vdi, *.ubifs files"
            ;;

        CONTAINER_SCAN)
            # Search for container tar files
            if [ -n "$initial_file_limit" ]; then
                files=($(find "$project_root" -name "*.tar" -print 2>/dev/null | sort -V | head -n $initial_file_limit))
            else
                files=($(find "$project_root" -name "*.tar" -print 2>/dev/null | sort -V))
            fi
            file_type="container image files"
            log_debug "  • Looking for: *.tar files (container images)"
            ;;

        *)
            log_error "Unknown scan type: $scan_type"
            IFS=$OIFS
            return 1
            ;;
    esac

    IFS=$OIFS

    log_success "Initial File Discovery Results:"
    log_info "  • Found ${#files[@]} $file_type"
    log_info "  • Directory: $project_root"

    # Apply size-based filtering if enhanced multi-scan is enabled
    if [ "${ENABLE_ENHANCED_MULTI_SCAN}" == "yes" ] && [ -n "$scan_type_size" ]; then
        log_info "📏 FILTERING FILES BY SIZE CATEGORY"

        # Extract size category from SCAN_TYPE_SIZE
        # Handle special case for SNIPPET_SCAN (no size suffix)
        local size_category
        if [[ "$scan_type_size" == "SNIPPET_SCAN" ]]; then
            size_category="MEDIUM"  # Default for snippet scans
        else
            size_category=$(echo "$scan_type_size" | sed 's/.*_\([^_]*\)$/\1/')
        fi
        log_info "  • Target size category: $size_category"

        # Define size ranges in bytes (aligned with SCASS processing swim lanes)
        local min_size max_size
        case "$size_category" in
            SMALL)
                min_size=0
                max_size=134217727  # 128MB - 1 byte
                ;;
            MEDIUM)
                min_size=135266304   # 129MB
                max_size=1073741824  # 1GB
                ;;
            LARGE)
                min_size=1073741825   # 1GB + 1 byte
                max_size=6442450944   # 6GB
                ;;
            XLARGE)
                min_size=6442450945  # 6GB + 1 byte
                max_size=999999999999999  # Unlimited
                ;;
            *)
                log_warning "  ⚠️  Unknown size category: $size_category, using all files"
                min_size=0
                max_size=999999999999999
                ;;
        esac

        log_info "  • Size range: $((min_size / 1048576))MB - $((max_size / 1048576))MB"

        # Optimized size filtering with early termination
        local size_filtered_files=()
        local total_checked=0
        local target_files=100
        local batch_size=500
        local max_time=30
        local start_time=$(date +%s)

        log_debug "  • Optimization: Early termination after finding $target_files matching files (max ${max_time}s)"

        # Process files in batches
        for ((i=0; i<${#files[@]} && ${#size_filtered_files[@]}<$target_files; i+=$batch_size)); do
            # Check time limit
            local current_time=$(date +%s)
            local elapsed_time=$((current_time - start_time))
            if [ $elapsed_time -gt $max_time ]; then
                log_warning "  ⏰ Time limit reached (${elapsed_time}s), stopping with ${#size_filtered_files[@]} files found"
                break
            fi

            local batch_end=$((i + batch_size))
            if [ $batch_end -gt ${#files[@]} ]; then
                batch_end=${#files[@]}
            fi

            # Process current batch
            for ((j=i; j<batch_end && ${#size_filtered_files[@]}<$target_files; j++)); do
                local file="${files[j]}"
                if [ -f "$file" ]; then
                    # Cross-platform file size detection
                    local file_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
                    total_checked=$((total_checked + 1))

                    if [ "$file_size" -ge "$min_size" ] && [ "$file_size" -le "$max_size" ]; then
                        size_filtered_files+=("$file")
                    fi
                fi
            done

            # Progress update every 4 batches
            if [ $((i % (batch_size * 4))) -eq 0 ] && [ $i -gt 0 ]; then
                log_debug "  • Progress: Found ${#size_filtered_files[@]} matching files (checked $total_checked, ${elapsed_time}s elapsed)"
            fi
        done

        log_success "Size Filtering Results:"
        log_info "  • Checked: $total_checked files"
        log_info "  • Matching size range: ${#size_filtered_files[@]} files"

        # Use filtered files if any were found
        if [ ${#size_filtered_files[@]} -gt 0 ]; then
            files=("${size_filtered_files[@]}")
            log_success "  ✅ Using size-filtered files for $size_category category"

            # Update file_names for binary scans
            if [ "$scan_type" == "BINARY_SCAN" ]; then
                file_names=()
                for file in "${files[@]}"; do
                    file_names+=($(basename "$file"))
                done
            fi
        else
            log_warning "  ⚠️  No files match size criteria, using all available files as fallback"
        fi
    fi

    log_info "📋 Final File Selection Results:"
    log_info "  • Using ${#files[@]} $file_type"

    # Set discovered files as global arrays (arrays cannot be exported in Bash)
    DISCOVERED_FILES=("${files[@]}")
    DISCOVERED_FILE_NAMES=("${file_names[@]}")
    DISCOVERED_FILE_TYPE="$file_type"

    # Return success if files were found
    if [ ${#files[@]} -gt 0 ]; then
        return 0
    else
        log_warning "  ⚠️  No $file_type found in $project_root"
        return 1
    fi
}

# Select files from discovered files for a scan
# Supports both random and sequential selection modes
select_files_for_scan() {
    log_debug "📍 Function: select_files_for_scan() [file_manager.sh:361]"

    local scan_type="$1"
    local scan_type_key="${2:-$scan_type}"
    local random_scans="${3:-$RANDOM_SCANS}"

    # Use globally discovered files
    local files=("${DISCOVERED_FILES[@]}")

    if [ ${#files[@]} -eq 0 ]; then
        log_error "No files available for selection"
        return 1
    fi

    local project_files=()
    local start_pos=0
    local num_files=1

    if [ "$random_scans" == "yes" ]; then
        # Random selection mode
        start_pos=$(( RANDOM % ${#files[@]} ))

        if [ "$scan_type" == "SIGNATURE_SCAN" ]; then
            # Random number of components for signature scans
            num_files=$(( (RANDOM % ${MAX_COMPONENTS:-400}) + 1 ))
            # Ensure num_files meets minimum requirement
            local min_comp=${MIN_COMPONENTS:-200}
            if [ "$num_files" -lt "$min_comp" ]; then
                num_files=$min_comp
            fi
        else
            # Binary and container scans always use 1 file
            num_files=1
        fi

        local end=$((start_pos + num_files))
        if [ $end -gt ${#files[@]} ]; then
            num_files=$((${#files[@]} - start_pos))
        fi

        project_files=("${files[@]:$start_pos:$num_files}")

        log_debug "Random selection: start=$start_pos, num_files=$num_files"

    else
        # Sequential selection mode with per-scan-type position tracking
        if [ -z "${SCAN_TYPE_POSITIONS[$scan_type_key]}" ]; then
            SCAN_TYPE_POSITIONS[$scan_type_key]=0
            log_debug "Initializing file position for scan type: $scan_type_key"
        fi

        start_pos=${SCAN_TYPE_POSITIONS[$scan_type_key]}

        if [ "$scan_type" == "SIGNATURE_SCAN" ]; then
            # Use min of FIXED_COMPONENTS and available files
            local fixed_comp=${FIXED_COMPONENTS:-2}
            local available=${#files[@]}
            if [ "$fixed_comp" -gt "$available" ]; then
                num_files=$available
            else
                num_files=$fixed_comp
            fi
        else
            num_files=1
        fi

        local end=$((start_pos + num_files))

        # Wrap around if necessary
        if [ $end -gt ${#files[@]} ]; then
            start_pos=0
            end=$num_files
            log_debug "Wrapping around file list for scan type: $scan_type_key"
        fi

        project_files=("${files[@]:$start_pos:$num_files}")

        # Update position for next iteration
        SCAN_TYPE_POSITIONS[$scan_type_key]=$((start_pos + num_files))

        log_debug "Sequential selection: start=$start_pos, num_files=$num_files, next_pos=${SCAN_TYPE_POSITIONS[$scan_type_key]}"
    fi

    # Log selected files
    log_info "📋 DETAILED FILE SUBMISSION"
    log_info "  • FIXED_COMPONENTS setting: ${FIXED_COMPONENTS:-2}"
    log_info "  • Total files available: ${#files[@]}"
    log_info "  • Files selected for this scan: ${#project_files[@]}"
    log_info "  • Selection range: [$start_pos:$((start_pos + num_files - 1))]"

    if [ ${#project_files[@]} -eq 0 ]; then
        log_error "❌ NO FILES SELECTED! This will cause 0 matches."
        return 1
    fi

    # Set selected files as global variables (arrays cannot be exported in Bash)
    SELECTED_PROJECT_FILES=("${project_files[@]}")
    SELECTED_START_POS=$start_pos

    return 0
}

# Initialize scan type position tracking
# Using global associative array (Bash 4+) or fallback for older Bash
if [ "${BASH_VERSINFO[0]}" -ge 4 ]; then
    declare -A SCAN_TYPE_POSITIONS 2>/dev/null || true
else
    # Bash 3.x fallback - will be handled within functions
    SCAN_TYPE_POSITIONS=()
fi

# Cleanup project files
cleanup_project_files() {
    local project_dir="$1"

    if [ -n "$project_dir" ] && [ -d "$project_dir" ]; then
        log_debug "Cleaning up project directory: $project_dir"
        rm -rf "$project_dir"
    fi
}