# Sequential-With-Overflow Execution Mode

## Overview

The **Sequential-with-Overflow** mode is a hybrid execution strategy that combines the simplicity of sequential execution with the efficiency of parallel overflow processing. This mode ensures:

1. ✅ **Primary Sequential Execution** - One scan runs in the foreground at a time
2. ✅ **No Skipping** - Every scan executes, guaranteed
3. ✅ **Overflow Parallelization** - Background slots used only when needed to maintain cadence

## How It Works

### Core Principle

**Run scans one at a time (sequential), but when a long-running scan would block the next cadence interval, move it to a background overflow slot to keep the main thread free.**

### Execution Flow

```
Time: 0s
┌──────────────────────────────────────────────┐
│ Scan 1 starts (foreground/sequential)       │
│ ▶️ Running...                                │
└──────────────────────────────────────────────┘

Time: 36s (cadence interval)
┌──────────────────────────────────────────────┐
│ Scan 1 still running (takes 60s total)      │
│ 🔀 Move to overflow slot #1                 │
│ Scan 2 starts (foreground/sequential)       │
│ ▶️ Running...                                │
└──────────────────────────────────────────────┘

Time: 60s
┌──────────────────────────────────────────────┐
│ Scan 1 completes in background ✅            │
│ Scan 2 still running                         │
│ 🔀 Already in overflow, stays there         │
│ Scan 3 starts (foreground/sequential)       │
│ ▶️ Running...                                │
└──────────────────────────────────────────────┘

Time: 72s
┌──────────────────────────────────────────────┐
│ Scan 2 completes in background ✅            │
│ Scan 3 completes in foreground ✅            │
│ Scan 4 starts (foreground/sequential)       │
│ ▶️ Running...                                │
└──────────────────────────────────────────────┘
```

### Decision Logic

For each scan, the system decides:

```
IF there are NO background scans running:
    → Run in FOREGROUND (sequential)
    → Wait for completion before next scan

ELSE IF there ARE background scans running:
    → Run in BACKGROUND (overflow)
    → Continue immediately to next scan

IF all overflow slots are full:
    → WAIT for a slot to free up (no skipping!)
    → Then run in foreground
```

## Configuration

### Enable Sequential-with-Overflow Mode

```bash
export PARALLEL_SCANS=yes
export MAX_PARALLEL_JOBS=3  # Maximum overflow slots
```

### Key Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `PARALLEL_SCANS` | `no` | Set to `yes` to enable overflow mode |
| `MAX_PARALLEL_JOBS` | `3` | Maximum overflow slots (background scans) |
| `TARGET_DURATION` | Calculated | Cadence interval (TEST_DURATION / MAX_SCANS) |
| `TEST_DURATION` | `1` | Total test duration in hours |
| `MAX_SCANS` | `3` | Total number of scans to execute |

## Example Scenarios

### Scenario 1: All Scans Complete Quickly

**Config**: MAX_SCANS=10, TARGET_DURATION=36s, scan duration ~20s

```
00:00 - Scan 1 starts (foreground)
00:20 - Scan 1 completes ✅
00:36 - Scan 2 starts (foreground) - cadence wait 16s
00:56 - Scan 2 completes ✅
01:12 - Scan 3 starts (foreground) - cadence wait 16s
...
```

**Result**:
- All scans run sequentially (foreground)
- No overflow slots used
- Cadence maintained
- 0 scans in background

### Scenario 2: Some Long-Running Scans

**Config**: MAX_SCANS=10, TARGET_DURATION=36s, scan duration ~60s (longer than cadence)

```
00:00 - Scan 1 starts (foreground)
00:36 - Scan 1 still running → move to overflow slot #1
00:36 - Scan 2 starts (foreground)
01:00 - Scan 1 completes ✅ (in overflow)
01:12 - Scan 2 still running → already in overflow, stays there
01:12 - Scan 3 starts (foreground)
01:36 - Scan 2 completes ✅ (in overflow)
01:48 - Scan 3 still running → move to overflow slot #2
01:48 - Scan 4 starts (foreground)
...
```

**Result**:
- Mix of foreground and overflow execution
- Cadence maintained (scans start every 36s)
- All scans execute (0 skipped)
- Overflow slots used efficiently

### Scenario 3: All Overflow Slots Full

**Config**: MAX_SCANS=10, TARGET_DURATION=36s, MAX_PARALLEL_JOBS=3, scan duration ~120s

```
00:00 - Scan 1 starts (foreground)
00:36 - Scan 1 → overflow slot #1, Scan 2 starts (foreground)
01:12 - Scan 2 → overflow slot #2, Scan 3 starts (foreground)
01:48 - Scan 3 → overflow slot #3, Scan 4 starts (foreground)
02:00 - Scan 1 completes ✅ (frees slot #1)
02:24 - Scan 4 → overflow slot #1, Scan 5 starts (foreground)
02:36 - Scan 2 completes ✅ (frees slot #2)
03:00 - Scan 5 → overflow slot #2, Scan 6 starts (foreground)
...
```

