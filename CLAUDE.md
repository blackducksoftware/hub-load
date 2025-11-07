# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Quick Command Reference

```bash
# Run a quick test (most common)
USE_GCS=no MAX_SCANS=1 \
  API_TOKEN=your-token BD_HUB_URL=https://your-hub.com \
  ./src/hub_load/core/hub_load_main.sh

# Test specific scan type
source src/hub_load/config/debug_container_scan.sh  # or debug_binary_scan.sh, debug_signature_scan.sh
USE_GCS=no MAX_SCANS=3 ./src/hub_load/core/hub_load_main.sh

# Production load test (480 scans over 4 hours)
INSTANCE_ID="loadtest-1" USE_GCS=no ENABLE_ENHANCED_MULTI_SCAN=yes \
  MAX_SCANS=480 TEST_DURATION_HOURS=4 PARALLEL_SCANS=yes MAX_PARALLEL_JOBS=4 \
  API_TOKEN=your-token BD_HUB_URL=https://your-hub.com \
  ./src/hub_load/core/hub_load_main.sh

# Syntax validation
bash -n src/hub_load/core/lib/*.sh && bash -n src/hub_load/core/hub_load_main.sh

# Run multiple concurrent instances
./run_multiple_tests.sh 3  # Launches 3 isolated test instances

# Reset environment
source src/hub_load/config/reset_env.sh
```

## Table of Contents

**Quick Start**: Quick Command Reference | Decision Tree | Overview
**Setup**: Architecture | Test Data Structure | Key Configuration Variables
**Development**: Development Commands | Running Tests Locally | Debug Configs
**Deployment**: Docker | Kubernetes | Multiple Instances
**Reference**: Platform Compatibility | Common Bash Pitfalls | Troubleshooting
**Documentation**: Documentation References | Key Implementation Files

---

## Decision Tree: Which Script/Config to Use?

```
Need to test/run scans?
├─ Testing single scan type in isolation?
│  └─ Use debug config: source src/hub_load/config/debug_<type>_scan.sh
│     (container, binary, signature, snippet)
│
├─ Testing mixed scan types (development)?
│  └─ Use: source src/hub_load/config/debug_mixed_scans.sh
│
├─ Production load test (single machine)?
│  └─ Use: ./src/hub_load/core/hub_load_main.sh with ENABLE_ENHANCED_MULTI_SCAN=yes
│
├─ Multiple concurrent test instances (same machine)?
│  └─ Use: ./run_multiple_tests.sh <num_instances>
│
├─ Docker/Kubernetes deployment?
│  └─ See "Docker Deployment" and "Kubernetes Deployment" sections below
│
└─ Syntax validation or debugging?
   └─ Use: bash -n src/hub_load/core/lib/*.sh

Need to reset environment variables?
└─ Use: source src/hub_load/config/reset_env.sh

Need to modify code?
├─ File discovery/selection logic? → src/hub_load/core/lib/file_manager.sh
├─ Scan execution/metadata? → src/hub_load/core/lib/scan_manager.sh
├─ Parallel execution? → src/hub_load/core/lib/parallel_manager.sh
├─ Logging/validation? → src/hub_load/core/lib/common.sh
└─ Main orchestration? → src/hub_load/core/hub_load_main.sh
```

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

## Recent Major Enhancements (November 2025)

The modular architecture has been significantly enhanced with the following key improvements:

### Multi-Version/Codelocation Support
- **Multiple Versions**: `MAX_VERSIONS` creates multiple project versions (default: 1)
- **Multiple Codelocations**: `MAX_CODELOCATIONS` creates multiple codelocations per version (default: 1)
- **Example**: `MAX_VERSIONS=2 MAX_CODELOCATIONS=3` creates 6 total scans (2×3)
- **Naming**: Timestamped identifiers prevent collisions: `enhanced-container_scan_small-12345-on-03112025-143052`

### Instance Isolation & Session Tracking
- **Instance Isolation**: `INSTANCE_ID` enables running multiple concurrent test instances without conflicts
- **Session Tracking**: `RUN_SESSION_ID` filters logs/summaries to current run only (prevents counting historical logs)
- **Auto-Generated IDs**: Both IDs auto-generate if not explicitly set (`hostname-PID` and `YYYYMMDD-HHMMSS-PID`)
- **Isolated Logs**: Each instance gets separate log directory: `/tmp/hub_load_logs/<instance-id>/parallel/`
- **Helper Script**: `./run_multiple_tests.sh 3` launches 3 isolated instances automatically

### Summary & Metadata Improvements
- **Accurate Counting**: Summaries use `.meta` files (created at scan start) instead of `.log` files (created at completion)
- **Real-Time Visibility**: Shows running/failed scans, not just completed ones
- **Cross-Platform**: Works correctly on macOS, Linux, and containers
- **Session Filtering**: All summaries filter by `RUN_SESSION_ID` to show only current run

