#!/bin/bash
# Parallel Scan Log Monitor for hub-load

LOG_DIR="${LOG_DIR:-/app/logs}"
PARALLEL_LOG_DIR="${LOG_DIR}/parallel"

echo "🔍 HUB-LOAD PARALLEL SCAN MONITOR"
echo "=================================="
echo "Log directory: $PARALLEL_LOG_DIR"
echo "Current time: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Check if parallel log directory exists
if [ ! -d "$PARALLEL_LOG_DIR" ]; then
    echo "❌ Parallel log directory not found: $PARALLEL_LOG_DIR"
    echo "💡 Make sure parallel scans are running and LOG_DIR is set correctly"
    exit 1
fi

# Function to show scan summary
show_scan_summary() {
    echo "📊 SCAN SUMMARY"
    echo "---------------"
    
    total_logs=$(ls -1 "$PARALLEL_LOG_DIR"/*.log 2>/dev/null | wc -l)
    echo "Total scan logs: $total_logs"
    
    if [ "$total_logs" -gt 0 ]; then
        echo ""
        echo "📋 Scan Types Distribution:"
        ls -1 "$PARALLEL_LOG_DIR"/*.log 2>/dev/null | grep -o '_[A-Z_]*\.log$' | sed 's/^_//;s/\.log$//' | sort | uniq -c | while read count type; do
            echo "  • $type: $count scans"
        done
        
        echo ""
        echo "🕐 Recent Scans (last 10):"
        ls -1t "$PARALLEL_LOG_DIR"/*.log 2>/dev/null | head -10 | while read log_file; do
            filename=$(basename "$log_file")
            size=$(wc -c < "$log_file" 2>/dev/null || echo "0")
            size_mb=$(echo "scale=2; $size / 1024 / 1024" | bc -l 2>/dev/null || echo "0")
            echo "  • $filename (${size_mb}MB)"
        done
    fi
}

# Function to monitor active scans
monitor_active_scans() {
    echo ""
    echo "🔄 ACTIVE SCAN MONITORING"
    echo "-------------------------"
    
    # Look for scan logs that are still being written to (modified in last 5 minutes)
    active_logs=$(find "$PARALLEL_LOG_DIR" -name "*.log" -mmin -5 2>/dev/null)
    
    if [ -n "$active_logs" ]; then
        echo "Active scans (modified in last 5 minutes):"
        echo "$active_logs" | while read log_file; do
            filename=$(basename "$log_file")
            last_modified=$(stat -c %Y "$log_file" 2>/dev/null || stat -f %m "$log_file" 2>/dev/null)
            current_time=$(date +%s)
            age=$((current_time - last_modified))
            echo "  • $filename (${age}s ago)"
            
            # Show last few lines if recent
            if [ "$age" -lt 300 ]; then
                echo "    Latest: $(tail -1 "$log_file" 2>/dev/null | cut -c1-80)..."
            fi
        done
    else
        echo "No currently active scans detected"
    fi
}

# Function to show failed scans
show_failed_scans() {
    echo ""
    echo "❌ FAILED SCAN DETECTION"
    echo "------------------------"
    
    failed_count=0
    if [ -d "$PARALLEL_LOG_DIR" ]; then
        for log_file in "$PARALLEL_LOG_DIR"/*.log; do
            [ -f "$log_file" ] || continue
            
            if grep -q "ERROR\|FAILURE\|Exception\|failed" "$log_file" 2>/dev/null; then
                if [ "$failed_count" -eq 0 ]; then
                    echo "Scans with errors detected:"
                fi
                filename=$(basename "$log_file")
                error_count=$(grep -c "ERROR\|FAILURE\|Exception" "$log_file" 2>/dev/null)
                echo "  • $filename ($error_count errors)"
                failed_count=$((failed_count + 1))
            fi
        done
    fi
    
    if [ "$failed_count" -eq 0 ]; then
        echo "✅ No failed scans detected"
    else
        echo ""
        echo "💡 To investigate failures:"
        echo "   grep -l 'ERROR\|FAILURE' $PARALLEL_LOG_DIR/*.log"
    fi
}

# Function to tail multiple logs
tail_logs() {
    echo ""
    echo "📺 LIVE LOG MONITORING"
    echo "----------------------"
    echo "Following last 3 active logs... (Ctrl+C to stop)"
    echo ""
    
    recent_logs=$(ls -1t "$PARALLEL_LOG_DIR"/*.log 2>/dev/null | head -3)
    if [ -n "$recent_logs" ]; then
        tail -f $recent_logs
    else
        echo "No log files to monitor"
    fi
}

# Main execution
case "${1:-summary}" in
    "summary"|"")
        show_scan_summary
        monitor_active_scans
        show_failed_scans
        ;;
    "active")
        monitor_active_scans
        ;;
    "failed")
        show_failed_scans
        ;;
    "tail"|"follow")
        tail_logs
        ;;
    "help")
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  summary    Show complete scan summary (default)"
        echo "  active     Show only currently active scans"
        echo "  failed     Show only failed scans"
        echo "  tail       Follow recent log files live"
        echo "  help       Show this help"
        echo ""
        echo "Environment Variables:"
        echo "  LOG_DIR    Log directory (default: /app/logs)"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac