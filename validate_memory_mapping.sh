#!/bin/bash
# Memory Mapping Validation Script for hub-load

echo "🔍 MEMORY MAPPING VALIDATION TEST"
echo "================================="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Test configuration
TEST_DATA_DIR="${LOCAL_TEST_DATA_DIR:-/netapp/eng/perflab/SCA_DATA/SCASS}"
MEMORY_MAPPING_TEST="yes"
MAX_SCANS_TEST=5
LOG_DIR="/tmp/memory_mapping_test"

# Create test log directory
mkdir -p "$LOG_DIR"

echo "📊 Test Configuration:"
echo "  • Test data directory: $TEST_DATA_DIR"
echo "  • Memory mapping: $MEMORY_MAPPING_TEST"
echo "  • Test scans: $MAX_SCANS_TEST"
echo "  • Log directory: $LOG_DIR"
echo ""

# Validate test data exists
if [ ! -d "$TEST_DATA_DIR" ]; then
    echo "❌ Test data directory not found: $TEST_DATA_DIR"
    exit 1
fi

echo "✅ Test data directory found"
echo ""

# Performance comparison test
echo "🏃‍♂️ PERFORMANCE COMPARISON TEST"
echo "--------------------------------"

# Test 1: Without memory mapping (symbolic links)
echo "Test 1: Symbolic Links (current method)"
start_time=$(date +%s)

env \
  ENABLE_ENHANCED_MULTI_SCAN=yes \
  USE_MEMORY_MAPPING=no \
  MAX_SCANS=$MAX_SCANS_TEST \
  TEST_DURATION=1 \
  DRY_RUN=yes \
  LOCAL_TEST_DATA_DIR="$TEST_DATA_DIR" \
  LOG_DIR="$LOG_DIR" \
  bash ../src/hub_load/core/submit_scans_fixed.sh > "$LOG_DIR/symbolic_links_test.log" 2>&1

end_time=$(date +%s)
symbolic_duration=$((end_time - start_time))
echo "  • Duration: ${symbolic_duration}s"
echo "  • Log: $LOG_DIR/symbolic_links_test.log"

# Test 2: With memory mapping
echo ""
echo "Test 2: Memory Mapping"
start_time=$(date +%s)

env \
  ENABLE_ENHANCED_MULTI_SCAN=yes \
  USE_MEMORY_MAPPING=yes \
  MAX_SCANS=$MAX_SCANS_TEST \
  TEST_DURATION=1 \
  DRY_RUN=yes \
  LOCAL_TEST_DATA_DIR="$TEST_DATA_DIR" \
  LOG_DIR="$LOG_DIR" \
  bash ../src/hub_load/core/submit_scans_fixed.sh > "$LOG_DIR/memory_mapping_test.log" 2>&1

end_time=$(date +%s)
memory_duration=$((end_time - start_time))
echo "  • Duration: ${memory_duration}s"
echo "  • Log: $LOG_DIR/memory_mapping_test.log"

# Performance summary
echo ""
echo "📈 PERFORMANCE SUMMARY"
echo "---------------------"
echo "  • Symbolic Links: ${symbolic_duration}s"
echo "  • Memory Mapping: ${memory_duration}s"

if [ "$memory_duration" -lt "$symbolic_duration" ]; then
    improvement=$((symbolic_duration - memory_duration))
    echo "  • 🚀 Memory mapping is ${improvement}s faster"
elif [ "$memory_duration" -gt "$symbolic_duration" ]; then
    regression=$((memory_duration - symbolic_duration))
    echo "  • ⚠️  Memory mapping is ${regression}s slower"
else
    echo "  • ➡️  Performance is equivalent"
fi

# File access pattern analysis
echo ""
echo "📁 FILE ACCESS ANALYSIS"
echo "----------------------"

# Check file sizes in test data
total_files=$(find "$TEST_DATA_DIR" -type f | wc -l)
total_size=$(find "$TEST_DATA_DIR" -type f -exec stat -c%s {} + 2>/dev/null | awk '{sum+=$1} END {print sum}')
total_size_gb=$(echo "scale=2; $total_size / 1024 / 1024 / 1024" | bc -l 2>/dev/null || echo "0")

echo "  • Total files: $total_files"
echo "  • Total size: ${total_size_gb}GB"
echo "  • Average file size: $(echo "scale=2; $total_size / $total_files / 1024 / 1024" | bc -l 2>/dev/null || echo "0")MB"

# Memory usage analysis
echo ""
echo "💾 MEMORY USAGE RECOMMENDATIONS"
echo "------------------------------"

# Calculate recommended memory based on file sizes
if [ "$(echo "$total_size_gb > 10" | bc -l 2>/dev/null)" == "1" ]; then
    echo "  • ⚠️  Large dataset detected (${total_size_gb}GB)"
    echo "  • 💡 Memory mapping recommended for datasets > 10GB"
    echo "  • 🖥️  Ensure sufficient RAM (recommend 16GB+ for this dataset)"
else
    echo "  • ✅ Dataset size manageable (${total_size_gb}GB)"
    echo "  • 💡 Symbolic links may be sufficient for smaller datasets"
fi

echo ""
echo "🔗 NEXT STEPS"
echo "-------------"
echo "1. Review test logs in: $LOG_DIR"
echo "2. If memory mapping shows benefits, proceed with GCP setup"
echo "3. Consider container resource limits for production deployment"
echo ""
echo "📋 Test completed: $(date '+%Y-%m-%d %H:%M:%S')"