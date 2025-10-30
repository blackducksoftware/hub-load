#!/bin/bash

# Test Data Setup Script
# Creates and populates test data directory structure for Black Duck load testing
# Supports different scan types and sizes to match GCS structure

set -e

SCRIPT_DIR=$(dirname $0)
TEST_DATA_DIR="$SCRIPT_DIR"
SCASS_DIR="$TEST_DATA_DIR/SCASS"

echo "=== Black Duck Load Test Data Setup ==="
echo "Setting up test data in: $TEST_DATA_DIR"

# Create directory structure if not exists
mkdir -p "$SCASS_DIR"

# Directory structure matching GCS
DIRECTORIES=(
    "SCA_NON_BDIOS_BINARY_LARGE"
    "SCA_NON_BDIOS_BINARY_SM_MEDIUM" 
    "SCA_NON_BDIOS_BINARY_XLARGE"
    "SCA_NON_BDIOS_CONTAINER_LARGE"
    "SCA_NON_BDIOS_CONTAINER_SM_MEDIUM"
    "SCA_NON_BDIOS_CONTAINER_XLARGE"
    "SCA_NON_BDIOS_LARGE"
    "SCA_NON_BDIOS_SM_MEDIUM"
)

echo "Creating directory structure..."
for dir in "${DIRECTORIES[@]}"; do
    mkdir -p "$SCASS_DIR/$dir"
    echo "  Created: $SCASS_DIR/$dir"
done

# Download and extract base data
cd "$TEST_DATA_DIR"

if [ ! -f "jars.zip" ] && [ ! -d "base_jars" ]; then
    echo "Downloading jars.zip from S3..."
    wget https://bds-sa-data-files.s3.us-east-2.amazonaws.com/jars.zip
    
    echo "Extracting jars.zip..."
    unzip -q jars.zip
    rm -rf __MACOSX
    
    # Rename to base_jars for organization
    if [ -d "jars" ]; then
        mv jars base_jars
    fi
    
    echo "Cleaning up jars.zip..."
    rm jars.zip
fi

if [ ! -f "sources.zip" ] && [ ! -d "base_sources" ]; then
    echo "Downloading sources.zip from S3..."
    wget https://bds-sa-data-files.s3.us-east-2.amazonaws.com/sources.zip
    
    echo "Extracting sources.zip..."
    unzip -q sources.zip
    rm -rf __MACOSX
    
    # Rename to base_sources for organization
    if [ -d "sources" ]; then
        mv sources base_sources
    fi
    
    echo "Cleaning up sources.zip..."
    rm sources.zip
fi

