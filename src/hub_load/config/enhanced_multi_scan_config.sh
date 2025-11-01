#!/bin/bash
#
# Enhanced Multi-Type Multi-Repository Load Testing Configuration
# Supports size-based repositories and snippet scanning
#

# Configuration options
USE_GCS=${USE_GCS:-yes}

# Test data directory configuration - supports NFS, Docker, and local environments
# Priority order: 1) Environment variable 2) NFS path 3) Docker path 4) Relative path
if [ -n "$LOCAL_TEST_DATA_DIR" ]; then
    # Use explicitly set environment variable (highest priority)
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Using explicitly set LOCAL_TEST_DATA_DIR: $LOCAL_TEST_DATA_DIR" >&2
elif [ -d "/Users/karth/Library/CloudStorage/OneDrive-BlackDuckSoftware/Documents/Automation/blackducksoftware/hub-load/test-data/SCASS" ]; then
    # NFS path for your specific environment - CUSTOMIZE THIS PATH
    LOCAL_TEST_DATA_DIR="/Users/karth/Library/CloudStorage/OneDrive-BlackDuckSoftware/Documents/Automation/blackducksoftware/hub-load/test-data"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Using NFS path: $LOCAL_TEST_DATA_DIR" >&2
elif [ -d "/opt/blackduck/hub-load/test-data/SCASS" ]; then
    # Docker container path
    LOCAL_TEST_DATA_DIR="/opt/blackduck/hub-load/test-data"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Using Docker path: $LOCAL_TEST_DATA_DIR" >&2
elif [ -n "$CONFIG_DIR" ]; then
    # Modular setup - go up from config dir to project root
    # CONFIG_DIR is like: /path/to/hub-load/src/hub_load/config
    # We want: /path/to/hub-load/test-data
    HUB_LOAD_DIR="$(dirname "$(dirname "$CONFIG_DIR")")"  # /path/to/hub-load/src
    PROJECT_ROOT="$(dirname "$HUB_LOAD_DIR")"  # /path/to/hub-load
    LOCAL_TEST_DATA_DIR="$PROJECT_ROOT/test-data"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Using modular path: $LOCAL_TEST_DATA_DIR" >&2
else
    # Legacy setup - use existing logic
    LOCAL_TEST_DATA_DIR="${PROJECT_ROOT}/test-data"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Using legacy path: $LOCAL_TEST_DATA_DIR" >&2
fi

# Validate test data directory exists
# Check if the path ends with SCASS or contains SCASS subdirectories
if [[ "$LOCAL_TEST_DATA_DIR" == */SCASS ]]; then
    # Path already points to SCASS directory - check if it exists and has subdirectories
    if [ ! -d "$LOCAL_TEST_DATA_DIR" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: SCASS directory not found at: $LOCAL_TEST_DATA_DIR" >&2
    elif [ ! "$(ls -A "$LOCAL_TEST_DATA_DIR" 2>/dev/null)" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: SCASS directory is empty: $LOCAL_TEST_DATA_DIR" >&2
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ SCASS directory found with subdirectories: $LOCAL_TEST_DATA_DIR" >&2
    fi
else
    # Traditional path structure - check for SCASS subdirectory
    if [ ! -d "$LOCAL_TEST_DATA_DIR/SCASS" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: SCASS directory not found at: $LOCAL_TEST_DATA_DIR/SCASS" >&2
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Available directories in $LOCAL_TEST_DATA_DIR:" >&2
        ls -la "$LOCAL_TEST_DATA_DIR" 2>/dev/null || echo "$(date '+%Y-%m-%d %H:%M:%S') - Directory $LOCAL_TEST_DATA_DIR does not exist" >&2
    fi
fi

# Cross-platform compatibility detection
PLATFORM=$(uname -s)
echo "$(date '+%Y-%m-%d %H:%M:%S') - Detected platform: $PLATFORM" >&2

# Cross-platform compatibility function
check_platform_compatibility() {
    case "$PLATFORM" in
        "Darwin")
            echo "$(date '+%Y-%m-%d %H:%M:%S') - macOS compatibility mode enabled" >&2
            ;;
        "Linux")
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Linux/Ubuntu compatibility mode enabled" >&2
            ;;
        *)
            echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: Untested platform: $PLATFORM" >&2
            ;;
    esac
    
    # Check for required commands
    local missing_commands=()
    for cmd in find stat basename dirname; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Missing required commands: ${missing_commands[*]}" >&2
        return 1
    fi
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Platform compatibility check passed" >&2
    return 0
}

