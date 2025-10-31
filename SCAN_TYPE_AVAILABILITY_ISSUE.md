# Scan Type Availability Issue

## Problem Summary

When running 10 scans, **no container scans or snippet scans were submitted**, and **binary scans reported "Binary scanner found nothing to upload"** despite files being discovered.

## Root Cause Analysis

### Issue 1: Container Scans Not Selected

**Configuration** (`enhanced_multi_scan_config.sh` line 109):
```bash
SMALL_SCAN_CONFIG="...,CONTAINER_SCAN_SMALL:10,CONTAINER_SCAN_LARGE:5"
```

**Directory Mapping** (lines 161-163):
```bash
"CONTAINER_SCAN_SMALL") echo "${base_dir}/SCA_NON_BDIOS_CONTAINER_SM_MEDIUM" ;;
"CONTAINER_SCAN_MEDIUM") echo "${base_dir}/SCA_NON_BDIOS_CONTAINER_SM_MEDIUM" ;;
"CONTAINER_SCAN_LARGE") echo "${base_dir}/SCA_NON_BDIOS_CONTAINER_LARGE" ;;
```

**File Check** (lines 295-296):
```bash
"CONTAINER_SCAN")
    file_count=$(find "$local_dir" -name "*.tar" -type f 2>/dev/null | wc -l)
```

**Actual Files**:
```
$ find /Users/karth/.../SCASS/SCA_NON_BDIOS_CONTAINER_SM_MEDIUM -name "*.tar"
(no output - NO FILES FOUND)

$ find /Users/karth/.../SCASS/SCA_NON_BDIOS_CONTAINER_LARGE -name "*.tar"
(no output - NO FILES FOUND)
```

**Result**: Container scans are **excluded from selection** because `check_scan_type_has_files()` returns false (no `.tar` files found).

**Evidence from logs**:
```
Available scan types with files: 4
Available config: BINARY_SCAN_SMALL:20,BINARY_SCAN_MEDIUM:25,SIGNATURE_SCAN_SMALL:15,SIGNATURE_SCAN_MEDIUM:15
```

Notice: **NO CONTAINER_SCAN or SNIPPET_SCAN** in available config.

---

### Issue 2: Binary Scans Not Uploading

**Files Discovered**: ✅
```
2025-10-31 17:00:49 - ✅ Initial File Discovery Results:
2025-10-31 17:00:49 - ℹ️    • Found 1 binary files
2025-10-31 17:00:49 - ✅ Prepared 1 files using symbolic links
```

**Black Duck Detect Output**: ❌
```
2025-10-31 17:01:02 MDT INFO  [main] --- Will include the Binary Scanner tool.
2025-10-31 17:01:02 MDT INFO  [main] --- Binary scanner found nothing to upload.
2025-10-31 17:01:02 MDT INFO  [main] --- Binary Scanner actions finished.
```

**Root Cause**: Black Duck's Binary Scanner requires files to be **uploaded to the binary scanner service**, not just scanned locally. The scan command being generated is:

```bash
bash <(curl -s -L https://detect.blackduck.com/detect.sh) \
  --blackduck.url='...' \
  --blackduck.api.token='...' \
  --detect.project.name='enhanced-binary_scan_small-...' \
  --detect.project.version.name='1.0' \
  --detect.tools='BINARY_SCAN'
```

This command tells Detect to run binary scanning, but **Detect expects binary files to already be uploaded** to the Black Duck binary scanner service, or it needs additional parameters to upload them.

---

## Solutions

### Solution 1: Populate Container Scan Directories

**Option A**: Copy/move existing `.tar` files to the correct directories:
```bash
# Find existing tar files
find /Users/karth/.../SCASS -name "*.tar"
# Output: .../SCA_NON_BDIOS_CONTAINER_XLARGE/SCASS_SCA_NON_BDIOS_CONTAINER_SM_MEDIUM_alpine.tar

# Copy to expected directories
cp /Users/karth/.../SCASS/SCA_NON_BDIOS_CONTAINER_XLARGE/*.tar \
   /Users/karth/.../SCASS/SCA_NON_BDIOS_CONTAINER_SM_MEDIUM/

cp /Users/karth/.../SCASS/SCA_NON_BDIOS_CONTAINER_XLARGE/*.tar \
   /Users/karth/.../SCASS/SCA_NON_BDIOS_CONTAINER_LARGE/
```

**Option B**: Update directory mapping to point to the directory with files:
```bash
# In enhanced_multi_scan_config.sh, change:
"CONTAINER_SCAN_SMALL") echo "${base_dir}/SCA_NON_BDIOS_CONTAINER_XLARGE" ;;
"CONTAINER_SCAN_MEDIUM") echo "${base_dir}/SCA_NON_BDIOS_CONTAINER_XLARGE" ;;
"CONTAINER_SCAN_LARGE") echo "${base_dir}/SCA_NON_BDIOS_CONTAINER_XLARGE" ;;
```

