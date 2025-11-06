# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Hub Load is a containerized Black Duck SCA (Software Composition Analysis) load testing system that generates test workloads for Black Duck Hub instances. It supports four scan types (SIGNATURE_SCAN, BINARY_SCAN, CONTAINER_SCAN, and TAR.GZ file handling) with enhanced multi-scan capabilities.

**Key Technologies**: Bash scripts, Docker, Kubernetes, GCS integration, Synopsys Detect

**CRITICAL**: Always use `src/hub_load/core/hub_load_main.sh` (modular architecture). Never use `submit_scans_fixed.sh` (legacy, has known issues).

## Architecture

### Modular Structure

The codebase recently transitioned from a 2053-line monolithic script to a modular architecture to improve maintainability and reduce syntax/variable corruption issues:

```
src/hub_load/
├── hub_load_test.sh              # Main entry point - delegates to core
├── core/                         # Core load testing functionality
│   ├── submit_scans_fixed.sh    # Main load testing engine (legacy/compatibility)
│   ├── hub_load_main.sh         # Modular main entry point
│   └── lib/                     # Modular components
│       ├── common.sh            # Logging, config, validation (~95 lines)
│       ├── parallel_manager.sh  # Parallel execution management (~180 lines)
│       ├── scan_manager.sh      # Scan orchestration (~200 lines)
│       └── file_manager.sh      # File operations (~350 lines)
├── config/                      # Configuration files
│   ├── enhanced_multi_scan_config.sh  # Multi-scan type configuration
│   └── common_configs.sh        # Common configuration
├── scripts/                     # Utility scripts
│   └── download-packages.sh     # Package download functionality
├── memory_mapping/              # Memory mapping for 27.5% faster file access
│   ├── mmap_file_handler.py    # Python memory mapping handler
│   ├── mmap_wrapper.sh          # Shell wrapper
│   └── multi_type_mmap_handler.py
└── docker/                      # Docker configuration
    └── docker-entrypoint.sh     # Container entry point
```

**Key Architecture Decision**: The modular architecture (`hub_load_main.sh` + lib modules) **MUST** be used for all development and operations. The legacy `submit_scans_fixed.sh` has known issues (syntax errors, variable corruption, debugging nightmares) and should be avoided. When making changes:
- **ALWAYS** use `core/hub_load_main.sh` as the entry point
- Edit modular components in `core/lib/` for new features
- Each module has isolated error handling to prevent cascading failures
- `submit_scans_fixed.sh` exists only for legacy reference - DO NOT USE

### Scan Types

1. **SIGNATURE_SCAN**: Uses .jar files from test data repositories
2. **BINARY_SCAN**: Uses executable/binary files (1 file per scan default)
3. **CONTAINER_SCAN**: Uses Dockerfiles and container images
4. **TAR.GZ Handling**: Archive file processing (replaces snippet scans)

Each scan type has size variants: SMALL, MEDIUM, LARGE, XLARGE (e.g., `BINARY_SCAN_SMALL`, `SIGNATURE_SCAN_LARGE`)

### Test Data Structure

```
test-data/SCASS/
├── SCA_NON_BDIOS_BINARY_LARGE/
├── SCA_NON_BDIOS_BINARY_SM_MEDIUM/
├── SCA_NON_BDIOS_BINARY_XLARGE/
├── SCA_NON_BDIOS_CONTAINER_LARGE/
├── SCA_NON_BDIOS_CONTAINER_SM_MEDIUM/
├── SCA_NON_BDIOS_CONTAINER_XLARGE/
├── SCA_NON_BDIOS_LARGE/
├── SCA_NON_BDIOS_SM_MEDIUM/
└── SCA_SNIPPETS/
```

Test data can be sourced from:
- **Local directories** (USE_GCS=no): Using LOCAL_TEST_DATA_DIR
- **Google Cloud Storage** (USE_GCS=yes): Using GCS_BUCKET and GCS_PREFIX

## Development Commands

### Complete Parameter Reference for Starting Tests

When starting a test, you can configure the behavior using environment variables. Here's a comprehensive list of all available parameters:

#### Required Parameters

```bash
API_TOKEN="your-api-token-here"           # Black Duck API token (REQUIRED)
BD_HUB_URL="https://your-hub.com"         # Black Duck Hub URL (REQUIRED)
```

#### Test Execution Parameters

```bash
MAX_SCANS=10                              # Total number of scans to run (default: 3)
TEST_DURATION_HOURS=4                     # Test duration in hours (default: 8)
TARGET_DURATION=3600                      # Target seconds per scan for cadence (calculated from TEST_DURATION_HOURS)
```

#### Scan Type Configuration

```bash
# Single scan type mode
SCAN_TYPE=SIGNATURE_SCAN                  # SIGNATURE_SCAN, BINARY_SCAN, or CONTAINER_SCAN (default: SIGNATURE_SCAN)

# Enhanced multi-scan mode (distribute across multiple scan types)
ENABLE_ENHANCED_MULTI_SCAN=yes            # Enable multi-type distribution (yes/no, default: no)
MULTI_SCAN_CONFIG="BINARY_SCAN_SMALL:40,SIGNATURE_SCAN_MEDIUM:35,CONTAINER_SCAN_SMALL:25"  # Distribution percentages
```

#### Data Source Configuration

```bash
# Local test data (recommended for development)
USE_GCS=no                                # Use local test data instead of GCS (yes/no, default: no)
LOCAL_TEST_DATA_DIR="/path/to/test-data/SCASS"  # Path to local test data directory

# Google Cloud Storage (for production)
USE_GCS=yes                               # Use Google Cloud Storage (yes/no)
GCS_BUCKET="your-bucket-name"             # GCS bucket name
GCS_PREFIX="path/to/test-data"            # GCS prefix/folder path
```

#### Parallel Execution

```bash
PARALLEL_SCANS=yes                        # Enable parallel execution (yes/no, default: no)
MAX_PARALLEL_JOBS=4                       # Number of concurrent scans (default: 3)
CADENCE_WAIT_FOR_SLOT=0                   # Wait for parallel slot if all busy (seconds, default: 0)
```

#### Scan Behavior

```bash
SYNCHRONOUS_SCANS=yes                     # Wait for scan results (yes/no, default: no)
RANDOM_SCANS=yes                          # Randomize file selection (yes/no, default: no)
FAIL_ON_SEVERITIES="BLOCKER,CRITICAL"     # Fail on policy violations (default: NONE)
API_TIMEOUT=7200                          # Detect timeout in seconds (default: 7200)
```

#### Multiple Versions & Codelocations

```bash
MAX_VERSIONS=2                            # Number of versions per project (default: 1)
MAX_CODELOCATIONS=3                       # Number of codelocations per version (default: 1)
FIXED_COMPONENTS=2                        # Number of files per scan (for signature scans, default: 2)
```

#### Instance Isolation & Session Tracking