**Result**:
- All 3 overflow slots utilized
- When full, system waits for completion (no skipping)
- All scans execute
- Cadence maintained as closely as possible

## Benefits

### 1. Guaranteed Execution
- ✅ **No scans skipped** - every scan executes
- ✅ **Predictable count** - MAX_SCANS always honored
- ✅ **Complete coverage** - all test scenarios run

### 2. Efficient Resource Usage
- ✅ **Minimal parallelism** - most scans run sequentially
- ✅ **Overflow only when needed** - background slots used efficiently
- ✅ **Resource friendly** - lower system load than full parallel mode

### 3. Cadence Maintenance
- ✅ **Consistent intervals** - scans attempt to start every TARGET_DURATION
- ✅ **No blocking** - long scans don't stop the main flow
- ✅ **Predictable load** - steady request rate to Black Duck Hub

### 4. Simple Mental Model
- ✅ **Easy to understand** - "sequential unless it would block"
- ✅ **Predictable behavior** - one main scan at a time
- ✅ **Clear logging** - indicates foreground vs. overflow

## Comparison with Other Modes

### Pure Sequential (PARALLEL_SCANS=no)

**Behavior**:
- Scans run one at a time
- Each scan must complete before next starts
- Cadence may drift if scans take longer than TARGET_DURATION

**Use Case**: Simple, predictable, low-resource testing

### Full Parallel (Old Behavior)

**Behavior**:
- Multiple scans run simultaneously
- Scans may be skipped if no slots available
- Complex concurrency management

**Use Case**: High-throughput load testing with acceptable skip rate

### Sequential-with-Overflow (New - Recommended)

**Behavior**:
- One foreground scan at a time
- Overflow slots used when needed
- No scans skipped

**Use Case**: Balanced approach - sequential simplicity with overflow efficiency

| Feature | Pure Sequential | Full Parallel | Sequential-with-Overflow |
|---------|----------------|---------------|--------------------------|
| **Primary Mode** | Sequential | Parallel | Sequential |
| **Overflow** | No | N/A | Yes (when needed) |
| **Skipping** | No | Yes | No |
| **Cadence** | May drift | Strict | Strict |
| **Complexity** | Low | High | Medium |
| **Resource Usage** | Low | High | Low-Medium |
| **Predictability** | High | Medium | High |

## Usage Examples

### Example 1: Standard Load Test

```bash
export BD_HUB_URL="https://your-hub.com"
export API_TOKEN="your-token"
export MAX_SCANS=80
export TEST_DURATION=1  # 1 hour
export PARALLEL_SCANS=yes
export MAX_PARALLEL_JOBS=4  # Up to 4 overflow slots

./src/hub_load/core/hub_load_main.sh
```

**Expected**:
- 80 scans over 1 hour = 45s cadence
- Most scans run sequentially
- Long scans (>45s) move to overflow
- All 80 scans execute (0 skipped)

### Example 2: High Cadence Test

```bash
export MAX_SCANS=200
export TEST_DURATION=1  # 1 hour
export PARALLEL_SCANS=yes
export MAX_PARALLEL_JOBS=10  # More overflow capacity

./src/hub_load/core/hub_load_main.sh
```

**Expected**:
- 200 scans over 1 hour = 18s cadence
- More scans will use overflow (faster cadence)
- 10 overflow slots handle concurrency
- All 200 scans execute

### Example 3: Conservative Testing

```bash
export MAX_SCANS=20
export TEST_DURATION=1
export PARALLEL_SCANS=yes
export MAX_PARALLEL_JOBS=2  # Minimal overflow

./src/hub_load/core/hub_load_main.sh
```

**Expected**:
- 20 scans over 1 hour = 180s cadence
- Very few scans will need overflow
- Mostly sequential execution
- All 20 scans execute

## Logging Output

### Scan Execution Modes

```
# Foreground (sequential):
▶️  Sequential mode: Running scan 1 in foreground
🚀 Starting scan 1 in foreground (sequential)
✅ Scan 1 completed

# Overflow (background):
🔀 Overflow mode: Running scan 2 in background (freeing main thread)
🚀 Starting scan 2 in background overflow slot
📊 Background scans running: 1

# Overflow slots full:
⏸️  All overflow slots full (3/3)
⏳ Waiting for overflow slot to free up (no skipping)
✅ Overflow slot freed - continuing
```

### Execution Plan

