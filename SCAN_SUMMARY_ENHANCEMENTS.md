# Scan Summary Enhancements

## Overview

The scan summary functionality has been significantly enhanced to provide comprehensive tracking and reporting of all scan executions, including detailed metadata about each scan and its results.

## Key Enhancements

### 1. Scan Metadata Tracking

**New Function**: `write_scan_metadata()`

Each scan now creates a metadata file (`.meta`) alongside its log file containing:
- Scan ID
- Project name
- Version name
- Codelocation name
- Scan type and size (e.g., BINARY_SCAN_MEDIUM)
- Files used for scanning (comma-separated list)
- Start time (both epoch and formatted timestamp)

**Location**: `scan_manager.sh:145-166`

### 2. Enhanced Result Extraction

**Updated Function**: `extract_scan_results()`

Now extracts comprehensive information from both metadata files and log files:
- Status (SUCCESS, FAILED, RUNNING, UNKNOWN)
- Scan ID (UUID from Black Duck)
- BOM URL
- Project name and version
- Codelocation name
- Scan type and size
- Files used
- Start time
- Completion time

**Location**: `scan_manager.sh:786-874`

### 3. Size-Specific Scan Distribution

**Updated Function**: `print_scan_statistics()`

The summary now shows a detailed breakdown by size for each scan type:

```
Scan Type Distribution:
  • SIGNATURE_SCAN: 4 scans
    ├─ SMALL:  1
    ├─ MEDIUM: 1
    ├─ LARGE:  1
    └─ XLARGE: 1
  • BINARY_SCAN: 3 scans
    ├─ SMALL:  1
    ├─ MEDIUM: 1
    └─ LARGE:  1
  • CONTAINER_SCAN: 2 scans
    ├─ SMALL:  1
    └─ MEDIUM: 1
  • SNIPPET_SCAN: 1 scans
  • TOTAL: 10 scans
```

**Location**: `scan_manager.sh:877-915`

### 4. Comprehensive Results Table

**Updated Section**: Detailed Scan Results

The results table now displays:

| Column | Description | Example |
|--------|-------------|---------|
| SCAN TYPE | Type of scan performed | SIGNATURE_SCAN, BINARY_SCAN |
| SIZE | Size category | SMALL, MEDIUM, LARGE, XLARGE |
| STATUS | Scan result | SUCCESS, FAILED, RUNNING |
| PROJECT | Project name | enhanced-signature_scan_small-12345-on-03112025-144523 |
| START TIME | When scan started | 2025-11-03 14:45:23 |
| COMPLETION TIME | When scan completed | 2025-11-03 14:46:15 |

Each row also includes sub-rows with additional details:
```
  Version: v1-20251103-144523              Codelocation: local-cl-1-28473-03112025
  Files: commons-lang3-3.12.0.jar,guava-31.1-jre.jar,jackson-core-2.14.0.jar
  BOM URL: https://hub.example.com/api/projects/xxx/versions/yyy/components
  Log: /app/logs/parallel/scan_1_12345_20251103-144523.log
```

**Location**: `scan_manager.sh:926-1007`

## Example Output

### Size-Specific Distribution
```bash
📊 SCAN EXECUTION SUMMARY
===============================================

Scan Type Distribution:
  • SIGNATURE_SCAN: 4 scans
    ├─ SMALL:  1
    ├─ MEDIUM: 1
    ├─ LARGE:  1
    └─ XLARGE: 1
  • BINARY_SCAN: 0 scans
  • CONTAINER_SCAN: 0 scans
  • SNIPPET_SCAN: 0 scans
  • TOTAL: 4 scans
```

### Detailed Results Table
```
SCAN TYPE            SIZE            STATUS     PROJECT                        START TIME          COMPLETION TIME
-------------------- --------------- ---------- ------------------------------ ------------------- -------------------
SIGNATURE_SCAN       SMALL           SUCCESS    enhanced-signature_scan_sm...  2025-11-03 14:45:23 2025-11-03 14:46:15
  Version: v1-20251103-144523                    Codelocation: local-cl-1-28473-03112025
  Files: commons-lang3-3.12.0.jar,guava-31.1-jre.jar
  BOM URL: https://hub.example.com/api/projects/xxx/versions/yyy
  Log: /app/logs/parallel/scan_1_12345_20251103-144523_SIGNATURE_SCAN_SMALL.log

SIGNATURE_SCAN       MEDIUM          SUCCESS    enhanced-signature_scan_me...  2025-11-03 14:46:20 2025-11-03 14:47:45
  Version: v1-20251103-144620                    Codelocation: local-cl-1-15632-03112025
  Files: spring-boot-2.7.5.jar,hibernate-core-5.6.12.jar
  BOM URL: https://hub.example.com/api/projects/xxx/versions/yyy
  Log: /app/logs/parallel/scan_2_23456_20251103-144620_SIGNATURE_SCAN_MEDIUM.log
```

### Status Summary
```
📊 Status Summary:
  ✅ Successful: 4
  ❌ Failed: 0
  🔄 Running: 0
```

## Benefits

1. **Complete Traceability**: Every scan execution is fully documented with metadata
2. **Size Distribution Visibility**: Easily see how scans are distributed across size categories
3. **Quick Failure Analysis**: Comprehensive table makes it easy to identify failed scans
4. **Audit Trail**: Complete record of what files were scanned and when
5. **Works for Both Modes**: Comprehensive reporting works for both sequential and parallel execution modes
6. **BOM Accessibility**: Direct links to Black Duck for easy verification

## File Locations

All metadata and log files are stored in:
- **Default**: `/app/logs/parallel/`
- **Configurable via**: `PARALLEL_LOG_DIR` or `LOG_DIR`

File naming pattern:
- Log: `scan_<number>_<random>_<timestamp>_<scan_type_size>.log`
- Metadata: `scan_<number>_<random>_<timestamp>_<scan_type_size>.meta`

Example:
- `scan_1_12345_20251103-144523_SIGNATURE_SCAN_SMALL.log`
- `scan_1_12345_20251103-144523_SIGNATURE_SCAN_SMALL.meta`

## Testing the Enhancements

### Quick Test (Single Scan)
```bash
source src/hub_load/config/debug_signature_scan.sh
BD_HUB_URL=https://your-hub.example.com \
API_TOKEN=your-token \
MAX_SCANS=1 \
./src/hub_load/core/hub_load_main.sh
```

### Full Test (Multiple Scans with Sizes)
```bash
source src/hub_load/config/debug_signature_scan.sh
BD_HUB_URL=https://your-hub.example.com \
API_TOKEN=your-token \
MAX_SCANS=4 \
./src/hub_load/core/hub_load_main.sh
```

The debug configuration will distribute scans across all sizes (SMALL, MEDIUM, LARGE, XLARGE).

## Modified Functions

| Function | File | Lines | Description |
|----------|------|-------|-------------|
| `write_scan_metadata()` | scan_manager.sh | 145-166 | NEW: Writes metadata file |
| `execute_single_scan()` | scan_manager.sh | 168-332 | UPDATED: Now captures and writes metadata |
| `extract_scan_results()` | scan_manager.sh | 786-874 | UPDATED: Reads metadata and log files |
| `print_scan_statistics()` | scan_manager.sh | 876-1011 | UPDATED: Shows size breakdown and comprehensive table |

## Backward Compatibility

- All existing functionality preserved
- Metadata files are optional (system falls back to log-only extraction)
- Works with both sequential and parallel scan modes
- No breaking changes to existing configurations