```bash
INSTANCE_ID="test-instance-1"             # Unique instance identifier (default: auto-generated hostname-PID)
RUN_SESSION_ID="20251106-120000-12345"    # Session ID for log filtering (default: auto-generated YYYYMMDD-HHMMSS-PID)
CLEAN_OLD_LOGS=yes                        # Clean old logs at startup (yes/no, default: no)
```

#### Performance & Debugging

```bash
USE_MEMORY_MAPPING=yes                    # Enable memory mapping for 27.5% faster file access (yes/no, default: yes)
CLEANUP_TEMP_FILES=yes                    # Remove temp scan directories after successful submission (yes/no, default: yes)
DEBUG=yes                                 # Enable debug logging (yes/no, default: no)
```

#### Snippet Scan Settings

```bash
SNIPPETS=yes                              # Enable snippet matching (yes/no, default: no)
STRING_SEARCH=yes                         # Enable license/copyright search (yes/no, default: no)
```

### Example: Complete Test Configuration

Here's a complete example showing all commonly used parameters:

```bash
# Full production-like load test with all parameters
INSTANCE_ID="loadtest-1" \
RUN_SESSION_ID="20251106-120000" \
API_TOKEN="NTE2MmI0OTktZWYzYS00MDM0LWI2ZTQtNWRlMDg3ZjNmNjUyOjI1ZGFjNTI4LTBmZjYtNDAyNi04YjJlLTkyNDZmZmQwNjJlOQ==" \
BD_HUB_URL="https://rg-250sph-2025-7-1.saas-staging.blackduck.com" \
MAX_SCANS=480 \
TEST_DURATION_HOURS=4 \
ENABLE_ENHANCED_MULTI_SCAN=yes \
MULTI_SCAN_CONFIG="BINARY_SCAN_SMALL:25,BINARY_SCAN_LARGE:15,SIGNATURE_SCAN_SMALL:25,SIGNATURE_SCAN_LARGE:15,CONTAINER_SCAN_SMALL:10,CONTAINER_SCAN_LARGE:10" \
PARALLEL_SCANS=yes \
MAX_PARALLEL_JOBS=4 \
MAX_VERSIONS=2 \
MAX_CODELOCATIONS=2 \
FIXED_COMPONENTS=2 \
USE_GCS=no \
LOCAL_TEST_DATA_DIR="/Users/karth/Library/CloudStorage/OneDrive-BlackDuckSoftware/Documents/Automation/blackducksoftware/hub-load/test-data/SCASS" \
USE_MEMORY_MAPPING=yes \
CLEANUP_TEMP_FILES=yes \
CLEAN_OLD_LOGS=no \
DEBUG=no \
./src/hub_load/core/hub_load_main.sh
```

### Running Tests Locally (Modular Architecture)

**IMPORTANT**: Always use `hub_load_main.sh`, NOT `submit_scans_fixed.sh` or `hub_load_test.sh`

```bash
# Basic local test with signature scans (modular)
USE_GCS=no ./src/hub_load/core/hub_load_main.sh

# Test with specific scan type
USE_GCS=no SCAN_TYPE=BINARY_SCAN MAX_SCANS=5 ./src/hub_load/core/hub_load_main.sh

# Enhanced multi-scan testing with local data
USE_GCS=no ENABLE_ENHANCED_MULTI_SCAN=yes MAX_SCANS=10 ./src/hub_load/core/hub_load_main.sh

# Parallel execution testing
USE_GCS=no PARALLEL_SCANS=yes MAX_PARALLEL_JOBS=3 MAX_SCANS=10 ./src/hub_load/core/hub_load_main.sh

# Debug mode
DEBUG=yes USE_GCS=no ./src/hub_load/core/hub_load_main.sh
```

### Debug Individual Scan Types

Use debug configurations for testing specific scan types in isolation:

```bash
# Test container scans only (helpful for debugging container issues)
source src/hub_load/config/debug_container_scan.sh
USE_GCS=no MAX_SCANS=3 ./src/hub_load/core/hub_load_main.sh

# Test binary scans only
source src/hub_load/config/debug_binary_scan.sh
USE_GCS=no MAX_SCANS=3 ./src/hub_load/core/hub_load_main.sh

# Test signature scans only
source src/hub_load/config/debug_signature_scan.sh
USE_GCS=no MAX_SCANS=3 ./src/hub_load/core/hub_load_main.sh

# Test mixed scan types
source src/hub_load/config/debug_mixed_scans.sh
USE_GCS=no MAX_SCANS=10 ./src/hub_load/core/hub_load_main.sh

# Reset environment variables after testing
source src/hub_load/config/reset_env.sh
```

### Running Integration Tests

Integration test scripts are located at the repository root:

```bash
# Test enhanced summary functionality
./test_enhanced_summary.sh

# Test all scan type configurations
source src/hub_load/config/test_all_scan_types.sh

# Syntax validation of all modules
bash -n src/hub_load/core/hub_load_main.sh
bash -n src/hub_load/core/lib/*.sh
```

### Building Docker Image

```bash
cd src
docker build -t hub-load:latest .

# Tag for GCR
docker tag hub-load:latest gsasig/hub-load:latest
```

### Docker Deployment

**Note**: Update Docker entrypoint to use modular architecture

```bash
# Run signature scan in container (modular)
docker run --rm \
  -e BD_HUB_URL=https://your-hub.example.com \
  -e API_TOKEN=your-token \
  -e MAX_SCANS=3 \
  gsasig/hub-load \
  /home/hub_load/core/hub_load_main.sh

# Run binary scan (modular)
docker run --rm \
  -e SCAN_TYPE=BINARY_SCAN \
  -e BD_HUB_URL=https://your-hub.example.com \
  -e API_TOKEN=your-token \
  -e MAX_SCANS=5 \
  gsasig/hub-load \
  /home/hub_load/core/hub_load_main.sh
```

### Kubernetes Deployment

```bash
# Deploy with standard deployment
cd k8s
kubectl apply -f hub-load-deployment.yaml

# Deploy with jobs (one-time execution)
kubectl apply -f hub-load-jobs.yaml

# Deploy with monitoring
kubectl apply -f hub-load-monitoring.yaml

# Deploy services
kubectl apply -f hub-load-services.yaml

# Check status
kubectl get pods -n hub-load
kubectl logs -f <pod-name> -n hub-load

# Scale deployment
kubectl scale deployment <deployment-name> --replicas=10 -n hub-load
```

## Key Configuration Variables

### Required Variables
- `BD_HUB_URL`: Black Duck Hub URL
- `API_TOKEN`: API token for authentication

### Scan Behavior
- `SCAN_TYPE`: SIGNATURE_SCAN, BINARY_SCAN, or CONTAINER_SCAN (default: SIGNATURE_SCAN)
- `MAX_SCANS`: Maximum number of scans (default: 3)
- `SYNCHRONOUS_SCANS`: Wait for results (yes/no, default: no)
- `PARALLEL_SCANS`: Enable parallel execution (yes/no, default: no)
- `MAX_PARALLEL_JOBS`: Concurrent parallel scans (default: 3)