```
===============================================
📋 LOAD TEST EXECUTION PLAN
===============================================

Test Configuration:
  • Total Scans: 80
  • Test Duration: 3600s (1.00h)
  • Target Cadence: 45s per scan
  • Black Duck Hub: https://your-hub.com

Execution Mode:
  • Mode: SEQUENTIAL WITH OVERFLOW
  • Primary: One scan at a time (sequential)
  • Overflow: Use parallel slots when main scan blocks next cadence
  • Max overflow slots: 4
  • Cadence interval: 45s
  • Strategy: No skipping - all scans execute
```

### Completion Summary

```
✅ Scan batch completed: 80 scans executed (0 skipped)
   Sequential-with-overflow mode ensured all scans executed
```

## Troubleshooting

### Problem: Too Many Scans in Overflow

**Symptoms**:
```
📊 Background scans running: 4
📊 Background scans running: 4
📊 Background scans running: 4
```

**Causes**:
- Scan duration consistently exceeds TARGET_DURATION
- Overflow slots too small for scan rate

**Solutions**:
1. Increase overflow capacity:
   ```bash
   export MAX_PARALLEL_JOBS=8  # Was 4
   ```

2. Reduce scan rate (longer cadence):
   ```bash
   export MAX_SCANS=40  # Was 80 (doubles cadence)
   ```

3. Accept overflow usage - it's working as designed!

### Problem: Frequent "Waiting for Overflow Slot"

**Symptoms**:
```
⏸️  All overflow slots full (3/3)
⏳ Waiting for overflow slot to free up (no skipping)
```

**Causes**:
- All overflow slots constantly full
- Scans taking much longer than TARGET_DURATION

**Solutions**:
1. Increase MAX_PARALLEL_JOBS:
   ```bash
   export MAX_PARALLEL_JOBS=6  # Was 3
   ```

2. Check if scans are unexpectedly slow:
   - Review scan logs for errors
   - Check Black Duck Hub performance
   - Verify network connectivity

### Problem: All Scans Running Sequentially (No Overflow)

**Symptoms**:
- Never see "🔀 Overflow mode" messages
- All scans run in foreground

**Causes**:
- Scan duration less than TARGET_DURATION (good!)
- System keeping up with cadence

**Solution**:
- This is actually ideal behavior!
- No action needed
- System is efficient enough for sequential execution

## Technical Implementation

### Key Code Sections

**Location**: `src/hub_load/core/lib/scan_manager.sh`

**Decision Logic** (lines 332-364):
```bash
if [ "$running_count" -gt 0 ]; then
    # Already have background scans, add this one to background too
    use_overflow=true
else
    # No background scans yet - run in foreground (sequential)
    use_overflow=false
fi
```

**Foreground Execution** (lines 376-390):
```bash
# Temporarily disable parallel mode to force synchronous execution
local saved_parallel="${PARALLEL_SCANS}"
PARALLEL_SCANS="no"

execute_scan "$scan_config" "$scan_id"

# Restore parallel mode
PARALLEL_SCANS="$saved_parallel"
```

**Overflow Execution** (lines 368-374):
```bash
# Use overflow: execute in background (parallel slot)
execute_scan "$scan_config" "$scan_id"
# Continue immediately to next scan (overflow scan runs in background)
```

## Best Practices

### 1. Start with Recommended Settings

```bash
export PARALLEL_SCANS=yes
export MAX_PARALLEL_JOBS=4  # 3-5 is usually sufficient
```

### 2. Monitor Overflow Usage

Watch for these indicators:
- `📊 Background scans running: N` - shows overflow usage
- If N consistently equals MAX_PARALLEL_JOBS, consider increasing

### 3. Match Overflow to Cadence

**Rule of thumb**:
```
MAX_PARALLEL_JOBS >= (Average_Scan_Duration / TARGET_DURATION)
```

**Example**:
- Average scan: 90 seconds
- TARGET_DURATION: 45 seconds
- Recommended: MAX_PARALLEL_JOBS = 90/45 = 2

But add buffer for variability:
```bash
export MAX_PARALLEL_JOBS=4  # 2 + 2 buffer
```

### 4. Test Before Production

Run a small test to calibrate:
```bash
export MAX_SCANS=10
export TEST_DURATION=0.08  # ~5 minutes
export PARALLEL_SCANS=yes
export MAX_PARALLEL_JOBS=3

./src/hub_load/core/hub_load_main.sh
```

Observe:
- How many scans use overflow?
- Are slots frequently full?
- Adjust MAX_PARALLEL_JOBS accordingly

## Summary

**Sequential-with-Overflow** is the recommended mode for most use cases because it:

✅ **Runs scans one at a time** (simple, predictable)
✅ **Never skips scans** (guaranteed execution)
✅ **Uses overflow when needed** (efficient resource usage)
✅ **Maintains cadence** (consistent load pattern)
✅ **Works on all platforms** (macOS, Ubuntu, Linux)

**Configuration**:
```bash
export PARALLEL_SCANS=yes
export MAX_PARALLEL_JOBS=4
```

**Result**: Best of both worlds - sequential simplicity with parallel efficiency!