# Run compatibility check
check_platform_compatibility

# Enhanced configuration for realistic workload simulation with size variations
# Format: SCAN_TYPE_SIZE:percentage (total should equal 100)
# Example configurations:

# Balanced distribution across all 4 scan types:
# MULTI_SCAN_CONFIG="BINARY_SCAN_SMALL:12,BINARY_SCAN_MEDIUM:8,BINARY_SCAN_LARGE:5,SIGNATURE_SCAN_SMALL:12,SIGNATURE_SCAN_MEDIUM:8,SIGNATURE_SCAN_LARGE:5,CONTAINER_SCAN_SMALL:12,CONTAINER_SCAN_MEDIUM:8,CONTAINER_SCAN_LARGE:5"
# SNIPPET_SCAN_CONFIG="SNIPPET_SCAN_SMALL:10,SNIPPET_SCAN_MEDIUM:10,SNIPPET_SCAN_LARGE:5"

# Current default configuration (must total 100%) - includes all size categories and snippets:
# Increased binary scan weights to ensure better distribution in first 10 scans
# Distribution: Binary=35%, Signature=43%, Container=17%, Snippet=5%
MULTI_SCAN_CONFIG=${MULTI_SCAN_CONFIG:-"BINARY_SCAN_SMALL:12,BINARY_SCAN_MEDIUM:10,BINARY_SCAN_LARGE:8,BINARY_SCAN_XLARGE:5,SIGNATURE_SCAN_SMALL:20,SIGNATURE_SCAN_MEDIUM:12,SIGNATURE_SCAN_LARGE:8,SIGNATURE_SCAN_XLARGE:3,SNIPPET_SCAN:5,CONTAINER_SCAN_SMALL:8,CONTAINER_SCAN_MEDIUM:5,CONTAINER_SCAN_LARGE:3,CONTAINER_SCAN_XLARGE:1"}

# Simplified configuration for small scan counts (< 50 scans) - includes SMALL and snippets for coverage:
SMALL_SCAN_CONFIG=${SMALL_SCAN_CONFIG:-"BINARY_SCAN_SMALL:20,BINARY_SCAN_MEDIUM:25,SIGNATURE_SCAN_SMALL:15,SIGNATURE_SCAN_MEDIUM:15,SNIPPET_SCAN:10,CONTAINER_SCAN_SMALL:10,CONTAINER_SCAN_LARGE:5"}

# Scan count threshold for switching between configurations
SCAN_COUNT_THRESHOLD=${SCAN_COUNT_THRESHOLD:-50}

# TAR.GZ file control configuration
ENABLE_TARGZ_FILES=${ENABLE_TARGZ_FILES:-yes}
TARGZ_SOURCE_DIR=${TARGZ_SOURCE_DIR:-"SCA_SNIPPETS"}  # Directory containing pre-made tar.gz files
TARGZ_FILE_COUNT=${TARGZ_FILE_COUNT:-3}  # Number of tar.gz files to copy

# Size-based repository mapping (compatible with older bash)
get_repository_for_scan_type() {
    local scan_type_size="$1"
    
    case "$scan_type_size" in
        "BINARY_SCAN_SMALL")    echo "performance_test_bdios/SCASS/SCA_BINARY_SMALL" ;;
        "BINARY_SCAN_MEDIUM")   echo "performance_test_bdios/SCASS/SCA_BINARY_MEDIUM" ;;
        "BINARY_SCAN_LARGE")    echo "performance_test_bdios/SCASS/SCA_BINARY_LARGE" ;;
        "BINARY_SCAN_XLARGE")   echo "performance_test_bdios/SCASS/SCA_BINARY_XLARGE" ;;
        "SIGNATURE_SCAN_SMALL") echo "performance_test_bdios/SCASS/SCA_SIGNATURE_SMALL" ;;
        "SIGNATURE_SCAN_MEDIUM") echo "performance_test_bdios/SCASS/SCA_SIGNATURE_MEDIUM" ;;
        "SIGNATURE_SCAN_LARGE") echo "performance_test_bdios/SCASS/SCA_SIGNATURE_LARGE" ;;
        "SIGNATURE_SCAN_XLARGE") echo "performance_test_bdios/SCASS/SCA_SIGNATURE_XLARGE" ;;
        "CONTAINER_SCAN_SMALL") echo "performance_test_bdios/SCASS/SCA_CONTAINER_SMALL" ;;
        "CONTAINER_SCAN_MEDIUM") echo "performance_test_bdios/SCASS/SCA_CONTAINER_MEDIUM" ;;
        "CONTAINER_SCAN_LARGE") echo "performance_test_bdios/SCASS/SCA_CONTAINER_LARGE" ;;
        "CONTAINER_SCAN_XLARGE") echo "performance_test_bdios/SCASS/SCA_CONTAINER_XLARGE" ;;
        "SNIPPET_SCAN") echo "performance_test_bdios/SCASS/SCA_SNIPPETS" ;;
        *)                      echo "performance_test_bdios/SCASS/SCA_NON_BDIOS_BINARY_SM_MEDIUM" ;;
    esac
}