### Enhanced Multi-Scan
- `ENABLE_ENHANCED_MULTI_SCAN`: Enable multi-type scan distribution (yes/no)
- `MULTI_SCAN_CONFIG`: Distribution config (e.g., "BINARY_SCAN_SMALL:40,SIGNATURE_SCAN_MEDIUM:35,CONTAINER_SCAN_SMALL:25")

### Data Source
- `USE_GCS`: Use Google Cloud Storage (yes/no, default: no)
- `LOCAL_TEST_DATA_DIR`: Path to local test data (when USE_GCS=no)
- `GCS_BUCKET`: GCS bucket name (when USE_GCS=yes)
- `GCS_PREFIX`: GCS prefix/folder path

### Performance
- `USE_MEMORY_MAPPING`: Enable memory mapping for 27.5% faster file access (yes/no, default: yes)
- `DEBUG`: Enable debug logging (yes/no, default: no)
- `CLEANUP_TEMP_FILES`: Remove temporary scan directories after successful submission (yes/no, default: yes)

### Multiple Versions and Codelocations (NEW - Nov 2025)
- `MAX_VERSIONS`: Number of project versions to create per scan (default: 1)
- `MAX_CODELOCATIONS`: Number of codelocations per version (default: 1)

**Example**: `MAX_VERSIONS=2 MAX_CODELOCATIONS=3` creates 6 total scans (2 versions × 3 codelocations)

### Instance Isolation and Session Tracking (NEW - Nov 5, 2025)
- `INSTANCE_ID`: Unique identifier for running multiple concurrent test instances (auto-generated: `hostname-PID`)
- `RUN_SESSION_ID`: Unique session ID per test run to filter logs (auto-generated: `YYYYMMDD-HHMMSS-PID`)
- `CLEAN_OLD_LOGS`: Clean old log files from previous runs at startup (yes/no, default: no)

**Example**: Run 3 concurrent test instances without conflicts:
```bash
INSTANCE_ID="test-1" ./src/hub_load/core/hub_load_main.sh &
INSTANCE_ID="test-2" ./src/hub_load/core/hub_load_main.sh &
INSTANCE_ID="test-3" ./src/hub_load/core/hub_load_main.sh &
```

Each instance gets isolated log directories:
- `/tmp/hub_load_logs/test-1/parallel/`
- `/tmp/hub_load_logs/test-2/parallel/`
- `/tmp/hub_load_logs/test-3/parallel/`

## Recent Updates: Legacy Compatibility & Enhancements (November 2025)

The modular architecture was recently enhanced with complete legacy compatibility while maintaining all modular benefits:

### 1. Dynamic Codelocation Directories

Directory structure now supports multiple codelocations matching legacy pattern:

**Structure:**
```
/tmp/scan_${scan_id}_$$/
└── ${project_name}/
    ├── cl-1/source/    # Codelocation 1
    ├── cl-2/source/    # Codelocation 2
    └── cl-N/source/    # Codelocation N
```

Controlled by `MAX_CODELOCATIONS` environment variable (default: 1).

### 2. Multiple Versions Support

Each project can have multiple versions, each with multiple codelocations:

```bash
# Create 2 versions with 3 codelocations each = 6 total scans
MAX_VERSIONS=2 MAX_CODELOCATIONS=3 ./test_individual_scans.sh container 1
```

### 3. Enhanced Naming with Timestamps & Randomization

All scan identifiers now include timestamps and randomization for easy tracking:

**Project Names:**
- Format: `enhanced-{scan_type}-{random}-on-{DDMMYYYY-HHMMSS}`
- Example: `enhanced-container_scan_small-12345-on-03112025-143052`

**Version Names:**
- Format: `v{num}-{YYYYMMDD-HHMMSS}`
- Example: `v1-20251103-143052`

**Code Location Names:**
- Format: `{hostname}-{type}-cl-{num}-{random}-{DDMMYYYY}`
- Examples:
  - `local-cl-1-12345-03112025` (SIGNATURE_SCAN)
  - `local-binary-cl-1-23456-03112025` (BINARY_SCAN)
  - `local-container-cl-1-34567-03112025` (CONTAINER_SCAN)

**Scan IDs:**
- Format: `scan_{num}_{random}_{YYYYMMDD-HHMMSS}`
- Example: `scan_1_12345_20251103-143052`

**Benefits:**
- ✅ Unique identifiers prevent collisions
- ✅ Easy to track and filter by date/time
- ✅ Self-documenting names
- ✅ Sortable chronologically

### 4. Complete Detect Parameters Alignment

All scan types now use the exact parameters from legacy `submit_scans_fixed.sh`:

**SIGNATURE_SCAN:**
```bash
--detect.project.version.name='v1-20251103-143052'
--detect.code.location.name='local-cl-1-12345-03112025'
--detect.source.path='project/cl-1'  # Points to codelocation dir
```

**BINARY_SCAN:**
```bash
--detect.project.version.name='v1-20251103-143052'
--detect.code.location.name='local-binary-cl-1-23456-03112025'
--detect.binary.scan.file.path='project/cl-1/source/file.exe'
```

**CONTAINER_SCAN:**
```bash
--detect.project.version.name='v1-20251103-143052'
--detect.container.scan.file.path='project/cl-1/source/container.tar'  # Fixed parameter name
--detect.cleanup=false
--detect.diagnostic=true  # When DEBUG=yes
```

**All scan types now support:**
- `--blackduck.trust.cert=true`
- `--detect.timeout='$API_TIMEOUT'`
- `--detect.parallel.processors=-1` (SIGNATURE and BINARY only)
- `--logging.level.detect=TRACE` (when DEBUG=yes)
- `--detect.wait.for.results=true` (when SYNCHRONOUS_SCANS=yes)
- `--detect.policy.check.fail.on.severities='...'` (when FAIL_ON_SEVERITIES set)

### 5. Testing with Multiple Versions/Codelocations

```bash
# Single version, single codelocation (default - backward compatible)
./test_individual_scans.sh container 1

# Multiple codelocations (3 scans total)
MAX_CODELOCATIONS=3 ./test_individual_scans.sh container 1

# Multiple versions (2 scans total)
MAX_VERSIONS=2 ./test_individual_scans.sh signature 1

# Multiple versions and codelocations (6 scans total: 2×3)
MAX_VERSIONS=2 MAX_CODELOCATIONS=3 ./test_individual_scans.sh binary 1

# Production test with enhanced multi-scan
ENHANCED_MULTI_SCAN=yes MAX_SCANS=10 MAX_VERSIONS=2 MAX_CODELOCATIONS=2 \
  USE_GCS=no ./src/hub_load/core/hub_load_main.sh
```

