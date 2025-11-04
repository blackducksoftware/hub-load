#!/bin/bash
#
# Diagnostic script to verify metadata extraction fix
#

echo "==============================================="
echo "Metadata Fix Verification Script"
echo "==============================================="
echo ""

# Check if log directory exists
if [ -d "/app/logs/parallel" ]; then
    LOG_DIR="/app/logs/parallel"
elif [ -d "/tmp/hub_load_logs/parallel" ]; then
    LOG_DIR="/tmp/hub_load_logs/parallel"
else
    echo "❌ No log directory found"
    exit 1
fi

echo "Log directory: $LOG_DIR"
echo ""

# Count log and metadata files
log_count=$(find "$LOG_DIR" -name "*.log" 2>/dev/null | wc -l)
meta_count=$(find "$LOG_DIR" -name "*.meta" 2>/dev/null | wc -l)

echo "📊 File counts:"
echo "  • Log files (.log):      $log_count"
echo "  • Metadata files (.meta): $meta_count"
echo ""

# Show sample log file names
echo "📝 Sample log file names (first 5):"
find "$LOG_DIR" -name "*.log" 2>/dev/null | head -5 | while read logfile; do
    basename "$logfile"
done
echo ""

# Show sample metadata file names
echo "📝 Sample metadata file names (first 5):"
find "$LOG_DIR" -name "*.meta" 2>/dev/null | head -5 | while read metafile; do
    basename "$metafile"
done
echo ""

# Check for matching pairs
echo "🔍 Checking for matching log/meta pairs..."
mismatches=0
matches=0

find "$LOG_DIR" -name "*.log" 2>/dev/null | head -10 | while read logfile; do
    metafile="${logfile%.log}.meta"
    logbase=$(basename "$logfile")
    metabase=$(basename "$metafile")

    if [ -f "$metafile" ]; then
        echo "  ✅ MATCH: $logbase <-> $metabase"
        ((matches++))
    else
        echo "  ❌ MISSING META: $logbase (expected: $metabase)"
        ((mismatches++))
    fi
done

echo ""
echo "==============================================="
echo "Analysis:"
echo "==============================================="

if [ "$meta_count" -eq 0 ]; then
    echo "⚠️  WARNING: No metadata files found!"
    echo "   This suggests scans were run with OLD code that doesn't"
    echo "   create metadata files."
    echo ""
    echo "Action needed:"
    echo "  1. Verify latest code is deployed on server"
    echo "  2. Clear old log files: rm -rf $LOG_DIR/*"
    echo "  3. Run a test scan to verify metadata creation"
elif [ "$log_count" -gt "$meta_count" ]; then
    diff=$((log_count - meta_count))
    echo "⚠️  WARNING: $diff log files are missing matching metadata files"
    echo "   This suggests a mix of OLD and NEW scan results."
    echo ""
    echo "Action needed:"
    echo "  1. Clear old log files: rm -rf $LOG_DIR/*"
    echo "  2. Run fresh scans with updated code"
else
    echo "✅ Log and metadata file counts match!"
    echo "   The metadata extraction should work correctly."
fi

echo ""
echo "==============================================="
