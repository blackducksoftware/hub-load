# Debug Configurations for Individual Scan Types

This directory contains debug configuration files that allow you to test individual scan types in isolation before running the full multi-scan integration.

## Purpose

When debugging scan submission issues (especially with container scans), it's helpful to test each scan type independently with a simple 100% configuration before attempting complex multi-type distributions.

## Available Debug Configs

### 1. Container Scan Only
**File**: `debug_container_scan.sh`
```bash
source src/hub_load/config/debug_container_scan.sh
USE_GCS=no MAX_SCANS=3 ./src/hub_load/core/hub_load_main.sh
```
- 100% CONTAINER_SCAN_SMALL
- Looks for *.tar files
- Default: 3 scans, synchronous, no GCS
- **Uses modular architecture** (hub_load_main.sh)

### 2. Binary Scan Only
**File**: `debug_binary_scan.sh`
```bash
source src/hub_load/config/debug_binary_scan.sh
USE_GCS=no MAX_SCANS=3 ./src/hub_load/core/hub_load_main.sh
```
- 100% BINARY_SCAN_SMALL
- Looks for *.exe, *.dmg, *.rpm, *.deb, *.iso, etc.
- Default: 3 scans, synchronous, no GCS
- **Uses modular architecture** (hub_load_main.sh)

### 3. Signature Scan Only
**File**: `debug_signature_scan.sh`
```bash
source src/hub_load/config/debug_signature_scan.sh
USE_GCS=no MAX_SCANS=3 ./src/hub_load/core/hub_load_main.sh
```
- 100% SIGNATURE_SCAN_SMALL
- Looks for *.jar, *.war, *.ear, *.zip files
- Default: 3 scans, synchronous, no GCS
- **Uses modular architecture** (hub_load_main.sh)

### 4. Snippet Scan Only
**File**: `debug_snippet_scan.sh`
```bash
source src/hub_load/config/debug_snippet_scan.sh
USE_GCS=no MAX_SCANS=3 ./src/hub_load/core/hub_load_main.sh
```
- 100% SNIPPET_SCAN (uses SIGNATURE_SCAN with SNIPPETS=yes)
- Looks for *.tar.gz files in SCA_SNIPPETS directory
- Default: 3 scans, synchronous, no GCS
- **Uses modular architecture** (hub_load_main.sh)

### 5. Mixed Scans (Simple Distribution)
**File**: `debug_mixed_scans.sh`
```bash
source src/hub_load/config/debug_mixed_scans.sh
USE_GCS=no MAX_SCANS=10 ./src/hub_load/core/hub_load_main.sh
```
- 40% BINARY_SCAN_SMALL, 40% SIGNATURE_SCAN_SMALL, 20% CONTAINER_SCAN_SMALL
- Simple 3-type distribution for testing integration
- Default: 10 scans, synchronous, no GCS
- **Uses modular architecture** (hub_load_main.sh)

## Usage Workflow

### Step 1: Test Individual Scan Types
Start by testing each scan type individually to ensure they work:

```bash
# Test container scans first (since that's problematic)
source src/hub_load/config/debug_container_scan.sh
USE_GCS=no MAX_SCANS=3 BD_HUB_URL=https://your-hub.example.com API_TOKEN=your-token \
  ./src/hub_load/core/hub_load_main.sh

# Test binary scans
source src/hub_load/config/debug_binary_scan.sh
USE_GCS=no MAX_SCANS=3 BD_HUB_URL=https://your-hub.example.com API_TOKEN=your-token \
  ./src/hub_load/core/hub_load_main.sh

# Test signature scans
source src/hub_load/config/debug_signature_scan.sh
USE_GCS=no MAX_SCANS=3 BD_HUB_URL=https://your-hub.example.com API_TOKEN=your-token \
  ./src/hub_load/core/hub_load_main.sh
```

### Step 2: Test Simple Multi-Type Distribution
Once individual scans work, test a simple multi-type distribution:

```bash
source src/hub_load/config/debug_mixed_scans.sh
USE_GCS=no MAX_SCANS=10 BD_HUB_URL=https://your-hub.example.com API_TOKEN=your-token \
  ./src/hub_load/core/hub_load_main.sh
```

### Step 3: Full Integration
After validation, use the full configuration:

