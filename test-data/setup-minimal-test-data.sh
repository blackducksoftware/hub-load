#!/bin/bash

# Quick Test Data Setup Script
# Creates minimal test data (2-3 files per directory) without downloading large zip files

set -e

SCRIPT_DIR=$(dirname $0)
TEST_DATA_DIR="$SCRIPT_DIR"
SCASS_DIR="$TEST_DATA_DIR/SCASS"

echo "=== Black Duck Load Test Data Setup (Minimal) ==="
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
    "SCA_SNIPPETS"
)

echo "Creating directory structure..."
for dir in "${DIRECTORIES[@]}"; do
    mkdir -p "$SCASS_DIR/$dir"
    echo "  Created: $SCASS_DIR/$dir"
done

# Function to create test files based on scan type
create_test_files() {
    local target_dir="$1"
    local size_type="$2"
    local scan_type="$3"
    
    echo "Creating test files in $target_dir (${size_type}, ${scan_type})..."
    
    # Determine file count based on size
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
    
    # Create files based on scan type
    if [[ "$scan_type" == *"BINARY"* ]]; then
        # Create simple test jar files (just text files with .jar extension for testing)
        for i in $(seq 1 $file_count); do
            cat > "$target_dir/test${i}.jar" << EOF
# This is a placeholder jar file for testing
# In real scenarios, this would be a compiled Java archive
Main-Class: TestClass${i}
Version: 1.0
Build-Date: $(date)
EOF
        done
        
    elif [[ "$scan_type" == *"CONTAINER"* ]]; then
        # Create Dockerfiles and related files
        for i in $(seq 1 $file_count); do
            cat > "$target_dir/Dockerfile_${i}" << EOF
FROM ubuntu:20.04
RUN apt-get update && apt-get install -y curl wget
COPY app${i}.jar /app/
WORKDIR /app
EXPOSE 8080
CMD ["java", "-jar", "app${i}.jar"]
EOF
            # Create a simple jar reference
            echo "# This would be app${i}.jar for container ${i}" > "$target_dir/app${i}.jar.placeholder"
        done
        
    elif [[ "$target_dir" == *"SCA_SNIPPETS"* ]]; then
        # Create .tar.gz files for snippet scanning
        for i in $(seq 1 $file_count); do
            temp_dir="/tmp/snippet_$$_$i"
            mkdir -p "$temp_dir/src/main/java/com/example"
            
            cat > "$temp_dir/src/main/java/com/example/SnippetClass$i.java" << EOF
package com.example;

import java.util.List;
import java.util.ArrayList;

public class SnippetClass$i {
    private List<String> data = new ArrayList<>();
    
    public void processData() {
        data.add("Sample data for snippet scanning $i");
        System.out.println("Processing snippet data $i");
    }
}
EOF
            
            # Create tar.gz file (use absolute paths to avoid issues)
            (cd "$temp_dir" && tar -czf "$target_dir/snippet_source_$i.tar.gz" .)
            rm -rf "$temp_dir"
        done
        
    else
        # For signature scans, create source files
        for i in $(seq 1 $file_count); do
            mkdir -p "$target_dir/src/main/java/com/test"
            cat > "$target_dir/src/main/java/com/test/TestClass${i}.java" << EOF
package com.test;

public class TestClass${i} {
    public static void main(String[] args) {
        System.out.println("Hello from TestClass${i}");
        // Some dependencies for signature scanning
        java.util.List<String> list = new java.util.ArrayList<>();
        list.add("test-dependency-${i}");
    }
}
EOF
            # Create a simple pom.xml for Maven projects
            if [ $i -eq 1 ]; then
                cat > "$target_dir/pom.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.test</groupId>
    <artifactId>test-project-${size_type}</artifactId>
    <version>1.0-SNAPSHOT</version>
    <dependencies>
        <dependency>
            <groupId>junit</groupId>
            <artifactId>junit</artifactId>
            <version>4.13.2</version>
        </dependency>
    </dependencies>
</project>
EOF
            fi
        done
    fi
    
    file_count_actual=$(find "$target_dir" -type f | wc -l)
    echo "  Created $file_count_actual files"
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
    
    create_test_files "$target_path" "$size_type" "$scan_type"
done

# Create a simple README
cat > "$TEST_DATA_DIR/README.md" << 'EOF'
# Black Duck Load Test Data (Minimal)

This directory contains minimal test data (2-3 files per directory) organized to match the GCS bucket structure.

## Directory Structure

```
test-data/
└── SCASS/
    ├── SCA_NON_BDIOS_BINARY_LARGE/      # 3 test jar files
    ├── SCA_NON_BDIOS_BINARY_SM_MEDIUM/  # 2 test jar files
    ├── SCA_NON_BDIOS_BINARY_XLARGE/     # 3 test jar files
    ├── SCA_NON_BDIOS_CONTAINER_LARGE/   # 3 Dockerfiles + placeholders
    ├── SCA_NON_BDIOS_CONTAINER_SM_MEDIUM/ # 2 Dockerfiles + placeholders
    ├── SCA_NON_BDIOS_CONTAINER_XLARGE/  # 3 Dockerfiles + placeholders
    ├── SCA_NON_BDIOS_LARGE/            # 3 Java source files + pom.xml
    └── SCA_NON_BDIOS_SM_MEDIUM/        # 2 Java source files + pom.xml
```

## Usage

Set these environment variables to use local test data:
```bash
export USE_GCS=no
export LOCAL_TEST_DATA_DIR=/path/to/this/test-data/directory
```

Then run your load testing scripts normally.
EOF

echo ""
echo "=== Minimal Setup Complete ==="
echo "Test data directory structure created at: $TEST_DATA_DIR"
echo "Total directories: $(find "$SCASS_DIR" -type d | wc -l)"
echo "Total files: $(find "$SCASS_DIR" -type f | wc -l)"
echo ""
echo "To use this data:"
echo "1. Set USE_GCS=no in your environment"
echo "2. Set LOCAL_TEST_DATA_DIR=$TEST_DATA_DIR"
echo "3. Run your load testing scripts"