### 6. Black Duck UI Visibility

In Black Duck Hub, you'll see organized project structure:

```
enhanced-container_scan_small-12345-on-03112025-143052/
├── v1-20251103-143052/
│   ├── local-container-cl-1-23456-03112025
│   ├── local-container-cl-2-34567-03112025
│   └── local-container-cl-3-45678-03112025
└── v2-20251103-143053/
    ├── local-container-cl-1-56789-03112025
    ├── local-container-cl-2-67890-03112025
    └── local-container-cl-3-78901-03112025
```

### 7. Backward Compatibility

All changes are fully backward compatible:
- Default values (`MAX_VERSIONS=1`, `MAX_CODELOCATIONS=1`) maintain original behavior
- Existing environment variables unchanged
- No breaking changes to existing functionality
- Directory structure compatible (cl-1 instead of Codelocation)

For complete details, see `COMPLETE_MODULAR_UPDATES.md`.

### 8. Snippet Scan File Extraction Fix (Nov 5, 2025)

**Problem**: Snippet scans were failing because tar.gz files were being symlinked to the scan directory instead of being extracted. Black Duck Detect's signature scanner with snippet matching requires the actual source code, not archived files.

**Symptoms**:
```
❌ Command failed with exit code 1 at line 373
--detect.source.path='/tmp/scan_.../cl-1/source'  # contained symlink to .tar.gz
```

**Solution**: Modified `scan_manager.sh` (lines 234-302) to detect snippet scans and extract tar.gz files instead of creating symlinks:

```bash
# Check if this is a snippet scan
if [ "${snippets}" == "yes" ] || [[ "$scan_type_size" == *"SNIPPET"* ]]; then
    # Extract tar.gz to scan directory
    tar -xzf "$source_file" -C "$scan_dir"
    # Log as "(extracted)" for clarity
fi
```

**Benefits**:
- ✅ Snippet scans now properly extract source code from tar.gz archives
- ✅ Signature scanner can perform snippet matching on actual source files
- ✅ Log output clearly shows "(extracted)" status for snippet archives
- ✅ Backward compatible - non-snippet scans still use symlinks for performance

**Testing**:
```bash
source src/hub_load/config/debug_snippet_scan.sh
export USE_GCS=no MAX_SCANS=1
./src/hub_load/core/hub_load_main.sh

# Output shows:
# Files: SCASS_SCA_SNIPPETS_996.ICU.tar.gz (extracted)
# Source directory contains extracted source files, not tar.gz
```

See `src/hub_load/core/lib/scan_manager.sh:234-302` for implementation details.

### 9. Summary Counting Fix for .meta Files (Nov 5, 2025)

**Problem**: The scan summary was showing 0 scans for all types even when scans were running, because the counting logic was looking for `.log` files which don't exist until scans complete.

**Root Cause**: In `scan_manager.sh:1003` and `1136`, the summary logic was iterating over:
```bash
for log_file in "$log_dir"/${RUN_SESSION_ID}__*.log; do
```

But `.log` files are only created after scans complete. For running or failed scans, only `.meta` files exist (created at scan start).

**Solution**: Changed the summary logic to iterate over `.meta` files instead (lines 1005, 1136):

```bash
for metadata_file in "$log_dir"/${RUN_SESSION_ID}__*.meta; do
    # Extract scan type from metadata
    scan_type_size=$(grep "^SCAN_TYPE_SIZE=" "$metadata_file" | cut -d'=' -f2)

    # Build result from metadata if log doesn't exist
    if [ ! -f "$log_file" ]; then
        # Extract from metadata: PROJECT_NAME, VERSION_NAME, SCAN_TYPE_SIZE, etc.
    fi
done
```

**Benefits**:
- ✅ Summary now shows running scans, not just completed ones
- ✅ Works on macOS, Linux, and all platforms
- ✅ Scan counts are accurate from scan start, not scan completion
- ✅ Failed scans are also counted (previously invisible)

**Testing**:
```bash
# With 4 snippet scans from session 20251105-112122-24631
RUN_SESSION_ID="20251105-112122-24631" print_scan_statistics

# Output now shows:
# • SNIPPET_SCAN: 4 scans (was 0 before fix)
# • TOTAL: 4 scans (was 0 before fix)
```

See `src/hub_load/core/lib/scan_manager.sh:1001-1060` (count logic) and `1135-1156` (detailed results).

### 10. Summary Reporting and Instance Isolation Fixes (Nov 5, 2025)

Critical fixes to summary reporting and support for running multiple concurrent test instances:

#### Run Session ID Tracking

**Problem**: Log directories accumulated files from multiple test runs, causing summaries to count ALL historical logs instead of just the current run (e.g., reporting 1247 scans when only 480 were run).

**Solution**: Added `RUN_SESSION_ID` to distinguish between different test runs:

```bash
# Auto-generated format: YYYYMMDD-HHMMSS-PID
export RUN_SESSION_ID="20251105-123456-789"
```

**Log File Naming**: All log files now include the session ID prefix:
```
Before: BINARY_SCAN_enhanced-binary_scan_large-10278-on-05112025-092223.log
After:  20251105-123456-789__BINARY_SCAN_enhanced-binary_scan_large-10278-on-05112025-092223.log
```

**Summary Filtering**: All summary functions now filter by `RUN_SESSION_ID` to count only current run scans:
- Scan type distribution (scan_manager.sh:957)
- Detailed results table (scan_manager.sh:1076)
- Job status summary (parallel_manager.sh:211)
- Job results extraction (parallel_manager.sh:236)

#### Instance Isolation for Concurrent Tests

**Problem**: Running multiple test instances from the same machine caused log file conflicts and mixed scan results.

**Solution**: Added `INSTANCE_ID` to provide complete isolation between concurrent test instances:

```bash
# Auto-generated format: hostname-PID
export INSTANCE_ID="perflab1-123456"

# Or set explicitly for clarity
export INSTANCE_ID="test-instance-1"
```

**Instance-Specific Directories**:
```
/tmp/hub_load_logs/
├── test-instance-1/parallel/  # Instance 1 logs
├── test-instance-2/parallel/  # Instance 2 logs
└── test-instance-3/parallel/  # Instance 3 logs
```

**Running Multiple Instances**:

Method 1 - Using helper script:
```bash
./run_multiple_tests.sh 3  # Launches 3 instances automatically
```

Method 2 - Manual launch:
```bash
INSTANCE_ID="test-1" nohup ./src/hub_load/core/hub_load_main.sh > test1.log 2>&1 &
INSTANCE_ID="test-2" nohup ./src/hub_load/core/hub_load_main.sh > test2.log 2>&1 &
INSTANCE_ID="test-3" nohup ./src/hub_load/core/hub_load_main.sh > test3.log 2>&1 &
```