```bash
# Don't source any debug config - use default enhanced_multi_scan_config.sh
USE_GCS=no ENABLE_ENHANCED_MULTI_SCAN=yes MAX_SCANS=100 \
  BD_HUB_URL=https://your-hub.example.com API_TOKEN=your-token \
  ./src/hub_load/core/hub_load_main.sh
```

## Debugging Container Scan Issues

For container scan problems specifically:

```bash
# Enable debug mode and test container scans only
source src/hub_load/config/debug_container_scan.sh

# Override to force more verbose output
export DEBUG=yes
export DRY_RUN=no  # Set to 'yes' to test without actually submitting

# Check what files are available
ls -la "$LOCAL_TEST_DATA_DIR/SCASS/SCA_NON_BDIOS_CONTAINER_SM_MEDIUM/"

# Run the test using modular architecture
USE_GCS=no MAX_SCANS=1 BD_HUB_URL=https://your-hub.example.com API_TOKEN=your-token \
  ./src/hub_load/core/hub_load_main.sh
```

## Environment Variables

All debug configs set these defaults (can be overridden):

- `DEBUG=yes` - Enable verbose logging
- `ENABLE_ENHANCED_MULTI_SCAN=yes` - Use enhanced multi-scan mode
- `SYNCHRONOUS_SCANS=yes` - Wait for scan results (easier debugging)
- `PARALLEL_SCANS=no` - Run scans sequentially (easier debugging)
- `USE_GCS=no` - Use local test data (faster, no GCS required)
- `MAX_SCANS=3` (or 10 for mixed) - Small number for quick testing

## Expected Test Data Locations

When `USE_GCS=no`, the configs expect files in:

- Container: `$LOCAL_TEST_DATA_DIR/SCASS/SCA_NON_BDIOS_CONTAINER_SM_MEDIUM/*.tar`
- Binary: `$LOCAL_TEST_DATA_DIR/SCASS/SCA_NON_BDIOS_BINARY_SM_MEDIUM/*.{exe,dmg,rpm,deb,iso,...}`
- Signature: `$LOCAL_TEST_DATA_DIR/SCASS/SCA_NON_BDIOS_SM_MEDIUM/*.{jar,war,ear,zip}`
- Snippet: `$LOCAL_TEST_DATA_DIR/SCASS/SCA_SNIPPETS/*.tar.gz`

Verify files exist:
```bash
find test-data/SCASS -type f | head -20
```

## Tips

1. **Start Simple**: Always test with `MAX_SCANS=1` first
2. **Check Files First**: Verify test data exists before running scans
3. **Read Logs**: Debug mode shows detailed file discovery and selection
4. **One at a Time**: Test each scan type individually before mixing
5. **Synchronous First**: Use `SYNCHRONOUS_SCANS=yes` for easier debugging
6. **Local First**: Use `USE_GCS=no` to avoid GCS configuration issues

## Resetting Environment Variables

After sourcing debug configs, you may want to reset all environment variables:

### Option 1: Use the Reset Script (Recommended)
```bash
# Unset all hub-load environment variables
source src/hub_load/config/reset_env.sh
```

This will unset:
- All configuration variables (DEBUG, SYNCHRONOUS_SCANS, etc.)
- Multi-scan settings (MULTI_SCAN_CONFIG, SMALL_SCAN_CONFIG, etc.)
- Test data paths (LOCAL_TEST_DATA_DIR, USE_GCS, etc.)
- All other hub-load specific variables

### Option 2: Start a Fresh Shell
```bash
# Exit current shell and start new one
exec bash
# or
bash
```

### Option 3: Manual Unset (Minimal)
```bash
# Unset just the critical variables
unset MULTI_SCAN_CONFIG SMALL_SCAN_CONFIG DEBUG SYNCHRONOUS_SCANS
```

## Reverting to Production Config

To go back to the production multi-scan configuration:

```bash
# Option 1: Use reset script then run without debug config
source src/hub_load/config/reset_env.sh
USE_GCS=no ENABLE_ENHANCED_MULTI_SCAN=yes MAX_SCANS=100 \
  BD_HUB_URL=https://your-hub.example.com API_TOKEN=your-token \
  ./src/hub_load/core/hub_load_main.sh

# Option 2: Simply don't source any debug config in a fresh shell
# The default enhanced_multi_scan_config.sh will be used automatically
```
