# Strict Cadence Mode for Parallel Scans

## Problem Statement

When running parallel scans with a strict cadence requirement (e.g., start a new scan every 45 seconds), the system was **waiting for parallel slots** to become available, which violated the cadence timing.

### Previous Behavior
- Scan cadence: 45 seconds (80 scans in 1 hour)
- Max parallel jobs: 4
- **Issue**: When all 4 slots were full, the system would wait up to 30 seconds for a slot
- **Result**: Cadence was not maintained - scans started late

### Example Problem
```
16:28:54 - Preparing scan 11/80
16:28:54 - No parallel slots available (4/4 running)
16:28:54 - Waiting for parallel slot (4/4 jobs running) - 0s elapsed
16:28:59 - Slot became available after 5s wait  # <-- 5 second delay
16:28:59 - Starting scan 11 (parallel slot available)
```

## Solution: Strict Cadence Mode

### Default Behavior (NEW)
**Strict cadence mode**: Skip scans immediately if no slot is available

```bash
# Default behavior - NO waiting
PARALLEL_SCANS=yes
MAX_PARALLEL_JOBS=4
# CADENCE_WAIT_FOR_SLOT is not set (defaults to 0)

./src/hub_load/core/hub_load_main.sh
```

**Output**:
```
Scan cadence configuration:
  • Target duration per scan: 45s
  • Max parallel jobs: 4
  • Cadence strategy: Start every 45s
  • Slot wait mode: STRICT (skip immediately if no slots)

16:28:54 - No parallel slots available (4/4 running)
16:28:54 - ⚠️  No slots available - skipping scan 11 immediately (strict cadence mode)
16:28:54 - ⏭️  Will attempt scan 12 at next cadence interval
```

### Flexible Mode (Optional)
Allow waiting for a limited time (useful if you want to maximize scan count):

```bash
# Wait up to 10 seconds for a slot before skipping
export CADENCE_WAIT_FOR_SLOT=10
export PARALLEL_SCANS=yes
export MAX_PARALLEL_JOBS=4

./src/hub_load/core/hub_load_main.sh
```

**Output**:
```
Scan cadence configuration:
  • Target duration per scan: 45s
  • Max parallel jobs: 4
  • Cadence strategy: Start every 45s
  • Slot wait mode: FLEXIBLE (wait up to 10s for slots)

16:28:54 - No parallel slots available (4/4 running)
16:28:54 - ⏳ Waiting up to 10s for slot (CADENCE_WAIT_FOR_SLOT=10)
16:28:59 - ✅ Slot became available after 5s wait
16:28:59 - Starting scan 11 (parallel slot available)
```

## Configuration Options

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CADENCE_WAIT_FOR_SLOT` | `0` | Max seconds to wait for a parallel slot before skipping |
| `PARALLEL_SCANS` | `no` | Enable parallel scan execution |
| `MAX_PARALLEL_JOBS` | `3` | Maximum concurrent parallel scans |
| `TARGET_DURATION` | Calculated | Seconds per scan (TEST_DURATION / MAX_SCANS) |

### Cadence Behavior Matrix

| CADENCE_WAIT_FOR_SLOT | Behavior | Use Case |
|-----------------------|----------|----------|
| `0` (default) | **Strict**: Skip immediately if no slots | Maintain exact cadence timing |
| `1-30` | **Flexible**: Wait up to N seconds for slot | Balance cadence and scan count |
| `> TARGET_DURATION` | **Blocking**: May violate cadence | Not recommended |

## Usage Examples

### Example 1: Load Testing with Strict Timing
**Goal**: Generate exactly 80 scan requests per hour, maintaining precise cadence

```bash
export BD_HUB_URL="https://your-hub.com"
export API_TOKEN="your-token"
export MAX_SCANS=80
export TEST_DURATION=1  # 1 hour
export PARALLEL_SCANS=yes
export MAX_PARALLEL_JOBS=4
export CADENCE_WAIT_FOR_SLOT=0  # Strict mode (default)

./src/hub_load/core/hub_load_main.sh
```

**Result**:
- Scans start every 45 seconds (3600 / 80)
- If all 4 slots are full at cadence time → skip scan
- Maintains exact timing
- Some scans may be skipped to preserve cadence

### Example 2: Maximize Scan Count with Flexible Timing
**Goal**: Submit as many scans as possible while roughly maintaining cadence

```bash
export BD_HUB_URL="https://your-hub.com"
export API_TOKEN="your-token"
export MAX_SCANS=80
export TEST_DURATION=1
export PARALLEL_SCANS=yes
export MAX_PARALLEL_JOBS=4
export CADENCE_WAIT_FOR_SLOT=15  # Wait up to 15 seconds

./src/hub_load/core/hub_load_main.sh
```

**Result**:
- Scans start every ~45 seconds
- If slots are full → wait up to 15 seconds
- Fewer skipped scans
- Slight cadence variance (±15 seconds)

### Example 3: High-Throughput Load Testing
**Goal**: Maximum parallel utilization with fast cadence

```bash
export MAX_SCANS=200
export TEST_DURATION=1
export PARALLEL_SCANS=yes
export MAX_PARALLEL_JOBS=10  # More parallel capacity
export CADENCE_WAIT_FOR_SLOT=0  # Strict mode