**Option C**: Add snippet scan files:
```bash
# Check if snippet files exist
find /Users/karth/.../SCASS/SCA_SNIPPETS -name "*.tar.gz"
```

---

### Solution 2: Fix Binary Scanner Upload

Binary scanning requires one of these approaches:

**Option A**: Upload binaries using `detect.binary.scan.file.path`:
```bash
--detect.binary.scan.file.path='/path/to/binary.exe'
```

**Option B**: Use detect.bdba.enabled for intelligent binary analysis (requires BDBA license)

**Option C**: Update scan command generation in `scan_manager.sh` (line 219-226):

**Current Code**:
```bash
BINARY_SCAN)
    base_command+="bash <(curl -s -L https://detect.blackduck.com/detect.sh)"
    base_command+=" --blackduck.url='$BD_HUB_URL'"
    base_command+=" --blackduck.api.token='$API_TOKEN'"
    base_command+=" --detect.project.name='$project_name'"
    base_command+=" --detect.project.version.name='1.0'"
    base_command+=" --detect.tools='BINARY_SCAN'"
```

**Recommended Fix** (add binary scan file specification):
```bash
BINARY_SCAN)
    # Get first binary file from scan directory
    local binary_file=$(find "$scan_dir" -type f \( -name "*.exe" -o -name "*.dmg" -o -name "*.msi" \) | head -1)

    base_command+="bash <(curl -s -L https://detect.blackduck.com/detect.sh)"
    base_command+=" --blackduck.url='$BD_HUB_URL'"
    base_command+=" --blackduck.api.token='$API_TOKEN'"
    base_command+=" --detect.project.name='$project_name'"
    base_command+=" --detect.project.version.name='1.0'"
    base_command+=" --detect.tools='BINARY_SCAN'"

    # Add binary scan file path if found
    if [ -n "$binary_file" ]; then
        base_command+=" --detect.binary.scan.file.path='$binary_file'"
    fi
```

---

## Quick Fix Commands

### 1. Add Container Files

```bash
# Navigate to SCASS directory
cd /Users/karth/Library/CloudStorage/OneDrive-BlackDuckSoftware/Documents/Automation/blackducksoftware/test-data/SCASS

# Copy tar file to expected directories
cp SCA_NON_BDIOS_CONTAINER_XLARGE/SCASS_SCA_NON_BDIOS_CONTAINER_SM_MEDIUM_alpine.tar SCA_NON_BDIOS_CONTAINER_SM_MEDIUM/
cp SCA_NON_BDIOS_CONTAINER_XLARGE/SCASS_SCA_NON_BDIOS_CONTAINER_SM_MEDIUM_alpine.tar SCA_NON_BDIOS_CONTAINER_LARGE/

# Verify
ls -la SCA_NON_BDIOS_CONTAINER_SM_MEDIUM/
ls -la SCA_NON_BDIOS_CONTAINER_LARGE/
```

### 2. Update Binary Scan Command (Code Change Required)

See Solution 2 Option C above - requires editing `src/hub_load/core/lib/scan_manager.sh`.

---

## Test After Fixes

```bash
# Test with container and binary scans
ENHANCED_MULTI_SCAN=yes \
USE_GCS=no \
MAX_SCANS=10 \
TEST_DURATION=0.1 \
PARALLEL_SCANS=yes \
MAX_PARALLEL_JOBS=4 \
LOCAL_TEST_DATA_DIR='/Users/karth/Library/CloudStorage/OneDrive-BlackDuckSoftware/Documents/Automation/blackducksoftware/test-data/SCASS' \
bash src/hub_load/core/hub_load_main.sh
```

**Expected after container files added**:
```
Available scan types with files: 6
Available config: BINARY_SCAN_SMALL:20,BINARY_SCAN_MEDIUM:25,SIGNATURE_SCAN_SMALL:15,SIGNATURE_SCAN_MEDIUM:15,CONTAINER_SCAN_SMALL:10,CONTAINER_SCAN_LARGE:5
```

**Expected scan distribution** (10 scans with all types available):
- BINARY_SCAN: ~4-5 scans (45% weight)
- SIGNATURE_SCAN: ~3 scans (30% weight)
- CONTAINER_SCAN: ~1-2 scans (15% weight)
- SNIPPET_SCAN: ~1 scan (10% weight, if files exist)

---

## Recommendations

1. **Immediate**: Copy container `.tar` files to expected directories
2. **Short-term**: Update binary scan command to include `--detect.binary.scan.file.path`
3. **Long-term**: Consider restructuring test data directories to match configuration expectations

---

**Status**: Issues identified, solutions provided
**Date**: 2025-10-31
**Priority**: HIGH (blocks proper scan type distribution testing)
