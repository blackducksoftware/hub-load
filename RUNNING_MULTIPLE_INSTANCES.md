# Running Multiple Test Instances Concurrently

This document explains how to run multiple load test instances in parallel from the same machine without conflicts.

## Overview

The hub-load system now supports running **multiple concurrent test instances** on the same machine with complete isolation:

- **Separate log directories** per instance
- **No file conflicts** between instances
- **Independent progress tracking** for each instance
- **Isolated scan results** and summaries

## How It Works

### Instance Isolation

Each test instance gets a unique `INSTANCE_ID`:

```bash
INSTANCE_ID="test-instance-1"
```

This creates separate directories:
```
/tmp/hub_load_logs/
├── test-instance-1/
│   └── parallel/
│       ├── 20251105-123456-789__BINARY_SCAN_....log
│       └── 20251105-123456-789__BINARY_SCAN_....meta
├── test-instance-2/
│   └── parallel/
│       ├── 20251105-123500-790__SIGNATURE_SCAN_....log
│       └── 20251105-123500-790__SIGNATURE_SCAN_....meta
└── test-instance-3/
    └── parallel/
        ├── 20251105-123504-791__CONTAINER_SCAN_....log
        └── 20251105-123504-791__CONTAINER_SCAN_....meta
```

### Directory Structure

**Without INSTANCE_ID** (single instance, legacy):
```
/tmp/hub_load_logs/parallel/
```

**With INSTANCE_ID** (multiple instances):
```
/tmp/hub_load_logs/${INSTANCE_ID}/parallel/
```

**In Docker**:
```
/app/logs/${INSTANCE_ID}/parallel/
```

## Quick Start: Run Multiple Instances

### Method 1: Using the Helper Script (Recommended)

```bash
# Run 3 instances in parallel
./run_multiple_tests.sh 3

# Custom configuration
MAX_SCANS=240 TEST_DURATION=4 ./run_multiple_tests.sh 5
```

The helper script:
- ✅ Automatically assigns unique INSTANCE_IDs
- ✅ Creates timestamped log directories
- ✅ Starts instances with 2-second delay
- ✅ Provides monitoring commands
- ✅ Tracks all PIDs for easy management

### Method 2: Manual Launch

Run each instance manually with unique `INSTANCE_ID`:

**Terminal 1:**
```bash
nohup bash -c '
export INSTANCE_ID="test-instance-1"
source src/hub_load/config/debug_mixed_scans.sh
export API_TOKEN="your-token"
export BD_HUB_URL="https://your-hub.com"
export MAX_PARALLEL_JOBS=4
export MAX_SCANS=480
export TEST_DURATION=8
export LOCAL_TEST_DATA_DIR="/netapp/eng/perflab/SCA_DATA/SCASS"
export USE_GCS=no
./src/hub_load/core/hub_load_main.sh
' > test1.log 2>&1 &
```

**Terminal 2:**
```bash
nohup bash -c '
export INSTANCE_ID="test-instance-2"
source src/hub_load/config/debug_mixed_scans.sh
export API_TOKEN="your-token"
export BD_HUB_URL="https://your-hub.com"
export MAX_PARALLEL_JOBS=4
export MAX_SCANS=480
export TEST_DURATION=8
export LOCAL_TEST_DATA_DIR="/netapp/eng/perflab/SCA_DATA/SCASS"
export USE_GCS=no
./src/hub_load/core/hub_load_main.sh
' > test2.log 2>&1 &
```

**Terminal 3:**
```bash
nohup bash -c '
export INSTANCE_ID="test-instance-3"
source src/hub_load/config/debug_mixed_scans.sh
export API_TOKEN="your-token"
export BD_HUB_URL="https://your-hub.com"
export MAX_PARALLEL_JOBS=4
export MAX_SCANS=480
export TEST_DURATION=8
export LOCAL_TEST_DATA_DIR="/netapp/eng/perflab/SCA_DATA/SCASS"
export USE_GCS=no
./src/hub_load/core/hub_load_main.sh
' > test3.log 2>&1 &
```

## Monitoring Multiple Instances

### Check All Running Instances

```bash
ps aux | grep hub_load_main.sh
```

### Monitor Individual Instance Logs

```bash
# Instance 1
tail -f test1.log

# Instance 2
tail -f test2.log

# Instance 3
tail -f test3.log
```

### View Instance-Specific Results

```bash
# Instance 1 scans
ls -lh /tmp/hub_load_logs/test-instance-1/parallel/

# Instance 2 scans
ls -lh /tmp/hub_load_logs/test-instance-2/parallel/

# Instance 3 scans
ls -lh /tmp/hub_load_logs/test-instance-3/parallel/
```

### Count Scans Per Instance

```bash
# Instance 1 scan count
find /tmp/hub_load_logs/test-instance-1/parallel/ -name "*.log" | wc -l

# Instance 2 scan count
find /tmp/hub_load_logs/test-instance-2/parallel/ -name "*.log" | wc -l

# Instance 3 scan count
find /tmp/hub_load_logs/test-instance-3/parallel/ -name "*.log" | wc -l
```

### Monitor Real-Time Scan Progress

```bash
# Watch all instances
watch -n 5 'for i in 1 2 3; do echo "Instance $i:"; find /tmp/hub_load_logs/test-instance-$i/parallel/ -name "*.log" 2>/dev/null | wc -l; done'
```

## Environment Variables

### Required for Multi-Instance

| Variable | Description | Example |
|----------|-------------|---------|
| `INSTANCE_ID` | Unique identifier for this instance | `test-instance-1` |

