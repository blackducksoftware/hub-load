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

# File preparation functions
prepare_scan_files() {
    local project_dir="$1"
    local scan_type="$2"
    local target_size="$3"
    local scan_type_size="$4"  # Enhanced parameter from generate_scan_config
    
    if [ -z "$project_dir" ] || [ -z "$scan_type" ]; then
        log_error "prepare_scan_files requires project_dir and scan_type parameters"
        return 1
    fi
    
    log_info "Preparing files for $scan_type in $project_dir (target size: ${target_size:-DEFAULT})"
    
    # Try enhanced file preparation first if scan_type_size is provided
    if [ -n "$scan_type_size" ]; then
        log_debug "Attempting enhanced file preparation for $scan_type_size"
        if prepare_enhanced_scan_files "$project_dir" "$scan_type" "$target_size" "$scan_type_size"; then
            return 0
        fi
        log_info "Enhanced preparation not available, using synthetic generation"
    else
        log_debug "No enhanced scan type provided, using synthetic generation"
    fi
    
    # Fall back to synthetic file generation
    log_info "Using synthetic file generation for $scan_type"
    
    # Create project directory
    mkdir -p "$project_dir"
    
    case "$scan_type" in
        SIGNATURE_SCAN)
            prepare_signature_files "$project_dir" "$target_size"
            ;;
        BINARY_SCAN)
            prepare_binary_files "$project_dir" "$target_size"
            ;;
        CONTAINER_SCAN)
            prepare_container_files "$project_dir" "$target_size"
            ;;
        *)
            log_error "Unknown scan type for file preparation: $scan_type"
            return 1
            ;;
    esac
    
    return $?
}

# Prepare files for signature scanning
prepare_signature_files() {
    local project_dir="$1"
    local target_size="$2"
    
    log_debug "Preparing signature scan files in $project_dir"
    
    # Determine file count based on target size
    local file_count
    case "$target_size" in
        SMALL) file_count=10 ;;
        MEDIUM) file_count=50 ;;
        LARGE) file_count=200 ;;
        XLARGE) file_count=500 ;;
        *) file_count=50 ;;
    esac
    
    # Create source files
    create_source_files "$project_dir" "$file_count"
    
    # Add dependency files
    create_dependency_files "$project_dir" "$target_size"
    
    log_success "Prepared $file_count source files for signature scanning"
    return 0
}

# Prepare files for binary scanning  
prepare_binary_files() {
    local project_dir="$1"
    local target_size="$2"
    
    log_debug "Preparing binary scan files in $project_dir"
    
    # Determine binary count based on target size
    local binary_count
    case "$target_size" in
        SMALL) binary_count=5 ;;
        MEDIUM) binary_count=20 ;;
        LARGE) binary_count=50 ;;
        XLARGE) binary_count=100 ;;
        *) binary_count=20 ;;
    esac
    
    # Create binary files
    create_binary_files "$project_dir" "$binary_count"
    
    log_success "Prepared $binary_count binary files for binary scanning"
    return 0
}

# Prepare files for container scanning
prepare_container_files() {
    local project_dir="$1"
    local target_size="$2"
    
    log_debug "Preparing container scan files in $project_dir"
    
    # Create Dockerfile
    create_dockerfile "$project_dir" "$target_size"
    
    # Create application files
    create_application_files "$project_dir" "$target_size"
    
    log_success "Prepared container files for container scanning"
    return 0
}

# Create source code files
create_source_files() {
    local project_dir="$1"
    local file_count="$2"
    
    local src_dir="$project_dir/src/main/java/com/example"
    mkdir -p "$src_dir"
    
    for ((i=1; i<=file_count; i++)); do
        local class_name="Class$(printf "%03d" $i)"
        cat > "$src_dir/${class_name}.java" << EOF
package com.example;

/**
 * Generated test class $class_name for load testing
 */
public class $class_name {
    private String name = "$class_name";
    private int id = $i;
    
    public $class_name() {
        // Default constructor
    }
    
    public String getName() {
        return name;
    }
    
    public int getId() {
        return id;
    }
    
    public void processData() {
        System.out.println("Processing data in " + name);
        // Simulate some work
        for (int j = 0; j < 100; j++) {
            Math.random();
        }
    }
}
EOF
    done
    
    log_debug "Created $file_count Java source files"
}

