#!/bin/bash
#
# Docker entrypoint script for GCS integration and memory mapping
#

set -e

echo "=== Docker Hub Load Test Container ==="
echo "Memory Mapping: ${USE_MEMORY_MAPPING:-no}"
echo "GCS Integration: ${USE_GCS:-no}"

# Function to handle GCS authentication
setup_gcs_auth() {
    echo "Setting up GCS authentication..."
    
    # Check for service account key file
    if [ -n "$GOOGLE_APPLICATION_CREDENTIALS" ] && [ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
        echo "Using service account key: $GOOGLE_APPLICATION_CREDENTIALS"
        gcloud auth activate-service-account --key-file="$GOOGLE_APPLICATION_CREDENTIALS"
    elif [ -n "$GCS_SERVICE_ACCOUNT_KEY" ]; then
        # Service account key provided as environment variable
        echo "Setting up service account from environment variable"
        echo "$GCS_SERVICE_ACCOUNT_KEY" > /tmp/gcs-key.json
        export GOOGLE_APPLICATION_CREDENTIALS=/tmp/gcs-key.json
        gcloud auth activate-service-account --key-file="$GOOGLE_APPLICATION_CREDENTIALS"
    else
        echo "WARNING: No GCS authentication method found."
        echo "Please provide either:"
        echo "  - GOOGLE_APPLICATION_CREDENTIALS environment variable with path to key file"
        echo "  - GCS_SERVICE_ACCOUNT_KEY environment variable with key content"
        echo "  - Mount service account key file to container"
        return 1
    fi
    
    # Test authentication
    if gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
        echo "✓ GCS authentication successful"
        return 0
    else
        echo "✗ GCS authentication failed"
        return 1
    fi
}

# Function to test memory mapping
test_memory_mapping() {
    echo "Testing memory mapping functionality..."
    if python3 /home/hub_load/mmap_file_handler.py --help > /dev/null 2>&1; then
        echo "✓ Memory mapping handler is working"
        return 0
    else
        echo "✗ Memory mapping handler failed"
        return 1
    fi
}

# Main execution
main() {
    # Test memory mapping if enabled
    if [ "${USE_MEMORY_MAPPING}" == "yes" ]; then
        test_memory_mapping
    fi
    
    # Setup GCS if enabled
    if [ "${USE_GCS}" == "yes" ]; then
        if setup_gcs_auth; then
            echo "GCS setup completed successfully"
        else
            echo "GCS setup failed - continuing without GCS"
            export USE_GCS=no
        fi
    fi
    
    # Run the provided command or default to test script
    if [ $# -eq 0 ]; then
        echo "No command provided. Running test script..."
        exec /home/hub_load/test_memory_mapping.sh
    else
        echo "Executing command: $@"
        exec "$@"
    fi
}

# Run main function
main "$@"