# Hub Load Testing - Quick Start Guide

## Prerequisites

1. **Java 17** installed (required by Synopsys Detect)
2. **Test data** available in `test-data/SCASS/` directory
3. **Black Duck Hub** URL and API token

## Common Workflows

### 1. Test Container Scans (Debug Mode)

```bash
# Navigate to project root
cd /path/to/hub-load

# Source container debug config (sets DEBUG=yes, CONTAINER_SCAN only)
source src/hub_load/config/debug_container_scan.sh

# Run with your Hub credentials
BD_HUB_URL=https://your-hub.example.com \
  API_TOKEN=your_api_token \
  MAX_SCANS=1 \
  ./src/hub_load/core/hub_load_main.sh
```

### 2. Test Binary Scans (Debug Mode)

```bash
# Source binary debug config
source src/hub_load/config/debug_binary_scan.sh

# Run
BD_HUB_URL=https://your-hub.example.com \
  API_TOKEN=your_api_token \
  MAX_SCANS=1 \
  ./src/hub_load/core/hub_load_main.sh
```

### 3. Test Signature Scans (Debug Mode)

```bash
# Source signature debug config
source src/hub_load/config/debug_signature_scan.sh

# Run
BD_HUB_URL=https://your-hub.example.com \
  API_TOKEN=your_api_token \
  MAX_SCANS=1 \
  ./src/hub_load/core/hub_load_main.sh
```

### 4. Production Multi-Scan (No Debug)

```bash
# Don't source any debug config - use defaults
USE_GCS=no \
  ENABLE_ENHANCED_MULTI_SCAN=yes \
  MAX_SCANS=100 \
  DEBUG=no \
  BD_HUB_URL=https://your-hub.example.com \
  API_TOKEN=your_api_token \
  LOCAL_TEST_DATA_DIR=/path/to/test-data \
  ./src/hub_load/core/hub_load_main.sh
```

### 5. Reset Environment Variables

```bash
# After testing, reset all environment variables
source src/hub_load/config/reset_env.sh

# Or start a fresh shell
exec bash
```

## Environment Variable Quick Reference

### Essential Variables
```bash
BD_HUB_URL          # Black Duck Hub URL (required)
API_TOKEN           # API authentication token (required)
MAX_SCANS           # Number of scans to run (default: 3)
DEBUG               # Enable verbose logging: yes/no (default: no)
```

### Scan Configuration
```bash
SCAN_TYPE           # SIGNATURE_SCAN, BINARY_SCAN, or CONTAINER_SCAN
SYNCHRONOUS_SCANS   # Wait for results: yes/no (default: no)
PARALLEL_SCANS      # Parallel execution: yes/no (default: no)
FIXED_COMPONENTS    # Files per scan (default: 2 for signature, 1 for binary/container)
```

### Data Source
```bash
USE_GCS             # Use Google Cloud Storage: yes/no (default: no)
LOCAL_TEST_DATA_DIR # Path to local test data (default: ../../../test-data)
```

### Enhanced Multi-Scan
```bash
ENABLE_ENHANCED_MULTI_SCAN  # Enable multi-type distribution: yes/no
MULTI_SCAN_CONFIG           # Distribution for large scale (≥50 scans)
SMALL_SCAN_CONFIG           # Distribution for small scale (<50 scans)
```

## Typical Test Workflow

```bash
# Step 1: Verify test data exists
ls -la test-data/SCASS/

# Step 2: Test individual scan types
source src/hub_load/config/debug_container_scan.sh
BD_HUB_URL=https://... API_TOKEN=... MAX_SCANS=1 ./src/hub_load/core/hub_load_main.sh

# Step 3: Reset environment
source src/hub_load/config/reset_env.sh

# Step 4: Test mixed scans
source src/hub_load/config/debug_mixed_scans.sh
BD_HUB_URL=https://... API_TOKEN=... MAX_SCANS=10 ./src/hub_load/core/hub_load_main.sh

# Step 5: Reset again
source src/hub_load/config/reset_env.sh

# Step 6: Run production load test
USE_GCS=no ENABLE_ENHANCED_MULTI_SCAN=yes MAX_SCANS=100 \
  BD_HUB_URL=https://... API_TOKEN=... \
  ./src/hub_load/core/hub_load_main.sh
```

## Troubleshooting

### No test data files found
```bash
# Check if files exist
find test-data/SCASS -name "*.tar" -o -name "*.jar" -o -name "*.exe" | head -20

# Verify LOCAL_TEST_DATA_DIR is correct
echo $LOCAL_TEST_DATA_DIR
ls -la $LOCAL_TEST_DATA_DIR/SCASS/
```

### Java not found
```bash
# Install Java 17
brew install openjdk@17         # macOS
sudo apt install openjdk-17-jdk # Ubuntu/Debian

# Check Java version
java -version
```

### Debug logs not showing
```bash
# Ensure DEBUG is set to 'yes'
echo $DEBUG

# If not, source a debug config or set it manually
export DEBUG=yes
```

### Commands show unexpected parameters
```bash
# Reset environment and start fresh
source src/hub_load/config/reset_env.sh

# Or start a new shell
exec bash

# Then re-source the config you want
source src/hub_load/config/debug_container_scan.sh
```

## Debug Config Files

| Config File | Purpose | Scan Distribution |
|------------|---------|-------------------|
| `debug_container_scan.sh` | Container scans only | 100% CONTAINER_SCAN |
| `debug_binary_scan.sh` | Binary scans only | 100% BINARY_SCAN |
| `debug_signature_scan.sh` | Signature scans only | 100% SIGNATURE_SCAN |
| `debug_snippet_scan.sh` | Snippet scans only | 100% SNIPPET_SCAN |
| `debug_mixed_scans.sh` | Simple multi-type | 40% Binary, 40% Signature, 20% Container |
| `reset_env.sh` | Reset variables | Unsets all hub-load variables |

## Getting Help

```bash
# Show usage information
./src/hub_load/core/hub_load_main.sh --help

# Enable debug mode for verbose output
export DEBUG=yes

# Check recent changes
cat CLAUDE.md
```

## Example: Complete Container Scan Test

```bash
#!/bin/bash
# complete_container_test.sh

# 1. Navigate to project
cd /Users/karth/Library/CloudStorage/OneDrive-BlackDuckSoftware/Documents/Automation/blackducksoftware/hub-load

# 2. Verify test data
echo "Checking for container test data..."
find test-data/SCASS -name "*.tar" -type f | head -5

# 3. Source container debug config
echo "Loading container debug config..."
source src/hub_load/config/debug_container_scan.sh

# 4. Run a single scan test
echo "Running single container scan test..."
BD_HUB_URL=https://rg-250sph-2025-7-1.saas-staging.blackduck.com \
  API_TOKEN=your_token_here \
  MAX_SCANS=1 \
  ./src/hub_load/core/hub_load_main.sh

# 5. Check results
echo "Test completed. Check logs for results."

# 6. Reset environment for next test
echo "Resetting environment..."
source src/hub_load/config/reset_env.sh
```

Make it executable and run:
```bash
chmod +x complete_container_test.sh
./complete_container_test.sh
```