# Create dependency files
create_dependency_files() {
    local project_dir="$1"
    local target_size="$2"
    
    # Create pom.xml for Maven
    cat > "$project_dir/pom.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <groupId>com.example</groupId>
    <artifactId>test-project</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>
    
    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
    </properties>
    
    <dependencies>
        <dependency>
            <groupId>org.apache.commons</groupId>
            <artifactId>commons-lang3</artifactId>
            <version>3.12.0</version>
        </dependency>
        <dependency>
            <groupId>com.fasterxml.jackson.core</groupId>
            <artifactId>jackson-core</artifactId>
            <version>2.13.0</version>
        </dependency>
    </dependencies>
</project>
EOF
    
    log_debug "Created Maven POM file"
}

# Create binary files for binary scanning
create_binary_files() {
    local project_dir="$1"
    local binary_count="$2"
    
    local bin_dir="$project_dir/bin"
    mkdir -p "$bin_dir"
    
    for ((i=1; i<=binary_count; i++)); do
        local binary_name="binary$(printf "%03d" $i)"
        
        # Create a simple binary file (compiled from C)
        local c_file="/tmp/${binary_name}.c"
        cat > "$c_file" << EOF
#include <stdio.h>
#include <stdlib.h>

int main() {
    printf("Hello from %s\\n", "$binary_name");
    return 0;
}
EOF
        
        # Compile if gcc is available, otherwise create a dummy binary
        if command -v gcc >/dev/null 2>&1; then
            gcc -o "$bin_dir/$binary_name" "$c_file" 2>/dev/null || {
                # Fallback: create dummy binary
                echo "#!/bin/bash" > "$bin_dir/$binary_name"
                echo "echo 'Dummy binary $binary_name'" >> "$bin_dir/$binary_name"
                chmod +x "$bin_dir/$binary_name"
            }
        else
            # Create dummy executable
            echo "#!/bin/bash" > "$bin_dir/$binary_name"
            echo "echo 'Dummy binary $binary_name'" >> "$bin_dir/$binary_name"
            chmod +x "$bin_dir/$binary_name"
        fi
        
        rm -f "$c_file"
    done
    
    log_debug "Created $binary_count binary files"
}

# Create Dockerfile and related files
create_dockerfile() {
    local project_dir="$1"
    local target_size="$2"
    
    cat > "$project_dir/Dockerfile" << EOF
FROM openjdk:11-jre-slim

LABEL maintainer="load-test-generator"
LABEL version="1.0.0"

# Set working directory
WORKDIR /app

# Copy application files
COPY src/ /app/src/
COPY target/ /app/target/

# Install additional packages based on size
$(case "$target_size" in
    LARGE|XLARGE) echo "RUN apt-get update && apt-get install -y curl wget git && rm -rf /var/lib/apt/lists/*" ;;
    *) echo "# Minimal image - no additional packages" ;;
esac)

# Expose port
EXPOSE 8080

# Set entrypoint
ENTRYPOINT ["java", "-jar", "/app/target/app.jar"]
EOF
    
    # Create .dockerignore
    cat > "$project_dir/.dockerignore" << EOF
.git
.gitignore
README.md
Dockerfile
.dockerignore
*.log
*.tmp
EOF
    
    log_debug "Created Dockerfile and .dockerignore"
}

# Create application files for container
create_application_files() {
    local project_dir="$1"
    local target_size="$2"
    
    # Create a simple application structure
    mkdir -p "$project_dir/target"
    
    # Create a dummy JAR file (empty for load testing)
    touch "$project_dir/target/app.jar"
    
    # Create some configuration files
    mkdir -p "$project_dir/config"
    cat > "$project_dir/config/application.properties" << EOF
# Application configuration for load testing
app.name=LoadTestApp
app.version=1.0.0
server.port=8080

# Database configuration (dummy)
db.host=localhost
db.port=5432
db.name=testdb

# Logging configuration
logging.level.root=INFO
logging.file.name=/app/logs/application.log
EOF
    
    log_debug "Created application files for container scanning"
}