Each instance maintains:
- ✅ Separate log directories (no file conflicts)
- ✅ Independent scan tracking (accurate counts per instance)
- ✅ Isolated summaries (each shows only its scans)
- ✅ Shared test data access (read-only, safe)

See `RUNNING_MULTIPLE_INSTANCES.md` for complete documentation.

#### Summary Accuracy Improvements

**Fixed Scan Type Counting** (scan_manager.sh:891-1004):
- Changed from global counters (only worked in synchronous mode) to log file-based counting
- Now accurately counts scan types in both parallel and sequential modes
- Extracts scan type from metadata files or detect command parameters

**Enhanced Metadata Extraction** (scan_manager.sh:864-917):
- Improved fallback logic when metadata files are missing
- Extracts scan type from `detect.tools='BINARY_SCAN'` parameter
- Infers size variants from filenames (`_large`, `_small`, etc.)
- Extracts files used, start times, and other metadata from log content

**Consistent File Naming** (scan_manager.sh:195-200):
- Log files and metadata files now use matching base names
- Format: `${RUN_SESSION_ID}__${scan_type}_${project_name}_${scan_id}.log`
- Corresponding metadata: `${RUN_SESSION_ID}__${scan_type}_${project_name}_${scan_id}.meta`

**Results**:
- Scan type distribution now shows accurate counts (was showing 0 for all types)
- Detailed results table displays complete metadata (was showing N/A for most fields)
- Summary totals match actual scans run (480 instead of 1247 accumulated logs)

#### Old Log File Management

**Auto-Detection**: System reports old log count at startup:
```
Found 1247 log files from previous runs (set CLEAN_OLD_LOGS=yes to auto-clean)
```

**Auto-Cleanup** (optional):
```bash
CLEAN_OLD_LOGS=yes ./src/hub_load/core/hub_load_main.sh
```

This removes all `.log` and `.meta` files from the instance log directory before starting.

#### Backward Compatibility

All changes maintain backward compatibility:
- Auto-generated IDs if not set explicitly
- Default behavior unchanged (keeps old logs)
- Works with existing Docker/Kubernetes deployments
- No breaking changes to environment variables

### 11. Automatic Cleanup of Temporary Scan Directories (Nov 6, 2025)

**Problem**: Temporary scan directories (`/tmp/scan_*`) were accumulating on disk during load tests, consuming significant disk space, especially for:
- Snippet scans with extracted tar.gz files (hundreds of MB per scan)
- Binary scans with large ISO/VMDK files (GBs per scan)
- Long-running load tests with hundreds of scans

**Symptoms**:
```bash
# Disk filling up with temp directories
/tmp/scan_scan_113_10079_20251106-034653_3769833/
  └── enhanced-binary_scan_large-18033-on-06112025-034643/
      └── cl-1/source/linuxmint-20.2-cinnamon-64bit.iso  # 2.1 GB
```

**Solution**: Added automatic cleanup of temporary directories after successful scan submission (scan_manager.sh:582-586):

```bash
# Cleanup logic added to scan command
bash <(curl -s -L https://detect.blackduck.com/detect.sh) \
  --detect.project.name='...' \
  ... [all detect parameters] ... \
  && rm -rf '/tmp/scan_scan_113_10079_20251106-034653_3769833'
```

**Key Features**:
- **Automatic**: Cleanup happens automatically after successful scan submission
- **Smart**: Uses `&&` operator - only cleans up on success, preserves files on failure for debugging
- **Configurable**: Can be disabled with `CLEANUP_TEMP_FILES=no` for debugging
- **Default enabled**: `CLEANUP_TEMP_FILES=yes` by default to prevent disk space issues
- **Cross-mode**: Works in both synchronous and parallel execution modes

**Configuration**:

```bash
# Enable cleanup (default)
CLEANUP_TEMP_FILES=yes ./src/hub_load/core/hub_load_main.sh

# Disable cleanup for debugging
CLEANUP_TEMP_FILES=no ./src/hub_load/core/hub_load_main.sh
```

**Testing**:

```bash
# Verify cleanup works
USE_GCS=no MAX_SCANS=1 API_TOKEN=your-token BD_HUB_URL=https://your-hub.com \
  ./src/hub_load/core/hub_load_main.sh

# Check that temp directories are removed
ls -la /tmp/scan_* 2>/dev/null  # Should show "No such file or directory"

# Test with cleanup disabled
CLEANUP_TEMP_FILES=no USE_GCS=no MAX_SCANS=1 \
  API_TOKEN=your-token BD_HUB_URL=https://your-hub.com \
  ./src/hub_load/core/hub_load_main.sh

# Temp directories should still exist
ls -la /tmp/scan_*  # Should show scan directories
```

**Benefits**:
- ✅ Prevents disk space exhaustion during long load tests
- ✅ Particularly important for snippet scans (extracted tar.gz files) and binary scans (large ISOs)
- ✅ Preserves files on failure for debugging
- ✅ No manual cleanup required
- ✅ Works with all scan types (SIGNATURE, BINARY, CONTAINER)
- ✅ Compatible with multiple versions/codelocations per scan

**Implementation Details**:
- Modified `generate_scan_command()` to accept `base_scan_dir` parameter (scan_manager.sh:472)
- Added cleanup logic with `&& rm -rf` at end of command (scan_manager.sh:582-586)
- Updated `execute_single_scan()` to pass `base_scan_dir` to command generator (scan_manager.sh:392)

See `src/hub_load/core/lib/scan_manager.sh:582-586` for implementation.

## Platform Compatibility

The codebase supports both macOS and Linux:
- **macOS**: Uses BSD-compatible commands, Bash 3.2 compatible
- **Linux/Ubuntu**: Optimized for container environments, requires Java 17

**Cross-platform considerations**:
- File discovery uses platform-agnostic `find` commands
- Path handling works with both NFS (macOS) and container paths
- Bash version detection switches between associative arrays (Bash 4+) and alternative tracking (Bash 3.2)

## Common Development Patterns

### Testing Changes Locally (macOS)

**Always test with the modular architecture:**

```bash
# Test your changes locally
DEBUG=yes USE_GCS=no MAX_SCANS=3 \
  API_TOKEN=your-token \
  BD_HUB_URL=https://your-hub.com \
  ./src/hub_load/core/hub_load_main.sh

# Use debug configs to isolate specific scan types
source src/hub_load/config/debug_container_scan.sh
API_TOKEN=your-token BD_HUB_URL=https://your-hub.com \
  ./src/hub_load/core/hub_load_main.sh
```

### Testing on Ubuntu/Linux

```bash
# Verify Bash compatibility
bash -n src/hub_load/core/lib/common.sh
bash -n src/hub_load/core/lib/file_manager.sh
bash -n src/hub_load/core/lib/scan_manager.sh
bash -n src/hub_load/core/hub_load_main.sh

# Run test
source src/hub_load/config/debug_mixed_scans.sh
API_TOKEN=your-token \
  BD_HUB_URL=https://your-hub.com \
  LOCAL_TEST_DATA_DIR=/path/to/SCASS \
  USE_GCS=no \
  MAX_SCANS=10 \
  ./src/hub_load/core/hub_load_main.sh
```

