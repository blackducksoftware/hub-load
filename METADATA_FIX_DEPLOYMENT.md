# Metadata Extraction Fix - Deployment Guide

## Problem Summary

The scan summary was showing "N/A" for all metadata fields (project name, version, codelocation, files, etc.) even though scans were completing successfully. This was caused by a **log file naming mismatch** between:
- Metadata files: `scan_15_v1_cl1_170852_BINARY_SCAN_XLARGE.meta`
- Log files: `scan_15_170852_BINARY_SCAN_XLARGE.log` (WRONG - missing v1_cl1)

## Root Cause

In parallel execution mode, the log file variable was being redefined with a simpler naming scheme, causing the names to not match when `extract_scan_results()` tried to find the corresponding `.meta` file by replacing `.log` with `.meta`.

## Fix Applied

**File**: `src/hub_load/core/lib/scan_manager.sh:354-361`

**Change**: Removed the line that redefined `log_file` with job_name pattern. Now uses the detailed log file name from line 195 which matches the metadata file naming.

## Deployment Steps

### Step 1: Verify Code is Updated

SSH into your Ubuntu server and check the fix is present:

```bash
cd /path/to/hub-load

# Check scan_manager.sh has the fix
grep -A 8 "if \[ \"\${PARALLEL_SCANS}\" == \"yes\" \]; then" src/hub_load/core/lib/scan_manager.sh | head -10
```

**Expected output** (with fix):
```bash
if [ "${PARALLEL_SCANS}" == "yes" ]; then
    # Execute in parallel - use the already-defined log_file from line 195
    # This ensures metadata file and log file names match for proper extraction
    local job_name="${scan_type}_${project_name}_${scan_id}"
    # Note: log_file already defined at line 195 with detailed naming
    # ${scan_id}_v${version}_cl${codelocation_num}_${scan_timestamp}_${scan_type_size}.log

    start_parallel_job "$job_name" "$scan_command" "$log_file"
```

If you don't see this, pull the latest code:
```bash
git pull origin perflab_enhanced_multiscans
```

### Step 2: Clear Old Log Files

Old log files have the wrong naming pattern and will cause confusion:

```bash
# Backup old logs if needed
mkdir -p ~/old_scan_logs
mv /app/logs/parallel/* ~/old_scan_logs/ 2>/dev/null || mv /tmp/hub_load_logs/parallel/* ~/old_scan_logs/ 2>/dev/null

# Or just delete them
rm -rf /app/logs/parallel/*
rm -rf /tmp/hub_load_logs/parallel/*
```

### Step 3: Run Diagnostic Script

```bash
chmod +x verify_metadata_fix.sh
./verify_metadata_fix.sh
```

This will check:
- Log directory location
- Count of .log and .meta files
- Sample file names
- Whether log/meta pairs match

### Step 4: Run a Small Test

Run a small test with 5-10 scans to verify the fix:

```bash
source src/hub_load/config/debug_mixed_scans.sh

export API_TOKEN="your-token"
export BD_HUB_URL="https://your-hub.com"
export PARALLEL_SCANS=yes
export MAX_PARALLEL_JOBS=3
export MAX_SCANS=5
export USE_GCS=no
export LOCAL_TEST_DATA_DIR="/path/to/SCASS"

# Run test
./src/hub_load/core/hub_load_main.sh 2>&1 | tee test_metadata_fix.log
```

### Step 5: Verify Results

Check the final summary at the end of the log:

**Before fix (WRONG)**:
```
N/A    N/A    UNKNOWN    N/A    N/A    N/A
  Version: N/A
  Codelocation: N/A
  Files: N/A
```

**After fix (CORRECT)**:
```
BINARY_SCAN    XLARGE    SUCCESS    enhanced-binary_scan_xlarge-12345...    2025-11-04 17:08:52    2025-11-04 17:15:33
  Version: v1-20251104-170852
  Codelocation: hostname-binary-cl-1-12345-04112025
  Files: binary-file.exe (2.5GB)
  BOM URL: https://your-hub.com/api/projects/...
```

### Step 6: Inspect Actual Files

Check that log and metadata files now have matching names:

```bash
# Show recent files
ls -lht /app/logs/parallel/ | head -20
# OR
ls -lht /tmp/hub_load_logs/parallel/ | head -20
```

**Expected naming pattern**:
```
scan_1_12345_20251104-170852_v1_cl1_170852_BINARY_SCAN_XLARGE.log
scan_1_12345_20251104-170852_v1_cl1_170852_BINARY_SCAN_XLARGE.meta
scan_2_23456_20251104-171002_v1_cl1_171002_SIGNATURE_SCAN_MEDIUM.log
scan_2_23456_20251104-171002_v1_cl1_171002_SIGNATURE_SCAN_MEDIUM.meta
```

Notice:
- ✅ Both files have same base name
- ✅ Includes `_v1_cl1_` component
- ✅ Includes random number component
- ✅ Only difference is .log vs .meta extension

### Step 7: Check Metadata Content

Verify metadata files contain the expected information:

```bash
# Pick any .meta file
cat /app/logs/parallel/scan_1_*.meta
```

**Expected content**:
```
SCAN_ID=scan_1_12345_20251104-170852
PROJECT_NAME=enhanced-binary_scan_xlarge-12345-on-04112025-170852
VERSION_NAME=v1-20251104-170852
CODELOCATION_NAME=hostname-binary-cl-1-12345-04112025
SCAN_TYPE_SIZE=BINARY_SCAN_XLARGE
FILES_USED=binary-file.exe
SCAN_START_TIME=1730739532
SCAN_START_TIMESTAMP=2025-11-04 17:08:52
```

## Troubleshooting

### Issue: Still seeing N/A values

**Possible causes:**

1. **Old code still running**: Verify Step 1 again
2. **Old log files mixed with new**: Clear logs (Step 2) and re-run
3. **Metadata files not being created**: Check file permissions on log directory

```bash
# Check permissions
ls -ld /app/logs/parallel/
# Should be writable by the user running scans

# Check if metadata files exist
find /app/logs/parallel -name "*.meta" | wc -l
# Should match number of .log files
```

### Issue: Log files still have old naming pattern

Example: `scan_15_170852_BINARY_SCAN_XLARGE.log` (missing `_v1_cl1_`)

This means you're running OLD code. Verify:
```bash
# Check which script is being called
ps aux | grep hub_load

# Ensure it's calling hub_load_main.sh, NOT submit_scans_fixed.sh
```

### Issue: Metadata file exists but still shows N/A

This suggests the metadata file has a different name than expected.

```bash
# Find the log file
LOG_FILE="/app/logs/parallel/scan_1_12345_20251104-170852_v1_cl1_170852_BINARY_SCAN_XLARGE.log"

# Check what meta file extract_scan_results is looking for
EXPECTED_META="${LOG_FILE%.log}.meta"
echo "Looking for: $EXPECTED_META"

# Check if it exists
ls -l "$EXPECTED_META"

# If not found, list all .meta files to see the actual pattern
ls -l /app/logs/parallel/*.meta | head
```

## Success Criteria

✅ Log and metadata files have matching names
✅ Final summary shows complete metadata for all scans
✅ Project name, version, codelocation, files, BOM URL all populated
✅ No "N/A" values in summary (except for failed scans)

## Additional Notes

- This fix only affects **parallel execution mode** (`PARALLEL_SCANS=yes`)
- Sequential mode was not affected by this bug
- The fix maintains backward compatibility
- No changes needed to existing configuration files
