#!/bin/bash
#
# parallel_manager.sh - Parallel execution management
#

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Parallel job tracking
# Check if associative arrays are supported (Bash 4+)
if [ "${BASH_VERSINFO[0]}" -ge 4 ]; then
    declare -A parallel_jobs=() 2>/dev/null || true
    declare -A parallel_job_info=() 2>/dev/null || true
    ASSOC_ARRAYS_SUPPORTED=true
else
    ASSOC_ARRAYS_SUPPORTED=false
    log_warning "Associative arrays not supported in Bash ${BASH_VERSION}. Using alternative tracking method."
fi

# Initialize parallel job management
init_parallel_manager() {
    local max_jobs=${MAX_PARALLEL_JOBS:-3}
    
    log_info "Initializing parallel manager with max $max_jobs concurrent jobs"
    log_info "Instance ID: ${INSTANCE_ID}"
    log_info "Session ID: ${RUN_SESSION_ID}"

    # Create parallel logs directory with instance isolation - detect environment
    local log_dir
    if [ -n "$LOG_DIR" ]; then
        # Use explicitly set LOG_DIR with instance isolation
        log_dir="${LOG_DIR}/${INSTANCE_ID}/parallel"
    elif [ -d "/app/logs" ]; then
        # Docker environment with instance isolation
        log_dir="/app/logs/${INSTANCE_ID}/parallel"
    else
        # Local/development environment with instance isolation
        log_dir="/tmp/hub_load_logs/${INSTANCE_ID}/parallel"
    fi

    mkdir -p "$log_dir"

    # Optional: Clean old log files from previous runs of this instance
    if [ "${CLEAN_OLD_LOGS:-no}" == "yes" ]; then
        local old_log_count=$(find "$log_dir" -name "*.log" -o -name "*.meta" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$old_log_count" -gt 0 ]; then
            log_info "Cleaning $old_log_count old log files from previous runs..."
            find "$log_dir" -name "*.log" -delete 2>/dev/null || true
            find "$log_dir" -name "*.meta" -delete 2>/dev/null || true
            log_success "Old logs cleaned"
        fi
    else
        # Report old log count for user awareness
        local old_log_count=$(find "$log_dir" -name "*.log" -o -name "*.meta" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$old_log_count" -gt 0 ]; then
            log_info "Found $old_log_count log files from previous runs (set CLEAN_OLD_LOGS=yes to auto-clean)"
        fi
    fi

    export PARALLEL_LOG_DIR="$log_dir"
    export MAX_PARALLEL_JOBS="$max_jobs"

    log_info "Log directory: ${PARALLEL_LOG_DIR}"

    return 0
}

# Get count of running parallel jobs
get_running_job_count() {
    local count=0
    
    for pid in "${!parallel_jobs[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            ((count++))
        else
            # Clean up completed job
            unset parallel_jobs["$pid"]
            unset parallel_job_info["$pid"]
        fi
    done
    
    echo "$count"
}

# Wait for available parallel slot with timeout
wait_for_parallel_slot() {
    local max_jobs=${MAX_PARALLEL_JOBS:-3}
    local timeout=${1:-300}  # Default 5 minute timeout
    local start_time=$(date +%s)
    local check_interval=5
    
    while [ "$(get_running_job_count)" -ge "$max_jobs" ]; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ "$elapsed" -ge "$timeout" ]; then
            log_warning "⏱️  Timeout waiting for parallel slot after ${timeout}s"
            return 1
        fi
        
        log_debug "Waiting for parallel slot ($(get_running_job_count)/$max_jobs jobs running) - ${elapsed}s elapsed"
        sleep "$check_interval"
        cleanup_completed_jobs
    done
    
    return 0
}

# Check if parallel slot is available (non-blocking)
is_parallel_slot_available() {
    local max_jobs=${MAX_PARALLEL_JOBS:-3}
    local running_count
    
    cleanup_completed_jobs
    running_count=$(get_running_job_count)
    
    if [ "$running_count" -lt "$max_jobs" ]; then
        return 0  # Slot available
    else
        return 1  # No slot available
    fi
}

# Clean up completed jobs
cleanup_completed_jobs() {
    local completed_count=0
    
    for pid in "${!parallel_jobs[@]}"; do
        if ! kill -0 "$pid" 2>/dev/null; then
            local job_info="${parallel_job_info[$pid]}"
            log_debug "Job $pid completed: $job_info"
            
            unset parallel_jobs["$pid"]
            unset parallel_job_info["$pid"]
            ((completed_count++))
        fi
    done
    
    if [ "$completed_count" -gt 0 ]; then
        log_debug "Cleaned up $completed_count completed jobs"
    fi
}

# Start a parallel job
start_parallel_job() {
    local job_name="$1"
    local command="$2"
    local log_file="$3"
    
    if [ -z "$job_name" ] || [ -z "$command" ]; then
        log_error "start_parallel_job requires job_name and command parameters"
        return 1
    fi
    
    # Set default log file if not provided
    if [ -z "$log_file" ]; then
        log_file="${PARALLEL_LOG_DIR}/${job_name}_$(date +%s).log"
    fi
    
    # Start the job in background
    log_info "Starting parallel job: $job_name"
    log_debug "Command: $command"
    log_debug "Log file: $log_file"
    
    (
        echo "===============================================" > "$log_file"
        echo "🚀 PARALLEL JOB STARTED: $job_name" >> "$log_file"
        echo "  • Started: $(date '+%Y-%m-%d %H:%M:%S')" >> "$log_file"
        echo "  • PID: $$" >> "$log_file"
        echo "===============================================" >> "$log_file"
        
        # Execute the command
        eval "$command" >> "$log_file" 2>&1
        local exit_code=$?
        
        echo "" >> "$log_file"
        echo "===============================================" >> "$log_file"
        if [ $exit_code -eq 0 ]; then
            echo "✅ JOB COMPLETED SUCCESSFULLY: $job_name" >> "$log_file"
        else
            echo "❌ JOB FAILED: $job_name (exit code: $exit_code)" >> "$log_file"
        fi
        echo "  • Finished: $(date '+%Y-%m-%d %H:%M:%S')" >> "$log_file"
        echo "===============================================" >> "$log_file"
        
        exit $exit_code
    ) &
    
    local job_pid=$!
    
    # Track the job
    parallel_jobs["$job_pid"]="$log_file"
    parallel_job_info["$job_pid"]="$job_name"

    # Send job start confirmation to both stderr (log) and stdout (Jenkins console)
    log_success "Parallel job started: $job_name (PID: $job_pid)"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Parallel job started: $job_name (PID: $job_pid)"
    echo "$(date '+%Y-%m-%d %H:%M:%S') -    📄 Log file: $log_file"
    return 0
}

# Wait for all parallel jobs to complete
wait_for_all_jobs() {
    local total_jobs=${#parallel_jobs[@]}
    
    if [ "$total_jobs" -eq 0 ]; then
        log_info "No parallel jobs to wait for"
        return 0
    fi
    
    log_info "Waiting for $total_jobs parallel jobs to complete..."
    
    while [ "${#parallel_jobs[@]}" -gt 0 ]; do
        local running_count=$(get_running_job_count)
        log_info "Waiting for $running_count parallel jobs to complete..."
        
        sleep 10
        cleanup_completed_jobs
    done
    
    log_success "All parallel jobs completed"
    return 0
}

# Get status summary of all jobs
get_job_status_summary() {
    local total_jobs=0
    local running_jobs=0
    local completed_jobs=0
    
    # Count files in parallel log directory for total jobs started
    if [ -d "$PARALLEL_LOG_DIR" ]; then
        total_jobs=$(find "$PARALLEL_LOG_DIR" -name "*.log" -type f | wc -l)
    fi
    
    # Count currently running jobs
    running_jobs=$(get_running_job_count)
    
    # Calculate completed jobs
    completed_jobs=$((total_jobs - running_jobs))
    
    echo "Status: $completed_jobs completed, $running_jobs running, $total_jobs total"
}

# Extract results from completed job logs
extract_job_results() {
    if [ ! -d "$PARALLEL_LOG_DIR" ]; then
        log_warning "Parallel log directory not found: $PARALLEL_LOG_DIR"
        return 1
    fi
    
    local success_count=0
    local failure_count=0
    
    log_info "Extracting results from parallel job logs..."
    
    for log_file in "$PARALLEL_LOG_DIR"/*.log; do
        if [ -f "$log_file" ]; then
            if grep -q "✅ JOB COMPLETED SUCCESSFULLY" "$log_file"; then
                ((success_count++))
            elif grep -q "❌ JOB FAILED" "$log_file"; then
                ((failure_count++))
            fi
        fi
    done
    
    local total_jobs=$((success_count + failure_count))

    # Send parallel job results to stdout for pipeline processing
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 📊 Parallel job results:"
    echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Total jobs: $total_jobs"
    echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Successful: $success_count"
    echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Failed: $failure_count"

    if [ "$total_jobs" -gt 0 ]; then
        local success_rate=$(( (success_count * 100) / total_jobs ))
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Success rate: ${success_rate}%"
    fi
    
    return 0
}