# Function to populate directory with files based on size
populate_directory() {
    local target_dir="$1"
    local size_type="$2"
    local scan_type="$3"
    
    echo "Populating $target_dir (${size_type}, ${scan_type})..."
    
    # Determine file count and types based on size (keeping small for testing)
    case "$size_type" in
        "SM_MEDIUM")
            file_count=2
            ;;
        "LARGE")
            file_count=3
            ;;
        "XLARGE")
            file_count=3
            ;;
        *)
            file_count=2
            ;;
    esac
    
    # Copy files based on scan type
    if [[ "$scan_type" == *"BINARY"* ]]; then
        # For binary scans, use jar files
        if [ -d "base_jars" ]; then
            cp -r base_jars/* "$target_dir/" 2>/dev/null || true
            
            # Copy only the needed number of jar files
            jar_files=($(find base_jars -name "*.jar" 2>/dev/null | head -$file_count))
            counter=1
            for jar in "${jar_files[@]}"; do
                if [ -f "$jar" ] && [ $counter -le $file_count ]; then
                    cp "$jar" "$target_dir/test_${counter}.jar"
                    ((counter++))
                fi
            done
        fi
    elif [[ "$scan_type" == *"CONTAINER"* ]]; then
        # For container scans, create Dockerfiles and related files
        for i in $(seq 1 $file_count); do
            cat > "$target_dir/Dockerfile_${i}" << EOF
FROM ubuntu:20.04
RUN apt-get update && apt-get install -y curl wget
COPY app_${i}.jar /app/
WORKDIR /app
CMD ["java", "-jar", "app_${i}.jar"]
EOF
            # Create a dummy jar file
            if [ -d "base_jars" ]; then
                first_jar=$(find base_jars -name "*.jar" | head -1)
                if [ -f "$first_jar" ]; then
                    cp "$first_jar" "$target_dir/app_${i}.jar"
                fi
            fi
        done
    else
        # For signature scans, use source files and jars
        if [ -d "base_sources" ]; then
            cp -r base_sources/* "$target_dir/" 2>/dev/null || true
        fi
        if [ -d "base_jars" ]; then
            cp -r base_jars/* "$target_dir/" 2>/dev/null || true
        fi
        
        # Add simple test files to reach target count
        current_count=$(find "$target_dir" -type f 2>/dev/null | wc -l)
        for i in $(seq $((current_count + 1)) $file_count); do
            echo "This is test file ${i} for ${scan_type} ${size_type}" > "$target_dir/test_file_${i}.txt"
        done
    fi
    
    file_count_actual=$(find "$target_dir" -type f | wc -l)
    echo "  Populated with $file_count_actual files"
}

# Populate each directory
for dir in "${DIRECTORIES[@]}"; do
    target_path="$SCASS_DIR/$dir"
    
    # Extract size and scan type from directory name
    if [[ "$dir" == *"BINARY"* ]]; then
        scan_type="BINARY"
    elif [[ "$dir" == *"CONTAINER"* ]]; then
        scan_type="CONTAINER"
    else
        scan_type="SIGNATURE"
    fi
    
    if [[ "$dir" == *"SM_MEDIUM"* ]]; then
        size_type="SM_MEDIUM"
    elif [[ "$dir" == *"LARGE"* ]] && [[ "$dir" != *"XLARGE"* ]]; then
        size_type="LARGE"
    elif [[ "$dir" == *"XLARGE"* ]]; then
        size_type="XLARGE"
    else
        size_type="MEDIUM"
    fi
    
    populate_directory "$target_path" "$size_type" "$scan_type"
done

# Create a README file
cat > "$TEST_DATA_DIR/README.md" << 'EOF'
# Black Duck Load Test Data

This directory contains test data organized to match the GCS bucket structure for Black Duck load testing.

## Directory Structure

```
test-data/
├── SCASS/
│   ├── SCA_NON_BDIOS_BINARY_LARGE/      # Binary scan files (large dataset)
│   ├── SCA_NON_BDIOS_BINARY_SM_MEDIUM/  # Binary scan files (small-medium dataset)
│   ├── SCA_NON_BDIOS_BINARY_XLARGE/     # Binary scan files (extra large dataset)
│   ├── SCA_NON_BDIOS_CONTAINER_LARGE/   # Container scan files (large dataset)
│   ├── SCA_NON_BDIOS_CONTAINER_SM_MEDIUM/ # Container scan files (small-medium dataset)
│   ├── SCA_NON_BDIOS_CONTAINER_XLARGE/  # Container scan files (extra large dataset)
│   ├── SCA_NON_BDIOS_LARGE/            # Signature scan files (large dataset)
│   └── SCA_NON_BDIOS_SM_MEDIUM/        # Signature scan files (small-medium dataset)
├── base_jars/                          # Original jar files from S3
├── base_sources/                       # Original source files from S3
└── setup-test-data.sh                  # This setup script
```

## Usage

1. Run `./setup-test-data.sh` to download and organize test data
2. Configure your load testing scripts to use this local directory when `USE_GCS=no`
3. Files are organized by scan type and size to match the enhanced multi-type scanning system

## File Counts by Size

- SM_MEDIUM: 2 files
- LARGE: 3 files  
- XLARGE: 3 files

## Scan Types

- **BINARY**: Jar files for binary scanning
- **CONTAINER**: Dockerfiles and associated files for container scanning
- **SIGNATURE**: Mixed source files and jars for signature scanning
EOF

echo ""
echo "=== Setup Complete ==="
echo "Test data directory structure created at: $TEST_DATA_DIR"
echo "Total directories: $(find "$SCASS_DIR" -type d | wc -l)"
echo "Total files: $(find "$SCASS_DIR" -type f | wc -l)"
echo ""
echo "To use this data:"
echo "1. Set USE_GCS=no in your environment"
echo "2. Set LOCAL_TEST_DATA_DIR=$TEST_DATA_DIR"
echo "3. Run your load testing scripts"
echo ""
echo "See README.md for more details."