### Automatic Cleanup & Performance
- **Temp Directory Cleanup**: `CLEANUP_TEMP_FILES=yes` (default) removes `/tmp/scan_*` dirs after successful submission
- **Disk Space Protection**: Critical for snippet scans (extracted tar.gz) and binary scans (large ISOs)
- **Smart Cleanup**: Only removes on success; preserves files on failure for debugging
- **Snippet Extraction**: Snippet scans properly extract tar.gz archives instead of symlinking (required by Detect)

### Bash Compatibility Fixes
- **C-Style Ternary**: Replaced unsupported `condition ? true : false` with if-then-else
- **Counter Increments**: Fixed `((counter++))` which fails with `set -e` when counter is 0
- **Platform Detection**: Auto-detects log directory (`/app/logs` for containers, `/tmp/hub_load_logs` for local)

See detailed documentation in:
- `RUNNING_MULTIPLE_INSTANCES.md` - Multi-instance deployment guide
- `SCAN_SUMMARY_ENHANCEMENTS.md` - Summary improvements
- `BINARY_SCAN_UPLOAD_FIX.md` - Binary scan fixes
- `METADATA_FIX_DEPLOYMENT.md` - Metadata handling

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

**Current branch**: `perflab_enhanced_multiscans`

**Commit message patterns** (follow existing style):
- "sequence fix" - Logic/ordering fixes
- "Fixed the expected scans" - Configuration corrections
- "deterministic scan selection added" - Feature additions
- "Fixes for binary and container scans" - Bug fixes

**Before committing**:
```bash
# Verify syntax
bash -n src/hub_load/core/lib/*.sh && bash -n src/hub_load/core/hub_load_main.sh

# Check for sensitive data
git diff | grep -i "token\|password\|secret"

# Standard git workflow
git status
git diff
git add <files>
git commit -m "Clear descriptive message"
```

## Known Issues and Workarounds

### CRITICAL: Use Modular Architecture Only
- **Never use** `submit_scans_fixed.sh` (legacy, 2053-line monolith with known bugs)
- **Always use** `src/hub_load/core/hub_load_main.sh` (modular, tested, maintained)
- The `hub_load_test.sh` wrapper correctly calls the modular version

### Platform-Specific Notes

**macOS (Bash 3.2)**:
- No associative arrays - uses alternative tracking
- NFS paths supported: `/Users/karth/Library/CloudStorage/...`
- Log directory: `/tmp/hub_load_logs/`

**Linux/Ubuntu (Bash 4+)**:
- Requires Java 17 (`sudo apt install openjdk-17-jdk`)
- Docker paths: `/opt/blackduck/hub-load/test-data`
- Container log directory: `/app/logs/` (auto-detected)

**Test Data Path**:
- Always include `/SCASS` suffix: `LOCAL_TEST_DATA_DIR="/path/to/SCASS"`
- System checks priority: 1) Env var, 2) NFS path, 3) Docker path, 4) Relative path

### Performance Features
- **Memory Mapping**: 27.5% faster file access (enabled by default, disable with `USE_MEMORY_MAPPING=no`)
- **Parallel Execution**: Set `PARALLEL_SCANS=yes` and `MAX_PARALLEL_JOBS=4`
- **Temp Cleanup**: Automatic cleanup enabled by default (`CLEANUP_TEMP_FILES=yes`)

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

## Key Implementation Files

**Core Modular Components** (always use these):
- `src/hub_load/core/hub_load_main.sh` - Main entry point (modular)
- `src/hub_load/core/lib/common.sh` - Logging, config, validation, instance isolation
- `src/hub_load/core/lib/scan_manager.sh` - Scan orchestration, metadata, summaries
- `src/hub_load/core/lib/file_manager.sh` - File operations, test data discovery
- `src/hub_load/core/lib/parallel_manager.sh` - Parallel execution management

**Debug Configurations** (isolate scan types for testing):
- `src/hub_load/config/debug_container_scan.sh` - 100% container scans
- `src/hub_load/config/debug_binary_scan.sh` - 100% binary scans
- `src/hub_load/config/debug_signature_scan.sh` - 100% signature scans
- `src/hub_load/config/debug_mixed_scans.sh` - Multi-type distribution
- `src/hub_load/config/reset_env.sh` - Reset all environment variables

**Helper Scripts**:
- `run_multiple_tests.sh` - Launch multiple concurrent isolated instances
- `run_load_test.sh` - Wrapper for easy execution with nohup

**Security**:
- `.gitignore` - Protects API tokens, logs, and sensitive files from commits
