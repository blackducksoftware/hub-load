#!/bin/bash
# Quick version check script for hub-load

echo "=== HUB-LOAD VERSION CHECK ==="
echo "Date: $(date)"
echo "Current directory: $(pwd)"
echo

# Check Git information
if [ -d ".git" ]; then
    echo "🔍 Git Repository Information:"
    echo "  • Current branch: $(git branch --show-current 2>/dev/null || echo 'Unknown')"
    echo "  • Latest commit: $(git log -1 --oneline 2>/dev/null || echo 'Unknown')"
    echo "  • Commit date: $(git log -1 --format='%cd' --date=short 2>/dev/null || echo 'Unknown')"
    echo "  • Repository status:"
    git status --porcelain 2>/dev/null | head -5 || echo "    Clean working directory"
    echo
else
    echo "⚠️  Not a git repository"
    echo
fi

# Check if script exists and get basic info
SCRIPT_PATH="src/hub_load/core/submit_scans_fixed.sh"
if [ -f "$SCRIPT_PATH" ]; then
    echo "✅ Script found: $SCRIPT_PATH"
    echo "  • File size: $(wc -c < "$SCRIPT_PATH") bytes"
    echo "  • Line count: $(wc -l < "$SCRIPT_PATH") lines"
    echo "  • Last modified: $(stat -c %y "$SCRIPT_PATH" 2>/dev/null || stat -f %Sm "$SCRIPT_PATH" 2>/dev/null || echo 'Unknown')"
    echo
    
    # Check for parallel functionality
    echo "🔍 Feature Detection:"
    if grep -q "PARALLEL_SCANS.*yes" "$SCRIPT_PATH"; then
        echo "  ✅ Parallel scan functionality: PRESENT"
    else
        echo "  ❌ Parallel scan functionality: MISSING"
    fi
    
    if grep -q "ENABLE_ENHANCED_MULTI_SCAN" "$SCRIPT_PATH"; then
        echo "  ✅ Enhanced multi-scan functionality: PRESENT"
    else
        echo "  ❌ Enhanced multi-scan functionality: MISSING"
    fi
    
    if grep -q "Docker.*environment" "$SCRIPT_PATH"; then
        echo "  ✅ Docker optimization: PRESENT"
    else
        echo "  ❌ Docker optimization: MISSING"
    fi
    
    # Check for key parallel functions
    echo
    echo "🔍 Parallel Functionality Check:"
    parallel_functions=("manage_parallel_jobs" "wait_for_parallel_slot" "execute_parallel_scan" "wait_for_all_parallel_jobs")
    for func in "${parallel_functions[@]}"; do
        if grep -q "function $func\|$func()" "$SCRIPT_PATH"; then
            echo "  ✅ $func: PRESENT"
        else
            echo "  ❌ $func: MISSING"
        fi
    done
    
else
    echo "❌ Script not found: $SCRIPT_PATH"
fi

echo
echo "=== END VERSION CHECK ==="