### Running Multiple Concurrent Test Instances

The system supports running multiple test instances in parallel from the same machine with complete isolation:

**Method 1: Using Helper Script (Recommended)**

```bash
# Run 3 instances in parallel
./run_multiple_tests.sh 3

# Custom configuration
MAX_SCANS=240 TEST_DURATION=4 ./run_multiple_tests.sh 5
```

**Method 2: Manual Launch**

```bash
# Launch 3 instances manually with unique IDs
INSTANCE_ID="test-1" nohup bash -c '
source src/hub_load/config/debug_mixed_scans.sh
export API_TOKEN="your-token"
export BD_HUB_URL="https://your-hub.com"
export MAX_PARALLEL_JOBS=4
export MAX_SCANS=480
export LOCAL_TEST_DATA_DIR="/path/to/SCASS"
export USE_GCS=no
./src/hub_load/core/hub_load_main.sh
' > test1.log 2>&1 &

INSTANCE_ID="test-2" nohup bash -c '
source src/hub_load/config/debug_mixed_scans.sh
export API_TOKEN="your-token"
export BD_HUB_URL="https://your-hub.com"
export MAX_PARALLEL_JOBS=4
export MAX_SCANS=480
export LOCAL_TEST_DATA_DIR="/path/to/SCASS"
export USE_GCS=no
./src/hub_load/core/hub_load_main.sh
' > test2.log 2>&1 &

INSTANCE_ID="test-3" nohup bash -c '
source src/hub_load/config/debug_mixed_scans.sh
export API_TOKEN="your-token"
export BD_HUB_URL="https://your-hub.com"
export MAX_PARALLEL_JOBS=4
export MAX_SCANS=480
export LOCAL_TEST_DATA_DIR="/path/to/SCASS"
export USE_GCS=no
./src/hub_load/core/hub_load_main.sh
' > test3.log 2>&1 &
```

**Monitoring Multiple Instances**:

```bash
# Check running instances
ps aux | grep hub_load_main.sh

# Monitor logs
tail -f test*.log

# Count scans per instance
for i in 1 2 3; do
  echo "Instance $i:";
  find /tmp/hub_load_logs/test-instance-$i/parallel/ -name "*.log" 2>/dev/null | wc -l
done

# Real-time progress
watch -n 5 'for i in 1 2 3; do echo "Instance $i:"; find /tmp/hub_load_logs/test-instance-$i/parallel/ -name "*.log" 2>/dev/null | wc -l; done'
```

**Benefits**:
- ✅ Complete isolation between instances
- ✅ No file conflicts or data corruption
- ✅ Independent progress tracking
- ✅ Accurate summaries per instance
- ✅ Easy migration to Docker/Kubernetes

See `RUNNING_MULTIPLE_INSTANCES.md` for detailed documentation.

### Adding a New Scan Type Size Variant

1. Add test data directory to `test-data/SCASS/` (e.g., `SCA_NON_BDIOS_BINARY_XXLARGE/`)
2. Update `config/enhanced_multi_scan_config.sh` with new variant mapping
3. Modify `core/lib/file_manager.sh`'s `get_local_directory_for_scan_type()` to handle new variant
4. Update distribution config examples in documentation
5. Test with debug config: `./test_individual_scans.sh binary 3`

### Debugging Syntax Errors

Modular architecture isolates errors to specific modules (unlike legacy submit_scans_fixed.sh):

```bash
# Syntax check individual modules
bash -n src/hub_load/core/lib/common.sh
bash -n src/hub_load/core/lib/parallel_manager.sh
bash -n src/hub_load/core/lib/scan_manager.sh
bash -n src/hub_load/core/lib/file_manager.sh
bash -n src/hub_load/core/hub_load_main.sh

# Check all modules at once
bash -n src/hub_load/core/lib/*.sh && echo "✅ All syntax checks passed"

# Test individual module functions
source src/hub_load/core/lib/common.sh
source src/hub_load/core/lib/parallel_manager.sh
init_parallel_manager

# Full debug run
DEBUG=yes ./src/hub_load/core/hub_load_main.sh --help
```

### Common Bash Pitfalls to Avoid

When modifying the code, avoid these common issues:

#### ❌ Don't Use C-Style Ternary Operators
```bash
# WRONG - Not supported in Bash
result=$(( condition ? value1 : value2 ))

# CORRECT - Use if-then-else
if [ condition ]; then
    result=value1
else
    result=value2
fi
```

#### ❌ Don't Use Unsafe Counter Increments
```bash
# WRONG - Returns exit code 1 when counter is 0
((counter++))

# CORRECT - Always returns exit code 0
counter=$((counter + 1))
```

#### ❌ Don't Hardcode Paths
```bash
# WRONG - Breaks on different platforms
LOG_DIR="/app/logs"

# CORRECT - Platform-aware detection
if [ -d "/app" ] && [ -w "/app" ]; then
    LOG_DIR="/app/logs"
else
    LOG_DIR="/tmp/hub_load_logs"
fi
```

### Variable Scoping

To prevent variable corruption (a past issue):
- Use `local` variables within functions
- Module-level variables are exported only when necessary
- Global configuration uses clear `export` statements in `config/` files

### Path Resolution Priority

The system resolves test data paths in this order:
1. `LOCAL_TEST_DATA_DIR` environment variable (highest priority)
2. NFS path: `/Users/karth/Library/CloudStorage/OneDrive-BlackDuckSoftware/Documents/Automation/blackducksoftware/hub-load/test-data`
3. Docker path: `/opt/blackduck/hub-load/test-data`
4. Relative path from `CONFIG_DIR`

When adding new path logic, maintain this priority order.

## Git Workflow

Current branch: `perflab_enhanced_multiscans`

### Creating Commits

When committing changes:
1. Check current status: `git status`
2. Review changes: `git diff`
3. Stage files: `git add <files>`
4. Commit with descriptive message following existing style

Recent commit patterns show:
- "sequence fix" - for logic/ordering fixes
- "Fixed the expected scans" - for configuration corrections
- "deterministic scan selection added" - for feature additions
- "Fixes for binary and container scans" - for bug fixes

## Recent Fixes (November 2025)

### Critical Bash Compatibility Fixes

The following issues were discovered and fixed when running on Ubuntu/Linux:

#### 1. C-Style Ternary Operators Not Supported
**Problem**: Bash doesn't support `condition ? true : false` syntax in `$(( ))` arithmetic.

**Files Fixed**:
- `src/hub_load/core/lib/file_manager.sh:414` - Component count calculation
- `src/hub_load/core/lib/file_manager.sh:389` - Minimum components check
- `src/hub_load/core/lib/common.sh:277` - Sleep time calculation