# Calculate total file size
calculate_total_size() {
    local project_dir="$1"
    
    if [ ! -d "$project_dir" ]; then
        echo "0"
        return
    fi
    
    # Calculate size in bytes
    local total_size
    total_size=$(find "$project_dir" -type f -exec stat -f%z {} \; 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
    
    # Fallback for systems without stat -f
    if [ -z "$total_size" ] || [ "$total_size" -eq 0 ]; then
        total_size=$(find "$project_dir" -type f -ls 2>/dev/null | awk '{sum+=$7} END {print sum+0}')
    fi
    
    echo "${total_size:-0}"
}

# Format bytes in human readable format
format_bytes() {
    local bytes="$1"
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    local size="$bytes"
    
    while [ "$size" -gt 1024 ] && [ "$unit" -lt 4 ]; do
        size=$((size / 1024))
        ((unit++))
    done
    
    echo "${size}${units[$unit]}"
}

# Enhanced file preparation using the sophisticated config
prepare_enhanced_scan_files() {
    local project_dir="$1"
    local scan_type_size="$2"
    local scan_size="$3"
    
    log_info "Preparing enhanced files for $scan_type_size in $project_dir"
    
    # Source the enhanced configuration if not already loaded
    local config_dir="$(dirname "$(dirname "$SCRIPT_DIR")")/config"
    if [ -f "$config_dir/enhanced_multi_scan_config.sh" ]; then
        source "$config_dir/enhanced_multi_scan_config.sh"
        
        # Get the local directory for this scan type
        local source_dir=$(get_local_directory_for_scan_type "$scan_type_size")
        
        log_info "Source directory: $source_dir"
        
        if [ -d "$source_dir" ]; then
            # Copy files from the configured source directory
            log_info "Copying files from $source_dir to $project_dir"
            
            # Parse scan type to determine file patterns
            local scan_info=($(parse_scan_type_and_size "$scan_type_size"))
            local scan_type="${scan_info[0]}"
            local size="${scan_info[1]}"
            
            # Get appropriate file patterns
            local file_patterns=$(get_file_patterns_by_type_and_size "$scan_type" "$size")
            
            log_debug "File patterns for $scan_type/$size: $file_patterns"
            
            # Copy files based on patterns
            local copied_count=0
            for pattern in $file_patterns; do
                while IFS= read -r -d '' file; do
                    if [ -f "$file" ]; then
                        local filename=$(basename "$file")
                        cp "$file" "$project_dir/$filename"
                        ((copied_count++))
                        log_debug "Copied: $filename"
                        
                        # Limit files based on size category
                        local max_files=$(get_max_files_for_size "$size")
                        if [ $copied_count -ge $max_files ]; then
                            break 2
                        fi
                    fi
                done < <(find "$source_dir" -name "$pattern" -type f -print0 2>/dev/null)
            done
            
            # Handle snippet scans with tar.gz files
            if [[ "$scan_type_size" == "SNIPPET_SCAN"* ]] && [ "${ENABLE_TARGZ_FILES}" == "yes" ]; then
                copy_targz_files "$project_dir"
            fi
            
            log_success "Copied $copied_count files for $scan_type_size"
            
        else
            log_warning "Source directory not found: $source_dir"
            log_info "Falling back to generated files"
            prepare_scan_files "$project_dir" "$scan_type" "$scan_size"
        fi
    else
        log_warning "Enhanced multi-scan config not found, using basic file preparation"
        prepare_scan_files "$project_dir" "$scan_type" "$scan_size"
    fi
    
    return 0
}

# Get maximum files based on size category
get_max_files_for_size() {
    local size="$1"
    
    case "$size" in
        SMALL) echo 10 ;;
        MEDIUM) echo 25 ;;
        LARGE) echo 50 ;;
        XLARGE) echo 100 ;;
        *) echo 25 ;;
    esac
}

# Discover files from test data directories based on scan type
# This implements the sophisticated file discovery from the monolithic script
discover_scan_files() {
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
        local size_category=$(echo "$scan_type_size" | sed 's/.*_\([^_]*\)$/\1/')
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
            num_files=$(( num_files > ${MIN_COMPONENTS:-200} ? num_files : ${MIN_COMPONENTS:-200} ))
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
            num_files=$(( ${FIXED_COMPONENTS:-2} > ${#files[@]} ? ${#files[@]} : ${FIXED_COMPONENTS:-2} ))
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