# Get local directory path for scan type (when USE_GCS=no)
get_local_directory_for_scan_type() {
    local scan_type_size="$1"
    
    # Handle case where LOCAL_TEST_DATA_DIR already ends with SCASS
    if [[ "$LOCAL_TEST_DATA_DIR" == */SCASS ]]; then
        local base_dir="$LOCAL_TEST_DATA_DIR"
    else
        local base_dir="${LOCAL_TEST_DATA_DIR}/SCASS"
    fi
    
    case "$scan_type_size" in
        "BINARY_SCAN_SMALL")    echo "${base_dir}/SCA_NON_BDIOS_BINARY_SM_MEDIUM" ;;
        "BINARY_SCAN_MEDIUM")   echo "${base_dir}/SCA_NON_BDIOS_BINARY_SM_MEDIUM" ;;
        "BINARY_SCAN_LARGE")    echo "${base_dir}/SCA_NON_BDIOS_BINARY_LARGE" ;;
        "BINARY_SCAN_XLARGE")   echo "${base_dir}/SCA_NON_BDIOS_BINARY_XLARGE" ;;
        "SIGNATURE_SCAN_SMALL") echo "${base_dir}/SCA_NON_BDIOS_SM_MEDIUM" ;;
        "SIGNATURE_SCAN_MEDIUM") echo "${base_dir}/SCA_NON_BDIOS_SM_MEDIUM" ;;
        "SIGNATURE_SCAN_LARGE") echo "${base_dir}/SCA_NON_BDIOS_LARGE" ;;
        "SIGNATURE_SCAN_XLARGE") echo "${base_dir}/SCA_NON_BDIOS_LARGE" ;;
        "CONTAINER_SCAN_SMALL") echo "${base_dir}/SCA_NON_BDIOS_CONTAINER_SM_MEDIUM" ;;
        "CONTAINER_SCAN_MEDIUM") echo "${base_dir}/SCA_NON_BDIOS_CONTAINER_SM_MEDIUM" ;;
        "CONTAINER_SCAN_LARGE") echo "${base_dir}/SCA_NON_BDIOS_CONTAINER_LARGE" ;;
        "CONTAINER_SCAN_XLARGE") echo "${base_dir}/SCA_NON_BDIOS_CONTAINER_XLARGE" ;;
        "SNIPPET_SCAN") echo "${base_dir}/SCA_SNIPPETS" ;;
        *)                      echo "${base_dir}/SCA_NON_BDIOS_SM_MEDIUM" ;;
    esac
}

# Get tar.gz source directory for copying files
get_targz_source_directory() {
    # Handle case where LOCAL_TEST_DATA_DIR already ends with SCASS
    if [[ "$LOCAL_TEST_DATA_DIR" == */SCASS ]]; then
        local base_dir="$LOCAL_TEST_DATA_DIR"
    else
        local base_dir="${LOCAL_TEST_DATA_DIR}/SCASS"
    fi
    echo "${base_dir}/${TARGZ_SOURCE_DIR}"
}