**Before**:
```bash
num_files=$(( ${FIXED_COMPONENTS:-2} > ${#files[@]} ? ${#files[@]} : ${FIXED_COMPONENTS:-2} ))
```

**After**:
```bash
local fixed_comp=${FIXED_COMPONENTS:-2}
local available=${#files[@]}
if [ "$fixed_comp" -gt "$available" ]; then
    num_files=$available
else
    num_files=$fixed_comp
fi
```

#### 2. Unsafe Counter Increments with set -e
**Problem**: `((counter++))` returns exit code 1 when counter is 0, causing script failure with `set -e`.

**Fixed 28+ instances** across:
- `src/hub_load/core/lib/scan_manager.sh` - All scan type counters and status counters

**Before**:
```bash
((SIGNATURE_SCAN_COUNT++))
((success_count++))
```

**After**:
```bash
SIGNATURE_SCAN_COUNT=$((SIGNATURE_SCAN_COUNT + 1))
success_count=$((success_count + 1))
```

#### 3. Platform-Aware Log Directory
**Fixed**: `src/hub_load/core/lib/common.sh:129`

**Before**: Hardcoded `/app/logs` for all platforms
**After**: Automatically detects platform:
- Docker/containers with `/app`: Uses `/app/logs`
- macOS/Linux without `/app`: Uses `/tmp/hub_load_logs`

#### 4. hub_load_test.sh Called Wrong Script
**Fixed**: `src/hub_load/hub_load_test.sh:27`

**Before**: Called legacy `submit_scans_fixed.sh`
**After**: Calls modular `hub_load_main.sh`

### Security Fixes

#### API Token Protection
- Created `.gitignore` to protect sensitive files
- Sanitized `src/run_scans.bash` to use environment variables instead of hardcoded tokens
- Protected `.claude/settings.local.json` from git commits

### New Files Created

#### run_load_test.sh
Wrapper script for easy test execution with proper nohup support:

```bash
# Usage
export API_TOKEN=your-token
export BD_HUB_URL=https://your-hub.com
./run_load_test.sh background  # or foreground
```

#### .gitignore
Protects sensitive files from accidental commits:
- API keys and secrets
- Log files
- Claude Code local settings
- Backup files

## Known Issues and Workarounds

### Legacy Script Issues (DO NOT USE)

`submit_scans_fixed.sh` has known issues:
- Syntax errors that cascade across 2053 lines
- Variable corruption (e.g., `MAX_PARALLEL_JOBS` gets corrupted with "ho" suffix)
- Debugging nightmares due to monolithic design
- **Solution**: Use `hub_load_main.sh` instead

**CRITICAL**: The `hub_load_test.sh` script has been fixed to call the modular version. If you still see errors, ensure you have the latest version.

### Running on Ubuntu/Linux

When deploying to Ubuntu, use the modular architecture directly:

```bash
# Direct call (recommended)
nohup bash -c '
source src/hub_load/config/debug_mixed_scans.sh
export API_TOKEN="your-token"
export BD_HUB_URL="https://your-hub.com"
export MAX_PARALLEL_JOBS=4
export MAX_SCANS=480
export TEST_DURATION=8
export LOCAL_TEST_DATA_DIR="/path/to/test-data/SCASS"
export USE_GCS=no
./src/hub_load/core/hub_load_main.sh
' > scans.log 2>&1 &
```

**Important**: Always include `/SCASS` in your `LOCAL_TEST_DATA_DIR` path.

### Log Directory Behavior

The system automatically selects the appropriate log directory:

| Environment | Log Directory | Status |
|------------|---------------|--------|
| Docker containers | `/app/logs/parallel/` | Auto-detected |
| macOS/Linux local | `/tmp/hub_load_logs/parallel/` | Auto-detected |
| Custom | `$LOG_DIR/parallel/` | Set `LOG_DIR` env var |

**Note**: You may still see harmless warnings on macOS about `/app` directory if using older versions.

### Java Configuration in Containers

The modular architecture auto-detects Java 17 installations. If Java is not found, it searches common Ubuntu/Linux paths in priority order (JDK 17 first).

### Sleep Optimization

First scan skips initial sleep interval for faster testing. This is controlled in the scan manager logic.

### Memory Mapping Performance

Memory mapping provides ~27.5% performance improvement for file access. It's enabled by default but can be disabled with `USE_MEMORY_MAPPING=no`.

### Container Scan Debugging

If container scans fail, use debug configs to isolate the issue:

```bash
# Test container scans in isolation
./test_individual_scans.sh container 1

# Check test data exists
ls -la test-data/SCASS/SCA_NON_BDIOS_CONTAINER_SM_MEDIUM/

# Full debug
source src/hub_load/config/debug_container_scan.sh
DEBUG=yes USE_GCS=no MAX_SCANS=1 ./src/hub_load/core/hub_load_main.sh
```

## Monitoring and Logging

### Log Formats

All modules use consistent emoji-prefixed logging:
- ℹ️ Info: General information
- ✅ Success: Successful operations
- ⚠️ Warning: Non-critical issues
- ❌ Error: Critical failures
- 🔍 Debug: Debug-level information (when DEBUG=yes)

### Parallel Job Tracking

When `PARALLEL_SCANS=yes`, job status is tracked in `/tmp/hub_load_jobs/` with individual log files per scan.

## Quick Troubleshooting Guide

### Scans not starting

1. Verify credentials are set:
   ```bash
   echo $BD_HUB_URL
   echo $API_TOKEN
   ```

2. Check test data exists:
   ```bash
   ls -la test-data/SCASS/
   find test-data/SCASS -type f | wc -l
   ```

3. Enable debug mode:
   ```bash
   DEBUG=yes USE_GCS=no MAX_SCANS=1 ./src/hub_load/core/hub_load_main.sh
   ```

### Wrong scan type being used

1. Check environment variables:
   ```bash
   env | grep -E 'SCAN_TYPE|MULTI_SCAN|ENHANCED'
   ```

2. Reset and try again:
   ```bash
   source src/hub_load/config/reset_env.sh
   source src/hub_load/config/debug_container_scan.sh  # or your desired config
   ```

### Files not found errors

1. Check LOCAL_TEST_DATA_DIR:
   ```bash
   echo $LOCAL_TEST_DATA_DIR
   ls -la $LOCAL_TEST_DATA_DIR/SCASS/
   ```

2. Verify path resolution in src/hub_load/core/lib/file_manager.sh:340-360

### Syntax errors in modules

Run syntax checks on individual modules:
```bash
for file in src/hub_load/core/lib/*.sh; do
  echo "Checking $file..."
  bash -n "$file" || echo "ERROR in $file"
done
```

## Deployment Checklist

When deploying to a new environment (especially Ubuntu/Linux):