### Optional Multi-Instance Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `CLEAN_OLD_LOGS` | Clean old logs at startup | `no` |
| `LOG_DIR` | Base log directory (instance subdirs created) | `/tmp/hub_load_logs` |

### Standard Configuration

All standard environment variables still apply:
- `MAX_SCANS`, `MAX_PARALLEL_JOBS`, `TEST_DURATION`
- `API_TOKEN`, `BD_HUB_URL`
- `LOCAL_TEST_DATA_DIR`, `USE_GCS`
- See [README.md](README.md) for full list

## Expected Output

Each instance will show its instance ID in logs:

```
2025-11-05 14:30:00 - ℹ️  Initializing parallel manager with max 4 concurrent jobs (Instance: test-instance-1)
2025-11-05 14:30:00 - ℹ️  Instance log directory: /tmp/hub_load_logs/test-instance-1/parallel
```

Summaries are isolated per instance:

**Instance 1:**
```
📊 SCAN EXECUTION SUMMARY
Scan Type Distribution:
  • BINARY_SCAN: 192 scans
  • SIGNATURE_SCAN: 192 scans
  • CONTAINER_SCAN: 96 scans
  • TOTAL: 480 scans

Parallel Execution Results:
Status: 480 completed, 0 running, 480 total
```

**Instance 2:**
```
📊 SCAN EXECUTION SUMMARY
Scan Type Distribution:
  • BINARY_SCAN: 192 scans
  • SIGNATURE_SCAN: 192 scans
  • CONTAINER_SCAN: 96 scans
  • TOTAL: 480 scans

Parallel Execution Results:
Status: 480 completed, 0 running, 480 total
```

## Troubleshooting

### Instances Interfering With Each Other

**Problem:** Scans from different instances are mixing.

**Solution:** Ensure each instance has a unique `INSTANCE_ID`:
```bash
export INSTANCE_ID="unique-name-${RANDOM}"
```

### Log Directory Conflicts

**Problem:** Can't find instance logs.

**Check:**
```bash
# List all instance directories
ls -la /tmp/hub_load_logs/

# Check instance-specific logs
ls -la /tmp/hub_load_logs/${INSTANCE_ID}/parallel/
```

### Auto-Generated Instance IDs

If you don't set `INSTANCE_ID`, it auto-generates as `hostname-PID`:

```bash
# Example auto-generated IDs
perflab1-123456
perflab1-123457
perflab1-123458
```

These are unique but less descriptive. Set `INSTANCE_ID` explicitly for clarity.

### Cleaning Up After Tests

```bash
# Remove all instance logs
rm -rf /tmp/hub_load_logs/test-instance-*

# Remove specific instance
rm -rf /tmp/hub_load_logs/test-instance-1

# Clean before each run (automatic)
CLEAN_OLD_LOGS=yes INSTANCE_ID="test-instance-1" ./src/hub_load/core/hub_load_main.sh
```

## Docker Migration

When you migrate to Docker, each container naturally gets isolation:

```yaml
# docker-compose.yml
services:
  hub-load-1:
    image: hub-load:latest
    environment:
      - INSTANCE_ID=container-1
      - MAX_SCANS=480
    volumes:
      - ./logs/instance-1:/app/logs

  hub-load-2:
    image: hub-load:latest
    environment:
      - INSTANCE_ID=container-2
      - MAX_SCANS=480
    volumes:
      - ./logs/instance-2:/app/logs

  hub-load-3:
    image: hub-load:latest
    environment:
      - INSTANCE_ID=container-3
      - MAX_SCANS=480
    volumes:
      - ./logs/instance-3:/app/logs
```

The `INSTANCE_ID` system works identically in containers!

## Performance Considerations

### Resource Limits

Running multiple instances increases resource usage:

| Instances | Scans Each | Total Scans | Recommended RAM | Recommended CPUs |
|-----------|-----------|-------------|-----------------|------------------|
| 1 | 480 | 480 | 8GB | 4 cores |
| 2 | 480 | 960 | 16GB | 8 cores |
| 3 | 480 | 1440 | 24GB | 12 cores |
| 5 | 480 | 2400 | 40GB | 20 cores |

### Network Considerations

Multiple instances create more simultaneous connections to Black Duck Hub:

```
Instance 1: 4 parallel scans = 4 concurrent connections
Instance 2: 4 parallel scans = 4 concurrent connections
Instance 3: 4 parallel scans = 4 concurrent connections
Total: 12 concurrent connections to Hub
```

Ensure your Hub instance can handle the load.

### Test Data Access

All instances read from the same test data directory:
```
LOCAL_TEST_DATA_DIR="/netapp/eng/perflab/SCA_DATA/SCASS"
```

This is safe because:
- ✅ Read-only access (no writes to test data)
- ✅ Symbolic links to files (not copies)
- ✅ Each instance uses different temp directories (`/tmp/scan_${scan_id}_$$/`)

## Summary

**Benefits:**
- ✅ Run multiple load tests in parallel
- ✅ Complete isolation between instances
- ✅ Independent progress tracking
- ✅ No file conflicts or data corruption
- ✅ Easy migration to Docker

**Usage:**
```bash
# Automated (recommended)
./run_multiple_tests.sh 3

# Manual
INSTANCE_ID="test-1" ./src/hub_load/core/hub_load_main.sh &
INSTANCE_ID="test-2" ./src/hub_load/core/hub_load_main.sh &
INSTANCE_ID="test-3" ./src/hub_load/core/hub_load_main.sh &
```

**Monitor:**
```bash
tail -f test*.log
ls -lh /tmp/hub_load_logs/test-instance-*/parallel/
```

For more information, see [README.md](README.md) and [CLAUDE.md](CLAUDE.md).