# Copy .tar.gz files from SCA_SNIPPETS directory to target directory
copy_targz_files() {
    local target_dir="$1"
    local file_count="${TARGZ_FILE_COUNT:-3}"
    
    if [ "${ENABLE_TARGZ_FILES}" != "yes" ]; then
        return 0
    fi
    
    local source_dir=$(get_targz_source_directory)
    
    if [ ! -d "$source_dir" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Warning: TAR.GZ source directory not found: $source_dir"
        return 1
    fi
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') -   📥 Copying $file_count tar/tar.gz files from $source_dir to $target_dir"
    
    # Find available tar.gz and tar files
    local available_files=($(find "$source_dir" -name "*.tar.gz" -o -name "*.tar" | head -$file_count))
    echo "$(date '+%Y-%m-%d %H:%M:%S') -   🔍 Found ${#available_files[@]} available TAR files"
    
    if [ ${#available_files[@]} -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   ⚠️  No .tar or .tar.gz files found in $source_dir"
        return 1
    fi
    
    # Copy the files
    local copied=0
    for file in "${available_files[@]}"; do
        if [ $copied -lt $file_count ]; then
            local filename=$(basename "$file")
            # Cross-platform file size detection
            if command -v stat >/dev/null 2>&1; then
                local filesize_bytes=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
                local filesize=$(numfmt --to=iec --suffix=B $filesize_bytes 2>/dev/null || du -h "$file" | cut -f1)
            else
                local filesize=$(du -h "$file" | cut -f1)
            fi
            cp "$file" "$target_dir/$filename"
            echo "$(date '+%Y-%m-%d %H:%M:%S') -   ✅ Copied $filename ($filesize) to $target_dir"
            ((copied++))
        fi
    done
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Copied $copied .tar.gz files"
}

# Get cumulative weight for selection
get_cumulative_weight() {
    local config_string="$1"
    local total=0
    IFS=',' read -ra PAIRS <<< "$config_string"
    for pair in "${PAIRS[@]}"; do
        IFS=':' read -ra SPLIT <<< "$pair"
        if [[ ${#SPLIT[@]} -eq 2 ]]; then
            total=$((total + ${SPLIT[1]}))
        fi
    done
    echo $total
}

# Combine all scan configurations into one unified config
get_unified_scan_config() {
    local total_scans="${MAX_SCANS:-100}"
    local final_config=""
    
    # Automatically select configuration based on scan count
    if [ "$total_scans" -lt "$SCAN_COUNT_THRESHOLD" ]; then
        # Use simplified configuration for small scan counts
        final_config="$SMALL_SCAN_CONFIG"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Using SMALL_SCAN_CONFIG for $total_scans scans (< $SCAN_COUNT_THRESHOLD)" >&2
    else
        # Use full configuration for larger scan counts
        final_config="$MULTI_SCAN_CONFIG"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Using MULTI_SCAN_CONFIG for $total_scans scans (>= $SCAN_COUNT_THRESHOLD)" >&2
    fi
    
    echo "$final_config"
}

# Function to check if a scan type has available files
check_scan_type_has_files() {
    local scan_type_size="$1"
    local use_gcs="$2"
    
    if [ "$use_gcs" == "yes" ]; then
        # For GCS, assume files are available (would need GCS integration to check)
        return 0
    fi
    
    # For local files, check if directory exists and has files
    local local_dir=$(get_local_directory_for_scan_type "$scan_type_size")
    
    if [ ! -d "$local_dir" ]; then
        return 1
    fi
    
    # Parse scan type to determine file patterns
    local scan_info=($(parse_scan_type_and_size "$scan_type_size"))
    local scan_type="${scan_info[0]}"
    
    local file_count=0
    case "$scan_type" in
        "SIGNATURE_SCAN")
            if [[ "$scan_type_size" == "SNIPPET_SCAN"* ]]; then
                file_count=$(find "$local_dir" -name "*.tar.gz" -type f 2>/dev/null | wc -l)
            else
                file_count=$(find "$local_dir" \( -name "*.jar" -o -name "*.zip" \) -type f 2>/dev/null | wc -l)
            fi
            ;;
        "SNIPPET_SCAN")
            # Snippet scans use tar.gz files
            file_count=$(find "$local_dir" -name "*.tar.gz" -type f 2>/dev/null | wc -l)
            ;;
        "BINARY_SCAN")
            file_count=$(find "$local_dir" \( -name "*.exe" -o -name "*.dmg" -o -name "*.pkg" -o -name "*.lib" -o -name "*.rpm" -o -name "*.deb" -o -name "*.msi" -o -name "*.cab" -o -name "*.img" -o -name "*.iso" -o -name "*.vmdk" -o -name "*.ova" -o -name "*.vdi" -o -name "*.ubifs" \) -type f 2>/dev/null | wc -l)
            ;;
        "CONTAINER_SCAN")
            file_count=$(find "$local_dir" -name "*.tar" -type f 2>/dev/null | wc -l)
            ;;
        *)
            file_count=0
            ;;
    esac
    
    [ "$file_count" -gt 0 ]
}

# Function to get available scan types with files
get_available_scan_types() {
    local use_gcs="$1"
    local unified_config=$(get_unified_scan_config)
    local available_types=()
    
    IFS=',' read -ra PAIRS <<< "$unified_config"
    for pair in "${PAIRS[@]}"; do
        IFS=':' read -ra SPLIT <<< "$pair"
        if [[ ${#SPLIT[@]} -eq 2 ]]; then
            local scan_type_size="${SPLIT[0]}"
            if check_scan_type_has_files "$scan_type_size" "$use_gcs"; then
                available_types+=("$scan_type_size")
            fi
        fi
    done
    
    echo "${available_types[@]}"
}

# Global scan selection counter for deterministic ordering
# This ensures the same scan types are selected in the same order across test runs
SCAN_SELECTION_COUNTER=${SCAN_SELECTION_COUNTER:-0}

# Function to select scan type with size based on weighted distribution
# Uses deterministic round-robin selection to ensure repeatability
select_scan_type_with_size() {
    local use_gcs="${USE_GCS:-no}"

    # Verbose logging only in DEBUG mode
    if [ "${DEBUG}" == "yes" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 🔍 DEBUG: SCAN TYPE SELECTION PROCESS" >&2
    fi

    local unified_config=$(get_unified_scan_config)
    if [ "${DEBUG}" == "yes" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 🔍 DEBUG: Unified config: $unified_config" >&2
    fi

    # Check available scan types with files
    local available_types=($(get_available_scan_types "$use_gcs"))
    if [ "${DEBUG}" == "yes" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 🔍 DEBUG: Available scan types with files: ${#available_types[@]}" >&2
    fi

    if [ ${#available_types[@]} -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   ⚠️  No scan types have available files!" >&2
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Returning special marker for no files available" >&2
        echo "NO_FILES_AVAILABLE"
        return 1
    fi

    # Create a weighted config from only available scan types
    local available_config=""
    local total_available_weight=0

    IFS=',' read -ra PAIRS <<< "$unified_config"
    for pair in "${PAIRS[@]}"; do
        IFS=':' read -ra SPLIT <<< "$pair"
        if [[ ${#SPLIT[@]} -eq 2 ]]; then
            local scan_type_size="${SPLIT[0]}"
            local weight="${SPLIT[1]}"

            # Check if this scan type is in our available list
            for available_type in "${available_types[@]}"; do
                if [ "$scan_type_size" == "$available_type" ]; then
                    if [ -n "$available_config" ]; then
                        available_config="${available_config},"
                    fi
                    available_config="${available_config}${scan_type_size}:${weight}"
                    total_available_weight=$((total_available_weight + weight))
                    break
                fi
            done
        fi
    done

    if [ "${DEBUG}" == "yes" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 🔍 DEBUG: Available config: $available_config" >&2
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 🔍 DEBUG: Total available weight: $total_available_weight" >&2
    fi

    if [[ $total_available_weight -eq 0 ]]; then
        if [ "${DEBUG}" == "yes" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 🔍 DEBUG: No weights for available types, using first available" >&2
        fi
        echo "${available_types[0]}"
        return 0
    fi

    # Use deterministic counter-based selection instead of RANDOM for repeatability
    # This ensures the same scan type is selected for the same scan iteration across test runs
    local selection_num=$((SCAN_SELECTION_COUNTER % total_available_weight))
    SCAN_SELECTION_COUNTER=$((SCAN_SELECTION_COUNTER + 1))

    if [ "${DEBUG}" == "yes" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 🔍 DEBUG: Deterministic selection number: $selection_num (counter: $((SCAN_SELECTION_COUNTER - 1)), range: 0-$((total_available_weight-1)))" >&2
    fi
    local cumulative=0
    
    IFS=',' read -ra PAIRS <<< "$available_config"
    for pair in "${PAIRS[@]}"; do
        IFS=':' read -ra SPLIT <<< "$pair"
        if [[ ${#SPLIT[@]} -eq 2 ]]; then
            local scan_type_size="${SPLIT[0]}"
            local weight="${SPLIT[1]}"
            cumulative=$((cumulative + weight))
            if [ "${DEBUG}" == "yes" ]; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 🔍 DEBUG: Checking $scan_type_size (weight: $weight, cumulative: $cumulative)" >&2
            fi
            if [[ $selection_num -lt $cumulative ]]; then
                # Always log the selected scan type (not debug-only)
                if [ "${DEBUG}" != "yes" ]; then
                    echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Selected: $scan_type_size" >&2
                else
                    echo "$(date '+%Y-%m-%d %H:%M:%S') - 🔍 DEBUG: ✅ Selected: $scan_type_size" >&2
                fi
                echo "$scan_type_size"
                return 0
            fi
        fi
    done

    # Fallback to first available
    if [ "${DEBUG}" == "yes" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 🔍 DEBUG: ⚠️  No match found, using first available: ${available_types[0]}" >&2
    fi
    echo "${available_types[0]}"
}

# Function to parse scan type and size from combined string
parse_scan_type_and_size() {
    local scan_type_size="$1"
    
    if [[ "$scan_type_size" =~ ^(BINARY_SCAN|SIGNATURE_SCAN|CONTAINER_SCAN)_(SMALL|MEDIUM|LARGE|XLARGE)$ ]]; then
        local scan_type="${BASH_REMATCH[1]}"
        local size="${BASH_REMATCH[2]}"
        echo "$scan_type" "$size"
    elif [[ "$scan_type_size" == "SNIPPET_SCAN" ]]; then
        echo "SNIPPET_SCAN" "MEDIUM"
    else
        echo "SIGNATURE_SCAN" "MEDIUM"
    fi
}

# Function to get GCS repository based on scan type and size
get_gcs_repository_for_scan() {
    local scan_type_size="$1"
    get_repository_for_scan_type "$scan_type_size"
}

# Function to get file patterns based on scan type and size
get_file_patterns_by_type_and_size() {
    local scan_type="$1"
    local size="$2"
    
    case "$scan_type" in
        "BINARY_SCAN")
            case "$size" in
                "SMALL")
                    echo "*.exe *.msi"
                    ;;
                "MEDIUM")
                    echo "*.tar.gz *.tgz *.rpm"
                    ;;
                "LARGE"|"XLARGE")
                    echo "*.dmg *.iso *.ISO"
                    ;;
                *)
                    echo "*.exe *.tar.gz *.tgz *.dmg *.iso *.msi *.rpm"
                    ;;
            esac
            ;;
        "SIGNATURE_SCAN")
            case "$size" in
                "SMALL")
                    echo "*.jar"
                    ;;
                "MEDIUM")
                    echo "*.jar *.war"
                    ;;
                "LARGE"|"XLARGE")
                    echo "*.jar *.war *.ear *.zip"
                    ;;
                *)
                    echo "*.jar *.war *.ear *.zip"
                    ;;
            esac
            ;;
        "CONTAINER_SCAN")
            echo "*.tar"
            ;;
        *)
            echo "*.jar *.war *.ear *.zip"
            ;;
    esac
}

# Function to get component count based on size
get_component_count_by_size() {
    local size="$1"
    local base_count="$2"
    
    case "$size" in
        "SMALL")
            echo $((base_count / 4))
            ;;
        "MEDIUM")
            echo $base_count
            ;;
        "LARGE")
            echo $((base_count * 2))
            ;;
        "XLARGE")
            echo $((base_count * 4))
            ;;
        *)
            echo $base_count
            ;;
    esac
}

# Function to get file count for a scan type
get_file_count_for_scan_type() {
    local scan_type_size="$1"
    local use_gcs="${USE_GCS:-no}"

    if [ "$use_gcs" == "yes" ]; then
        # For GCS, we can't easily count without mounting
        echo "N/A"
        return 0
    fi

    # For local files, check if directory exists and has files
    local local_dir=$(get_local_directory_for_scan_type "$scan_type_size")

    if [ ! -d "$local_dir" ]; then
        echo "0"
        return 1
    fi

    # Parse scan type to determine file patterns
    local scan_info=($(parse_scan_type_and_size "$scan_type_size"))
    local scan_type="${scan_info[0]}"

    local file_count=0
    case "$scan_type" in
        "SIGNATURE_SCAN")
            if [[ "$scan_type_size" == "SNIPPET_SCAN"* ]]; then
                file_count=$(find "$local_dir" -name "*.tar.gz" -type f 2>/dev/null | wc -l | tr -d ' ')
            else
                file_count=$(find "$local_dir" \( -name "*.jar" -o -name "*.zip" \) -type f 2>/dev/null | wc -l | tr -d ' ')
            fi
            ;;
        "SNIPPET_SCAN")
            # Snippet scans use tar.gz files
            file_count=$(find "$local_dir" -name "*.tar.gz" -type f 2>/dev/null | wc -l | tr -d ' ')
            ;;
        "BINARY_SCAN")
            file_count=$(find "$local_dir" \( -name "*.exe" -o -name "*.dmg" -o -name "*.pkg" -o -name "*.lib" -o -name "*.rpm" -o -name "*.deb" -o -name "*.msi" -o -name "*.cab" -o -name "*.img" -o -name "*.iso" -o -name "*.vmdk" -o -name "*.ova" -o -name "*.vdi" -o -name "*.ubifs" \) -type f 2>/dev/null | wc -l | tr -d ' ')
            ;;
        "CONTAINER_SCAN")
            file_count=$(find "$local_dir" -name "*.tar" -type f 2>/dev/null | wc -l | tr -d ' ')
            ;;
        *)
            file_count=0
            ;;
    esac

    echo "$file_count"
}