1. **Verify Bash compatibility**:
   ```bash
   bash -n src/hub_load/core/lib/*.sh
   bash -n src/hub_load/core/hub_load_main.sh
   ```

2. **Check file permissions**:
   ```bash
   chmod +x src/hub_load/core/hub_load_main.sh
   chmod +x run_load_test.sh
   ```

3. **Verify test data access**:
   ```bash
   ls -la /path/to/test-data/SCASS/
   find /path/to/test-data/SCASS -type f | head -10
   ```

4. **Set environment variables**:
   ```bash
   export API_TOKEN="your-token"
   export BD_HUB_URL="https://your-hub.com"
   export LOCAL_TEST_DATA_DIR="/path/to/SCASS"
   export USE_GCS=no
   ```

5. **Run a test scan**:
   ```bash
   source src/hub_load/config/debug_binary_scan.sh
   MAX_SCANS=1 ./src/hub_load/core/hub_load_main.sh
   ```

6. **Check logs are being created**:
   ```bash
   # On Ubuntu/Linux (with auto-generated INSTANCE_ID)
   ls -la /tmp/hub_load_logs/$(hostname)-$$/parallel/

   # With explicit INSTANCE_ID
   ls -la /tmp/hub_load_logs/test-instance-1/parallel/

   # In Docker
   ls -la /app/logs/$(hostname)-$$/parallel/

   # Old location (pre-Nov 5, 2025)
   ls -la /tmp/hub_load_logs/parallel/  # Still works if INSTANCE_ID not set
   ```

## Summary Output

The system provides comprehensive reporting at two points:

### Per-Scan Output (During Execution)
For each scan submitted, the following is displayed:
- Scan type and size variant (e.g., BINARY_SCAN_SMALL)
- Project name (with timestamp and randomization)
- Version name (v1-YYYYMMDD-HHMMSS format)
- Code location name (hostname-type-cl-num-random-date format)
- Log file path
- Number of files and total size
- List of all files used

### Final Summary (After Completion)
Comprehensive table showing for ALL scans:
- Scan type and size
- Status (SUCCESS/FAILED/RUNNING)
- Project name
- Version name
- Code location name
- Start and completion times
- Files used (especially important for signature scans with multiple JARs)
- BOM URL (if scan succeeded)
- Log file path
- Overall statistics (success rate, total scans, etc.)

## Documentation References

Key documentation files:
- `README.md`: Main project documentation with usage examples
- `QUICK_START.md`: Quick start guide for common workflows
- `CLAUDE.md`: This file - comprehensive guide for Claude Code
- `src/hub_load/README.md`: Modular architecture overview
- `src/hub_load/core/MODULAR_ARCHITECTURE_SOLUTION.md`: Detailed modular design rationale
- `src/hub_load/config/README_DEBUG_CONFIGS.md`: Debug configuration documentation
- `src/hub_load/docs/MEMORY_MAPPING_README.md`: Memory mapping implementation details
- `test-data/README.md`: Test data structure and usage

Implementation and fix documentation:
- `SCAN_SUMMARY_ENHANCEMENTS.md`: Scan summary improvements
- `BINARY_SCAN_UPLOAD_FIX.md`: Binary scan fixes
- `RUNNING_MULTIPLE_INSTANCES.md`: Multi-instance deployment guide (Nov 5, 2025)
- `.gitignore`: Security protections for sensitive files

## Files Created/Modified in Latest Session (Nov 2025)

### Session 1 - Bash Compatibility and Security Fixes

**New Files**:
- `run_load_test.sh`: Wrapper script for easy execution
- `.gitignore`: Protects API keys and sensitive data

**Modified Files**:
- `src/hub_load/core/lib/common.sh`: Platform-aware LOG_DIR, Bash compatibility fixes
- `src/hub_load/core/lib/file_manager.sh`: Removed ternary operators, safe increments
- `src/hub_load/core/lib/scan_manager.sh`: Safe counter increments (28+ fixes)
- `src/hub_load/hub_load_test.sh`: Now calls modular architecture
- `src/run_scans.bash`: Sanitized API tokens

### Session 2 - Summary Reporting and Instance Isolation (Nov 5, 2025)

**New Files**:
- `run_multiple_tests.sh`: Helper script to launch multiple concurrent test instances
- `RUNNING_MULTIPLE_INSTANCES.md`: Complete guide for running multiple instances in parallel

**Modified Files**:
- `src/hub_load/core/lib/common.sh`:
  - Added `INSTANCE_ID` for multi-instance isolation (line 10-15)
  - Added `RUN_SESSION_ID` for session tracking (line 17-21)

- `src/hub_load/core/lib/parallel_manager.sh`:
  - Instance-specific log directories (line 25-36)
  - Old log file cleanup option (line 40-54)
  - Session-filtered job status summary (line 211)
  - Session-filtered results extraction (line 236)

- `src/hub_load/core/lib/scan_manager.sh`:
  - Session-prefixed log file naming (line 195-200)
  - Log file-based scan type counting (line 891-1004)
  - Enhanced metadata extraction fallbacks (line 864-917)
  - Session-filtered detailed results (line 1076)

- `CLAUDE.md`: This file - comprehensive documentation updates

### Session 3 - Snippet Scan and Summary Fixes (Nov 5, 2025)

**Modified Files**:
- `src/hub_load/core/lib/scan_manager.sh`:
  - **Snippet scan tar.gz extraction** (line 234-302): Extract archives instead of symlinking for snippet scans
  - **Summary counting fix** (line 1001-1060): Use .meta files instead of .log files for accurate counts on all platforms
  - **Detailed results fix** (line 1135-1156): Use .meta files to show running/failed scans, not just completed ones

- `src/hub_load/config/debug_mixed_scans.sh`:
  - **MAX_SCANS override fix** (line 31): Changed hardcoded `export MAX_SCANS=60` to `export MAX_SCANS=${MAX_SCANS:-60}` to allow override
  - **Active config display** (line 39-52): Shows which config (SMALL_SCAN_CONFIG or MULTI_SCAN_CONFIG) will actually be used based on threshold
  - **Clear config output**: Now displays `ACTIVE_CONFIG` and `CONFIG_VALUE` instead of misleading `MULTI_SCAN_CONFIG`
  - **FIXED_COMPONENTS export** (line 36): Added missing `export FIXED_COMPONENTS=${FIXED_COMPONENTS:-2}` to prevent integer expression errors

- `CLAUDE.md`: This file - documented snippet scan extraction fix, summary counting fix, and debug config improvements

**Benefits of debug config fix**:
- ✅ Users can override MAX_SCANS: `MAX_SCANS=20 source debug_mixed_scans.sh`
- ✅ Debug output shows correct config being used (SMALL for <50, MULTI for ≥50)
- ✅ No more confusion about which config percentages apply
- ✅ Threshold (50) is clearly displayed
- ✅ FIXED_COMPONENTS properly exported - prevents "integer expression expected" errors on Linux