./src/hub_load/core/hub_load_main.sh
```

**Result**:
- Scans start every 18 seconds (3600 / 200)
- 10 parallel slots reduce likelihood of skipping
- Fast scan submission rate
- Strict timing maintained

## Monitoring and Statistics

### Scan Completion Summary
At the end of execution:

```
Scan batch completed: 72 scans started, 8 skipped due to slot availability
💡 Consider increasing MAX_PARALLEL_JOBS or TARGET_DURATION to reduce skipped scans
```

### Interpreting Results

**If many scans are skipped:**
1. **Increase MAX_PARALLEL_JOBS**: More concurrent slots reduce contention
2. **Increase TEST_DURATION**: Longer cadence intervals give more time
3. **Set CADENCE_WAIT_FOR_SLOT**: Allow some waiting (e.g., 10-20s)

**If no scans are skipped:**
- System is keeping up with cadence
- Consider increasing MAX_SCANS or decreasing TEST_DURATION for more load

## Technical Implementation

### Code Location
`src/hub_load/core/lib/scan_manager.sh` - `run_scan_batch()` function

### Logic Flow
```
For each scan iteration:
  1. Wait for cadence timer (TARGET_DURATION since last scan)
  2. Check if parallel slot is available
  3. If slot available:
     → Start scan immediately
  4. If no slot available:
     → Check CADENCE_WAIT_FOR_SLOT setting
     → If CADENCE_WAIT_FOR_SLOT = 0:
        → Skip scan immediately (strict mode)
     → If CADENCE_WAIT_FOR_SLOT > 0:
        → Wait up to N seconds for slot
        → If slot becomes available: start scan
        → If timeout: skip scan
  5. Update last_scan_start_time for next cadence
  6. Continue to next scan
```

### Key Variables
```bash
# Cadence timing
last_scan_start_time   # Timestamp of last scan start
TARGET_DURATION        # Seconds between scan starts
expected_start_time    # When next scan should start

# Slot management
CADENCE_WAIT_FOR_SLOT  # Max wait time for slots (0 = skip immediately)
skipped_scans          # Counter for skipped scans
```

## Best Practices

### 1. Start with Strict Mode
Begin with `CADENCE_WAIT_FOR_SLOT=0` to understand true system capacity:
```bash
export CADENCE_WAIT_FOR_SLOT=0
```

### 2. Tune Based on Results
If you see:
- **>20% skipped scans**: Increase `MAX_PARALLEL_JOBS` or use flexible mode
- **<5% skipped scans**: System is well-tuned, consider increasing load
- **0% skipped scans**: You can push harder (more scans or faster cadence)

### 3. Calculate Optimal Parallel Jobs
```bash
# Rule of thumb:
# MAX_PARALLEL_JOBS ≥ (Average_Scan_Duration / TARGET_DURATION) + 1

# Example:
# If scans take ~2 minutes (120s) on average
# And TARGET_DURATION = 45s
# Then: MAX_PARALLEL_JOBS ≥ (120 / 45) + 1 = 3.67 ≈ 4
```

### 4. Use Flexible Mode for Critical Load Tests
If every scan matters (e.g., performance test with specific scan count):
```bash
# Allow reasonable wait time
export CADENCE_WAIT_FOR_SLOT=$((TARGET_DURATION / 3))
```

## Comparison: Old vs New Behavior

### OLD Behavior (Pre-Fix)
```
- CADENCE_WAIT_FOR_SLOT: Not configurable (hardcoded 30s)
- Always waited up to 30 seconds for slots
- Violated cadence timing regularly
- Unpredictable scan start times
```

### NEW Behavior (Post-Fix)
```
- CADENCE_WAIT_FOR_SLOT: Configurable (default 0)
- Default: Skip immediately if no slots (strict mode)
- Optional: Wait configurable time (flexible mode)
- Maintains cadence timing precisely
- Predictable scan start times
```

## Troubleshooting

### Problem: Too many skipped scans
**Symptoms**:
```
Scan batch completed: 50 scans started, 30 skipped due to slot availability
```

**Solutions**:
1. Increase parallel capacity:
   ```bash
   export MAX_PARALLEL_JOBS=8  # Was 4
   ```

2. Use flexible mode:
   ```bash
   export CADENCE_WAIT_FOR_SLOT=20
   ```

3. Reduce scan rate:
   ```bash
   export MAX_SCANS=60  # Was 80 (slower cadence)
   ```

### Problem: Scans still waiting despite strict mode
**Check**:
1. Verify CADENCE_WAIT_FOR_SLOT is set to 0:
   ```bash
   echo $CADENCE_WAIT_FOR_SLOT  # Should be empty or 0
   ```

2. Check logs for confirmation:
   ```
   Slot wait mode: STRICT (skip immediately if no slots)
   ```

### Problem: Not enough load on system
**Symptoms**:
- 0% skipped scans
- Low resource utilization

**Solutions**:
1. Increase scan count:
   ```bash
   export MAX_SCANS=150  # Was 80
   ```

2. Increase parallel jobs:
   ```bash
   export MAX_PARALLEL_JOBS=10  # Was 4
   ```

## Conclusion

**Strict cadence mode** (default) ensures that your load testing maintains precise timing, which is critical for:
- Performance testing with specific request rates
- Capacity planning with predictable load patterns
- SLA validation with time-based requirements

**Flexible mode** (`CADENCE_WAIT_FOR_SLOT > 0`) allows you to maximize scan submission while accepting some timing variance, useful for:
- Maximizing test coverage
- Systems where exact timing is less critical
- Balancing throughput and cadence

Choose the mode that best fits your testing requirements! 🎯