# Function to get expected scan distribution for a given total scan count
get_expected_distribution() {
    local total_scans="${1:-100}"
    local config_to_use=""

    if [ "$total_scans" -lt "$SCAN_COUNT_THRESHOLD" ]; then
        config_to_use="$SMALL_SCAN_CONFIG"
        echo "Expected distribution for $total_scans scans (using SMALL_SCAN_CONFIG):"
    else
        config_to_use="$MULTI_SCAN_CONFIG"
        echo "Expected distribution for $total_scans scans (using MULTI_SCAN_CONFIG):"
    fi

    IFS=',' read -ra PAIRS <<< "$config_to_use"
    for pair in "${PAIRS[@]}"; do
        IFS=':' read -ra SPLIT <<< "$pair"
        if [[ ${#SPLIT[@]} -eq 2 ]]; then
            local scan_type_size="${SPLIT[0]}"
            local percentage="${SPLIT[1]}"
            local expected_count=$((total_scans * percentage / 100))
            local remainder=$((total_scans * percentage % 100))
            if [ $remainder -ge 50 ]; then
                expected_count=$((expected_count + 1))
            fi

            # Get file count for this scan type
            local file_count=$(get_file_count_for_scan_type "$scan_type_size")

            # Format output with file count
            if [ "$file_count" = "N/A" ]; then
                printf "  %-25s: %3d%% = ~%2d scans [GCS]\n" "$scan_type_size" "$percentage" "$expected_count"
            elif [ "$file_count" -eq 0 ]; then
                printf "  %-25s: %3d%% = ~%2d scans [❌ NO FILES]\n" "$scan_type_size" "$percentage" "$expected_count"
            else
                printf "  %-25s: %3d%% = ~%2d scans [✅ %s files]\n" "$scan_type_size" "$percentage" "$expected_count" "$file_count"
            fi
        fi
    done
    echo ""
}

# Function to validate enhanced configuration percentages
validate_enhanced_config() {
    local unified_config=$(get_unified_scan_config)
    local total=$(get_cumulative_weight "$unified_config")
    
    if [[ $total -ne 100 ]]; then
        echo "WARNING: Enhanced scan type percentages total $total%, not 100%" >&2
        return 1
    fi
    return 0
}

# Function to display enhanced configuration summary
show_enhanced_config() {
    local total_scans="${MAX_SCANS:-100}"
    
    echo "=== Enhanced Multi-Type Multi-Repository Configuration ==="
    echo "Scan Count Threshold: $SCAN_COUNT_THRESHOLD"
    echo "Total Scans: $total_scans"
    echo ""
    echo "Available Configurations:"
    echo "  Large Scale (>= $SCAN_COUNT_THRESHOLD scans): $MULTI_SCAN_CONFIG"
    echo "  Small Scale (< $SCAN_COUNT_THRESHOLD scans): $SMALL_SCAN_CONFIG"
    echo ""
    
    local unified_config=$(get_unified_scan_config)
    if [ "$total_scans" -lt "$SCAN_COUNT_THRESHOLD" ]; then
        echo "🎯 ACTIVE CONFIGURATION: Small Scale (< $SCAN_COUNT_THRESHOLD scans)"
        echo "Rationale: Simplified distribution ensures all scan types are represented"
    else
        echo "🎯 ACTIVE CONFIGURATION: Large Scale (>= $SCAN_COUNT_THRESHOLD scans)"
        echo "Rationale: Full distribution with statistical reliability"
    fi
    echo ""
    
    echo "Active Scan Type Weights:"
    IFS=',' read -ra PAIRS <<< "$unified_config"
    for pair in "${PAIRS[@]}"; do
        IFS=':' read -ra SPLIT <<< "$pair"
        if [[ ${#SPLIT[@]} -eq 2 ]]; then
            local scan_type_size="${SPLIT[0]}"
            local percentage="${SPLIT[1]}"
            local expected_count=$((total_scans * percentage / 100))
            local gcs_repo=$(get_repository_for_scan_type "$scan_type_size")
            echo "  $scan_type_size: ${percentage}% (~$expected_count scans) → gs://$gcs_repo"
        fi
    done
    
    echo ""
    validate_enhanced_config
}

# Test enhanced distribution function
test_enhanced_distribution() {
    local iterations="${1:-100}"
    
    echo "Testing enhanced scan type distribution"
    echo "Iterations: $iterations"
    echo ""
    
    # Count occurrences
    for i in $(seq 1 $iterations); do
        select_scan_type_with_size
    done | sort | uniq -c | sort -nr
    echo ""
}

# Function to setup size-based scanning parameters
setup_size_based_scan() {
    local scan_type_size="$1"
    local scan_info=($(parse_scan_type_and_size "$scan_type_size"))
    local scan_type="${scan_info[0]}"
    local size="${scan_info[1]}"
    local gcs_repo=$(get_gcs_repository_for_scan "$scan_type_size")
    
    echo "SCAN_TYPE=$scan_type"
    echo "SCAN_SIZE=$size"
    echo "GCS_REPOSITORY=$gcs_repo"
    echo "FILE_PATTERNS=$(get_file_patterns_by_type_and_size "$scan_type" "$size")"
    
    # Special handling for snippet scans
    if [[ "$scan_type" == "SNIPPET_SCAN" ]]; then
        echo "SNIPPETS=yes"
        echo "ACTUAL_SCAN_TYPE=SIGNATURE_SCAN"
    else
        echo "SNIPPETS=no"
        echo "ACTUAL_SCAN_TYPE=$scan_type"
    fi
}

# Main test if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "=== Testing Enhanced Multi-Scan Configuration ==="
    
    # Test with different scan counts
    echo "=== Configuration Examples ==="
    echo ""
    
    echo "📊 Small Scale Example (10 scans/hour):"
    MAX_SCANS=10 get_expected_distribution 10
    
    echo "📊 Medium Scale Example (25 scans/hour):"
    MAX_SCANS=25 get_expected_distribution 25
    
    echo "📊 Large Scale Example (100 scans/hour):"
    MAX_SCANS=100 get_expected_distribution 100
    
    echo "📊 Very Large Scale Example (500 scans/hour):"
    MAX_SCANS=500 get_expected_distribution 500
    
    echo "=== Active Configuration Test ==="
    MAX_SCANS=50 show_enhanced_config
    echo ""
    
    echo "=== Distribution Testing ==="
    echo "Testing small scale distribution (10 iterations):"
    MAX_SCANS=10 test_enhanced_distribution 10
    
    echo "Testing large scale distribution (50 iterations):"
    MAX_SCANS=100 test_enhanced_distribution 50
    
    echo "=== Testing Size-Based Repository Selection ==="
    for scan_type_size in "BINARY_SCAN_SMALL" "SIGNATURE_SCAN_LARGE" "CONTAINER_SCAN_MEDIUM" "SNIPPET_SCAN_SMALL"; do
        echo "Testing $scan_type_size:"
        setup_size_based_scan "$scan_type_size"
        echo ""
    done
fi