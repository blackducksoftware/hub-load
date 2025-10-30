#!/bin/bash
#
#  Generates and submits test loads for HUB
#  Supports SIGNATURE_SCAN, BINARY_SCAN, and CONTAINER_SCAN
#

function show_usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Environment Variables:"
  echo "  SCAN_TYPE=<type>           Scan type: SIGNATURE_SCAN, BINARY_SCAN, or CONTAINER_SCAN (default: SIGNATURE_SCAN)"
  echo "  BD_HUB_URL=<url>           Black Duck Hub URL"
  echo "  API_TOKEN=<token>          API token for authentication"
  echo "  MAX_SCANS=<number>         Maximum number of scans to submit (default: 3)"
  echo "  SYNCHRONOUS_SCANS=<yes/no> Wait for scan results (default: yes)"
  echo "  DEBUG=<yes/no>             Enable debug logging (default: no)"
  echo "  USE_MEMORY_MAPPING=<yes/no> Use memory mapping for efficient file access (default: no)"
  echo "  USE_GCS=<yes/no>           Use Google Cloud Storage for test data (default: no)"
  echo "  GCS_BUCKET=<bucket>        GCS bucket name (required if USE_GCS=yes)"
  echo "  GCS_PREFIX=<prefix>        GCS prefix/folder path (optional)"
  echo "  GCS_MOUNT_POINT=<path>     Local mount point for GCS (default: /tmp/gcs-mount)"
  echo ""
  echo "Examples:"
  echo "  SCAN_TYPE=SIGNATURE_SCAN $0"
  echo "  SCAN_TYPE=BINARY_SCAN BD_HUB_URL=https://hub.example.com API_TOKEN=abc123 $0"
  echo "  SCAN_TYPE=CONTAINER_SCAN MAX_SCANS=5 $0"
  echo ""
  exit 1
}

# Check for help flag
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  show_usage
fi

function readvar() {
   echo -n "Enter value for $1 [${!1}] "
   read temp
   if [ ! -z $temp ] ; then 
     eval $1=$temp
   fi
}

function get_elapsed_time() {
  duration_line=$(cat $1 | awk '/Detect duration/ {print}')
  # echo "Duration line: $duration_line" 1>&2
  hours=$(echo $duration_line | awk '{print $9}' | sed -e "s/h//")
  # echo "Hours: $hours"  1>&2
  minutes=$(echo $duration_line | awk '{print $10}' | sed -e "s/m//")
  # echo "Minutes: $minutes"  1>&2
  seconds=$(echo $duration_line | awk '{print $11}' | sed -e "s/s//")
  # echo "Seconds: $seconds"  1>&2

  total_elapsed_seconds=$((10#$hours * 3600 + 10#$minutes * 60 + 10#$seconds))
  # echo "total elapsed time (seconds): $total_elapsed_seconds" 1>&2

  # the total elapsed time is written to stdout so you can use this as input to something else
  # that reads from stdout
  #
  echo $total_elapsed_seconds  
}

function cleanup_gcs() {
  if [ "${USE_GCS}" == "yes" ] && mount | grep -q "$GCS_MOUNT_POINT"; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Unmounting GCS bucket from $GCS_MOUNT_POINT"
    fusermount -u "$GCS_MOUNT_POINT" 2>/dev/null || umount "$GCS_MOUNT_POINT" 2>/dev/null
    
    if [ $? -eq 0 ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Successfully unmounted GCS bucket"
    else
      echo "WARNING: Failed to unmount GCS bucket from $GCS_MOUNT_POINT"
    fi
  fi
}

# Set woring directory
#
WORKDIR=$(dirname $0)
cd $WORKDIR

# Load multi-scan configuration if enabled
if [ "${ENABLE_MULTI_SCAN}" == "yes" ]; then
  # Use CONFIG_DIR if available (from modular setup), otherwise use relative path from current directory
  CONFIG_PATH="${CONFIG_DIR:-../config}"
  if [ "${ENABLE_ENHANCED_MULTI_SCAN}" == "yes" ] && [ -f "$CONFIG_PATH/enhanced_multi_scan_config.sh" ]; then
    source "$CONFIG_PATH/enhanced_multi_scan_config.sh"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Enhanced multi-scan configuration loaded from $CONFIG_PATH"
  elif [ -f "$CONFIG_PATH/multi_scan_config.sh" ]; then
    source "$CONFIG_PATH/multi_scan_config.sh"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Multi-scan configuration loaded from $CONFIG_PATH"
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: Multi-scan configuration file not found at $CONFIG_PATH"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Looking for: enhanced_multi_scan_config.sh or multi_scan_config.sh"
    ls -la "$CONFIG_PATH/" 2>/dev/null || echo "$(date '+%Y-%m-%d %H:%M:%S') - Config directory does not exist: $CONFIG_PATH"
  fi
fi

#
# Defaults
#
BD_HUB_URL=${BD_HUB_URL:-https://rg-250sph-2025-7-1.saas-staging.blackduck.com/}
API_TOKEN=${API_TOKEN:-NTE2MmI0OTktZWYzYS00MDM0LWI2ZTQtNWRlMDg3ZjNmNjUyOjBjNTk4NzU1LTE3MjUtNDVhYi1hM2E5LTU3NDU0NzNmNjU5YQ==}
API_TIMEOUT=${API_TIMEOUT:-300}
MAX_SCANS=${MAX_SCANS:-3}
MAX_CODELOCATIONS=${MAX_CODELOCATIONS:-1}
MAX_COMPONENTS=${MAX_COMPONENTS:-400}
MIN_COMPONENTS=${MIN_COMPONENTS:-200}
FIXED_COMPONENTS=${FIXED_COMPONENTS:-2}
MAX_VERSIONS=${MAX_VERSIONS:-1}
SYNCHRONOUS_SCANS=${SYNCHRONOUS_SCANS:-no}
REPEAT_SCAN=${REPEAT_SCAN:-no}
RANDOM_SCANS=${RANDOM_SCANS:-no}
DETECT_VERSION=${DETECT_VERSION}
FAIL_ON_SEVERITIES=${FAIL_ON_SEVERITIES}
INSECURE_CURL=${INSECURE_CURL:-no}
STRING_SEARCH=${STRING_SEARCH:-no}
DEBUG=${DEBUG:-no}
DRY_RUN=${DRY_RUN:-no}
SCAN_TYPE=${SCAN_TYPE:-SIGNATURE_SCAN}
SNIPPETS=${SNIPPETS:-no}
WAIT_TIME=${WAIT_TIME:-30}
USE_MEMORY_MAPPING=${USE_MEMORY_MAPPING:-no}
USE_GCS=${USE_GCS:-no}
GCS_BUCKET=${GCS_BUCKET:-performance_test_bdios}
GCS_PREFIX=${GCS_PREFIX:-SCASS/SCA_NON_BDIOS_BINARY_SM_MEDIUM/}
# Force LOCAL_TEST_DATA_DIR to use the correct path for local testing
if [ "${USE_GCS}" != "yes" ]; then
  LOCAL_TEST_DATA_DIR="../../../test-data"
else
  LOCAL_TEST_DATA_DIR=${LOCAL_TEST_DATA_DIR:-"${WORKDIR}/../../../test-data"}
fi
GCS_MOUNT_POINT=${GCS_MOUNT_POINT:-/tmp/gcs-mount}
GCS_CACHE_SIZE=${GCS_CACHE_SIZE:-10G}
# Multi-scan configuration
ENABLE_MULTI_SCAN=${ENABLE_MULTI_SCAN:-no}
ENABLE_ENHANCED_MULTI_SCAN=${ENABLE_ENHANCED_MULTI_SCAN:-no}
MULTI_SCAN_CONFIG=${MULTI_SCAN_CONFIG:-"BINARY_SCAN:40,SIGNATURE_SCAN:35,CONTAINER_SCAN:25"}
MULTI_GCS_CONFIG=${MULTI_GCS_CONFIG:-"performance_test_bdios/SCASS/SCA_NON_BDIOS_BINARY_SM_MEDIUM:40,performance_test_bdios/SCASS/SCA_SIGNATURE_LARGE:35,performance_test_bdios/SCASS/SCA_CONTAINER_MIXED:25"}
TEST_DURATION=${TEST_DURATION:-1}
TARGET_DURATION=0

#max scans * test duration is decided based on the number of scans a container has to be submit
MAX_SCANS=$((MAX_SCANS * TEST_DURATION))


if [ -z "$TEST_DURATION" ]; then
  echo "Scans will be submitted as fast it can, continuing."
  exit 1
else
#target rate / Scan
TARGET_DURATION=$(((TEST_DURATION * 3600) / (MAX_SCANS)))
echo "Scans will be submitted at the rate of 1 scan per ${TARGET_DURATION} seconds"
fi

if [ -z "${DETECT_VERSION}" ]
then
  echo "Default Detect Version"
  DETECT_VERSION="LATEST"
fi

if [ -z "${FAIL_ON_SEVERITIES}" ]
then
  echo "Default Fail on severities"
  FAIL_ON_SEVERITIES="NONE"
fi

PROJECT="Project-$HOSTNAME"
TIMESTAMP=$(date +%Y%m%d.%H%M%S)

INT_PARAMS="BD_HUB_URL API_TOKEN API_TIMEOUT FIXED_COMPONENTS SNIPPETS MAX_SCANS MAX_CODELOCATIONS MIN_COMPONENTS MAX_COMPONENTS MAX_VERSIONS REPEAT_SCAN SYNCHRONOUS_SCANS DETECT_VERSION FAIL_ON_SEVERITIES INSECURE_CURL DEBUG SCAN_TYPE USE_MEMORY_MAPPING USE_GCS GCS_BUCKET GCS_PREFIX"


if [ "$INTERACTIVE" = "yes" ]
then
   for i in $INT_PARAMS
   do
     readvar $i
   done
fi

echo 
echo "$(date '+%Y-%m-%d %H:%M:%S') - Submitting with the following parameters:"
echo  
for i in $INT_PARAMS
do
   echo $'\t' $i ${!i}
done

echo 
if [ "$INTERACTIVE" = "yes" ]
then
   continue=Y
   readvar continue
   if [[ ! "$continue" = "Y" ]] ; then exit 1 ; fi
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting ..."

if [ "$DRY_RUN" == "yes" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - DRY RUN MODE: Skipping authentication checks"
else
  if [ -z "$BD_HUB_URL" ]
  then
     echo No Black Duck URL specified, Exiting.
     exit 1
  fi

  if [ -z "$API_TOKEN" ]
  then
     echo No API token specified, Exiting.
     exit 1
  fi
fi

if (( $MAX_COMPONENTS <= $MIN_COMPONENTS )); then
  echo "MAX_COMPONENTS must be greater than MIN_COMPONENTS"
  exit 1
fi

if [ "${DETECT_VERSION}" != "LATEST" ]
then
  echo "Using Detect Version ${DETECT_VERSION}"
  export DETECT_LATEST_RELEASE_VERSION=${DETECT_VERSION}
else 
  echo "Using Latest Detect Version"
fi

if [ "${FAIL_ON_SEVERITIES}" != "NONE" ]
then
  echo "Using FAIL_ON_SEVERITIES ${FAIL_ON_SEVERITIES}"
else 
  echo "Not specifying FAIL_ON_SEVERITIES"
fi

if [ "${INSECURE_CURL}" == "yes" ]; then
	echo "Setting environment variable DETECT_CURL_OPTS=--insecure"
	export DETECT_CURL_OPTS=--insecure
fi

# Validate scan type
if [[ ! "$SCAN_TYPE" =~ ^(SIGNATURE_SCAN|BINARY_SCAN|CONTAINER_SCAN)$ ]]; then
  echo "Error: SCAN_TYPE must be one of: SIGNATURE_SCAN, BINARY_SCAN, CONTAINER_SCAN"
  echo "Current value: $SCAN_TYPE"
  exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Using scan type: $SCAN_TYPE"

#
#  Generate an array of available files based on scan type
#
echo ".............................."
OIFS=$IFS; IFS=$'\n';

# Set search base directory - support running from anywhere
if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT="$WORKDIR/../.."
  if [ ! -d "$PROJECT_ROOT" ]; then
    PROJECT_ROOT="."
  fi
fi

# Ensure PROJECT_ROOT exists
if [ ! -d "$PROJECT_ROOT" ]; then
  echo "ERROR: PROJECT_ROOT directory does not exist: $PROJECT_ROOT"
  exit 1
fi

# Setup GCS integration if enabled
if [ "${USE_GCS}" == "yes" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Setting up Google Cloud Storage integration"
  
  # Validate GCS configuration
  if [ -z "$GCS_BUCKET" ]; then
    echo "ERROR: GCS_BUCKET must be specified when USE_GCS=yes"
    exit 1
  fi
  
  # Check if gsutil is available
  if ! command -v gsutil &> /dev/null; then
    echo "ERROR: gsutil is not available. Please install Google Cloud SDK."
    exit 1
  fi
  
  # Check if gcsfuse is available
  if ! command -v gcsfuse &> /dev/null; then
    echo "ERROR: gcsfuse is not available. Please install gcsfuse for mounting GCS buckets."
    echo "Install with: curl -L https://github.com/GoogleCloudPlatform/gcsfuse/releases/latest/download/gcsfuse_`uname -s`_`uname -m`.tar.gz | tar -xz && sudo mv gcsfuse /usr/local/bin/"
    exit 1
  fi
  
  # Create mount point if it doesn't exist
  mkdir -p "$GCS_MOUNT_POINT"
  
  # Check if already mounted
  if mount | grep -q "$GCS_MOUNT_POINT"; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - GCS already mounted at $GCS_MOUNT_POINT"
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Mounting GCS bucket gs://$GCS_BUCKET to $GCS_MOUNT_POINT"
    
    # Mount with optimizations for performance
    GCSFUSE_OPTIONS="--temp-dir /tmp/gcs-cache --limit-bytes $GCS_CACHE_SIZE --stat-cache-ttl 1h --type-cache-ttl 1h"
    
    if [ "${DEBUG}" == "yes" ]; then
      GCSFUSE_OPTIONS="$GCSFUSE_OPTIONS --debug_gcs --debug_fuse"
      echo "GCSFuse options: $GCSFUSE_OPTIONS"
    fi
    
    gcsfuse $GCSFUSE_OPTIONS "$GCS_BUCKET" "$GCS_MOUNT_POINT"
    
    if [ $? -ne 0 ]; then
      echo "ERROR: Failed to mount GCS bucket gs://$GCS_BUCKET"
      exit 1
    fi
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Successfully mounted GCS bucket"
    
    # Register cleanup function
    trap 'cleanup_gcs' EXIT
  fi
  
  # Set PROJECT_ROOT to GCS mount point
  if [ -n "$GCS_PREFIX" ]; then
    PROJECT_ROOT="$GCS_MOUNT_POINT/$GCS_PREFIX"
  else
    PROJECT_ROOT="$GCS_MOUNT_POINT"
  fi
  
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Using GCS path: $PROJECT_ROOT"
fi

# ⚠️  LEGACY FILE DISCOVERY LOGIC - REPLACED WITH SCAN-TYPE SPECIFIC DISCOVERY
# This original file discovery logic has been moved inside the scan loop
# to use the specific directory mapped for each scan type/size combination
# 
# if [ "${SCAN_TYPE}" == "SIGNATURE_SCAN" ]; then
#   if [ "${SNIPPETS}" == "yes" ]; then
#     # Search in multiple possible locations for snippet files
#     files=($(find "$PROJECT_ROOT" -name \*.tar.gz -print 2>/dev/null))
#     file_type="tar.gz files for snippet scanning"
#   else
#     # Search in multiple possible locations for jar files
#     files=($(find "$PROJECT_ROOT" -name \*.jar -print 2>/dev/null))
#     file_type="jar files for signature scanning"
#   fi
# elif [ "${SCAN_TYPE}" == "BINARY_SCAN" ]; then
#   # Search for binary files in multiple locations, prioritizing the binaries directory
#   files=($(find "$PROJECT_ROOT" \( -name "*.exe" -o -name "*.tar.gz"  -o -name "*.tgz" -o -name "*.dmg" -o -name "*.iso" -o -name "*.ISO" -o -name "*.msi" -o -name "*.rpm" \) -print 2>/dev/null | sort -V))
#   fileNames=($(find "$PROJECT_ROOT" -type f \( -name "*.exe" -o -name "*.tar.gz" -o -name "*.tgz" -o -name "*.dmg" -o -name "*.iso" -o -name "*.ISO" -o -name "*.msi" -o -name "*.rpm" \) -print 2>/dev/null | sort -V | xargs -r basename -a))
#   file_type="binary files"
# elif [ "${SCAN_TYPE}" == "CONTAINER_SCAN" ]; then
#   # Search for container tar files
#   files=($(find "$PROJECT_ROOT" -name \*.tar -print 2>/dev/null | sort -V))
#   file_type="container image files"
# fi

# Initialize empty arrays - files will be discovered inside the scan loop
# based on the specific directory mapped for each scan type/size
files=()
fileNames=()
file_type="files (will be determined per scan type)"

IFS=$OIFS;

# ⚠️  LEGACY FILE COUNT VALIDATION - MOVED TO INSIDE SCAN LOOP
# File discovery and validation now happens inside the scan loop
# for each specific scan type and directory combination
echo "$(date '+%Y-%m-%d %H:%M:%S') - File discovery will happen per scan type inside the loop"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Initial scan type: $SCAN_TYPE (may change with multi-scan enabled)"

echo "...................................."


#
# Seed random number generator
#
RANDOM=$(date "+%s")
echo "starting" 
pos=0
scans=0
repeating=no
start_pos=0
cl_pos=0
#num_jars=100
end=10

# Per-scan-type file position tracking for sequential selection
# This ensures consistent file selection across scan iterations
declare -A scan_type_positions

# Scan type counters for detailed summary
declare -A scan_type_counts
scan_type_counts["BINARY_SCAN"]=0
scan_type_counts["SIGNATURE_SCAN"]=0
scan_type_counts["CONTAINER_SCAN"]=0

# Size-specific counters for detailed breakdown
declare -A size_specific_counts
# Binary scan size variants
size_specific_counts["BINARY_SCAN_SMALL"]=0
size_specific_counts["BINARY_SCAN_MEDIUM"]=0
size_specific_counts["BINARY_SCAN_LARGE"]=0
size_specific_counts["BINARY_SCAN_XLARGE"]=0
# Signature scan size variants
size_specific_counts["SIGNATURE_SCAN_SMALL"]=0
size_specific_counts["SIGNATURE_SCAN_MEDIUM"]=0
size_specific_counts["SIGNATURE_SCAN_LARGE"]=0
size_specific_counts["SIGNATURE_SCAN_XLARGE"]=0
# Container scan size variants
size_specific_counts["CONTAINER_SCAN_SMALL"]=0
size_specific_counts["CONTAINER_SCAN_MEDIUM"]=0
size_specific_counts["CONTAINER_SCAN_LARGE"]=0
size_specific_counts["CONTAINER_SCAN_XLARGE"]=0
# Snippet scan variants (if applicable)
size_specific_counts["SNIPPET_SCAN_SMALL"]=0
size_specific_counts["SNIPPET_SCAN_MEDIUM"]=0
size_specific_counts["SNIPPET_SCAN_LARGE"]=0
size_specific_counts["SNIPPET_SCAN_XLARGE"]=0
# while [ $pos -lt ${#jars[@]} ]

while (( scans < MAX_SCANS ))
do
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ==============================================="
  echo "$(date '+%Y-%m-%d %H:%M:%S') - 🚀 STARTING SCAN ITERATION $((scans + 1))"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ==============================================="
  echo "$(date '+%Y-%m-%d %H:%M:%S') - 📊 Loop Status:"
  echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Current iteration: $((scans + 1)) / $MAX_SCANS"
  echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Multi-scan enabled: $ENABLE_MULTI_SCAN"
  echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Enhanced multi-scan: $ENABLE_ENHANCED_MULTI_SCAN"
  echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Storage backend: $([ "$USE_GCS" == "yes" ] && echo "GCS" || echo "Local")"
  
  # Multi-scan type selection
  if [ "${ENABLE_MULTI_SCAN}" == "yes" ]; then
    if [ "${ENABLE_ENHANCED_MULTI_SCAN}" == "yes" ]; then
      # Enhanced multi-scan with size-based repositories
      SCAN_TYPE_SIZE=$(select_scan_type_with_size)
      
      # Check if no files are available for any scan type
      if [ "$SCAN_TYPE_SIZE" == "NO_FILES_AVAILABLE" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ==============================================="
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ NO FILES AVAILABLE FOR ANY SCAN TYPE"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ==============================================="
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 🚫 Cannot proceed with scans - no test data files found!"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 💡 Possible solutions:"
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Check LOCAL_TEST_DATA_DIR path: $LOCAL_TEST_DATA_DIR"
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Verify test data directories exist and contain files"
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Use USE_GCS=yes to access cloud-based test data"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ==============================================="
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Exiting to prevent infinite loop."
        exit 1
      fi
      
      echo "$(date '+%Y-%m-%d %H:%M:%S') - ==============================================="
      echo "$(date '+%Y-%m-%d %H:%M:%S') - 🎯 SCAN TYPE SELECTION FOR ITERATION $i"
      echo "$(date '+%Y-%m-%d %H:%M:%S') - ==============================================="
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Selected scan type with size: $SCAN_TYPE_SIZE"
      
      # Parse scan type and size information
      SCAN_INFO=($(parse_scan_type_and_size "$SCAN_TYPE_SIZE"))
      CURRENT_SCAN_TYPE="${SCAN_INFO[0]}"
      SCAN_SIZE="${SCAN_INFO[1]}"
      
      echo "$(date '+%Y-%m-%d %H:%M:%S') - 📊 Parsed scan details:"
      echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Base scan type: $CURRENT_SCAN_TYPE"
      echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Size variant: $SCAN_SIZE"
      echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Full scan type: $SCAN_TYPE_SIZE"
      
      # Get GCS repository for this scan type and size
      if [ "${USE_GCS}" == "yes" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 🗄️  GCS REPOSITORY SELECTION"
        CURRENT_GCS_REPO=$(get_gcs_repository_for_scan "$SCAN_TYPE_SIZE")
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Raw GCS repo path: $CURRENT_GCS_REPO"
        
        # Parse bucket and prefix from repository path
        if [[ "$CURRENT_GCS_REPO" =~ ^([^/]+)/(.+)$ ]]; then
          CURRENT_GCS_BUCKET="${BASH_REMATCH[1]}"
          CURRENT_GCS_PREFIX="${BASH_REMATCH[2]}"
          echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Parsed bucket: $CURRENT_GCS_BUCKET"
          echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Parsed prefix: $CURRENT_GCS_PREFIX"
        else
          CURRENT_GCS_BUCKET="$CURRENT_GCS_REPO"
          CURRENT_GCS_PREFIX=""
          echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Simple bucket: $CURRENT_GCS_BUCKET (no prefix)"
        fi
        
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 📍 Final GCS location: gs://$CURRENT_GCS_BUCKET/$CURRENT_GCS_PREFIX"
        
        # Update GCS mount if different from current
        if [ "$CURRENT_GCS_BUCKET" != "$GCS_BUCKET" ] || [ "$CURRENT_GCS_PREFIX" != "$GCS_PREFIX" ]; then
          echo "$(date '+%Y-%m-%d %H:%M:%S') - Switching to different GCS repository"
          # Unmount current if mounted
          if mount | grep -q "$GCS_MOUNT_POINT"; then
            fusermount -u "$GCS_MOUNT_POINT" 2>/dev/null || umount "$GCS_MOUNT_POINT" 2>/dev/null
          fi
          # Update variables and remount
          GCS_BUCKET="$CURRENT_GCS_BUCKET"
          GCS_PREFIX="$CURRENT_GCS_PREFIX"
          # Re-setup GCS mount with new bucket/prefix
          if [ -n "$GCS_PREFIX" ]; then
            PROJECT_ROOT="$GCS_MOUNT_POINT/$GCS_PREFIX"
          else
            PROJECT_ROOT="$GCS_MOUNT_POINT"
          fi
          # Remount GCS bucket
          gcsfuse $GCSFUSE_OPTIONS "$GCS_BUCKET" "$GCS_MOUNT_POINT"
          if [ $? -ne 0 ]; then
            echo "ERROR: Failed to remount GCS bucket gs://$GCS_BUCKET"
            exit 1
          fi
        fi
      fi
      
      # Handle snippet scans
      if [[ "$SCAN_TYPE_SIZE" =~ ^SNIPPET_SCAN ]]; then
        SNIPPETS="yes"
        CURRENT_SCAN_TYPE="SIGNATURE_SCAN"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Enabled snippet scanning for $SCAN_TYPE_SIZE"
      else
        SNIPPETS="no"
      fi
      
      # Use selected scan type for this iteration
      SCAN_TYPE="$CURRENT_SCAN_TYPE"
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Using scan type: $SCAN_TYPE, Size: $SCAN_SIZE, Snippets: $SNIPPETS"
      
      # Update PROJECT_ROOT for local test data when GCS is not used (Enhanced Multi-Scan)
      if [ "${USE_GCS}" != "yes" ]; then
        # Resolve LOCAL_TEST_DATA_DIR to absolute path
        LOCAL_TEST_DATA_DIR=$(cd "${LOCAL_TEST_DATA_DIR}" 2>/dev/null && pwd || echo "${LOCAL_TEST_DATA_DIR}")
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 📁 LOCAL DIRECTORY SELECTION"
        LOCAL_DIR=$(get_local_directory_for_scan_type "$SCAN_TYPE_SIZE")
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Mapped to local directory: $LOCAL_DIR"
        
        if [ -d "$LOCAL_DIR" ]; then
          PROJECT_ROOT="$LOCAL_DIR"
          echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Directory exists, using: $PROJECT_ROOT"
          
          # Count files in the directory for additional context
          file_count=$(find "$LOCAL_DIR" -type f | wc -l | tr -d ' ')
          echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Files available: $file_count"
        else
          echo "$(date '+%Y-%m-%d %H:%M:%S') - ⚠️  Directory not found: $LOCAL_DIR, using default PROJECT_ROOT"
        fi
      else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 📍 Using GCS storage, PROJECT_ROOT: $PROJECT_ROOT"
      fi
      
    else
      # Original multi-scan logic
      CURRENT_SCAN_TYPE=$(select_scan_type)
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Selected scan type for this iteration: $CURRENT_SCAN_TYPE"
      
      # Select GCS repository based on configuration
      if [ "${USE_GCS}" == "yes" ]; then
        GCS_SELECTION=($(select_gcs_repo))
        CURRENT_GCS_BUCKET="${GCS_SELECTION[0]}"
        CURRENT_GCS_PREFIX="${GCS_SELECTION[1]}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Selected GCS repo: gs://$CURRENT_GCS_BUCKET/$CURRENT_GCS_PREFIX"
        
        # Update GCS mount if different from current
        if [ "$CURRENT_GCS_BUCKET" != "$GCS_BUCKET" ] || [ "$CURRENT_GCS_PREFIX" != "$GCS_PREFIX" ]; then
          echo "$(date '+%Y-%m-%d %H:%M:%S') - Switching to different GCS repository"
          # Unmount current if mounted
          if mount | grep -q "$GCS_MOUNT_POINT"; then
            fusermount -u "$GCS_MOUNT_POINT" 2>/dev/null || umount "$GCS_MOUNT_POINT" 2>/dev/null
          fi
          # Update variables and remount
          GCS_BUCKET="$CURRENT_GCS_BUCKET"
          GCS_PREFIX="$CURRENT_GCS_PREFIX"
          # Re-setup GCS mount with new bucket/prefix
          if [ -n "$GCS_PREFIX" ]; then
            PROJECT_ROOT="$GCS_MOUNT_POINT/$GCS_PREFIX"
          else
            PROJECT_ROOT="$GCS_MOUNT_POINT"
          fi
          # Remount GCS bucket
          gcsfuse $GCSFUSE_OPTIONS "$GCS_BUCKET" "$GCS_MOUNT_POINT"
          if [ $? -ne 0 ]; then
            echo "ERROR: Failed to remount GCS bucket gs://$GCS_BUCKET"
            exit 1
          fi
        fi
      fi
      
      # Use selected scan type for this iteration
      SCAN_TYPE="$CURRENT_SCAN_TYPE"
      echo "$(date '+%Y-%m-%d %H:%M:%S') - 🔄 SCAN TYPE ACTIVATION"
      echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Activated scan type: $SCAN_TYPE (from $SCAN_TYPE_SIZE)"
      
      # Update PROJECT_ROOT for local test data when GCS is not used
      if [ "${USE_GCS}" != "yes" ] && [ "${ENABLE_ENHANCED_MULTI_SCAN}" == "yes" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 📁 LOCAL DIRECTORY SELECTION"
        LOCAL_DIR=$(get_local_directory_for_scan_type "$SCAN_TYPE_SIZE")
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Mapped to local directory: $LOCAL_DIR"
        
        if [ -d "$LOCAL_DIR" ]; then
          PROJECT_ROOT="$LOCAL_DIR"
          echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Directory exists, using: $PROJECT_ROOT"
          
          # Count files in the directory for additional context
          file_count=$(find "$LOCAL_DIR" -type f | wc -l | tr -d ' ')
          echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Files available: $file_count"
        else
          echo "$(date '+%Y-%m-%d %H:%M:%S') - ⚠️  Directory not found: $LOCAL_DIR, using default PROJECT_ROOT"
        fi
      else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 📍 Using GCS storage, PROJECT_ROOT: $PROJECT_ROOT"
      fi
    fi
  fi
  
  # 🔍 SCAN-TYPE SPECIFIC FILE DISCOVERY
  # Now that we have the correct PROJECT_ROOT for this scan type, discover files
  echo "$(date '+%Y-%m-%d %H:%M:%S') - 🔍 DISCOVERING FILES IN SCAN-TYPE SPECIFIC DIRECTORY"
  echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Searching in: $PROJECT_ROOT"
  echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Scan type: $SCAN_TYPE"
  
  OIFS=$IFS; IFS=$'\n';
  
  if [ "${SCAN_TYPE}" == "SIGNATURE_SCAN" ]; then
    if [ "${SNIPPETS}" == "yes" ]; then
      # Search for snippet files in the specific directory
      files=($(find "$PROJECT_ROOT" \( -name "*.tar.gz" -o -name "*.zip" \) -print 2>/dev/null))
      file_type="tar.gz and zip files for snippet scanning"
      echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Looking for: *.tar.gz and *.zip files (snippet mode)"
    else
      # Search for jar and zip files in the specific directory
      files=($(find "$PROJECT_ROOT" \( -name "*.jar" -o -name "*.zip" \) -print 2>/dev/null))
      file_type="jar and zip files for signature scanning"
      echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Looking for: *.jar and *.zip files (signature mode)"
    fi
  elif [ "${SCAN_TYPE}" == "BINARY_SCAN" ]; then
    # Search for binary files in the specific directory
    files=($(find "$PROJECT_ROOT" \( -name "*.exe" -o -name "*.tar.gz"  -o -name "*.tgz" -o -name "*.dmg" -o -name "*.iso" -o -name "*.ISO" -o -name "*.msi" -o -name "*.rpm" \) -print 2>/dev/null | sort -V))
    fileNames=($(find "$PROJECT_ROOT" -type f \( -name "*.exe" -o -name "*.tar.gz" -o -name "*.tgz" -o -name "*.dmg" -o -name "*.iso" -o -name "*.ISO" -o -name "*.msi" -o -name "*.rpm" \) -print 2>/dev/null | sort -V | xargs -r basename -a))
    file_type="binary files"
    echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Looking for: *.exe, *.msi, *.tar.gz, *.dmg, *.iso, *.rpm files"
  elif [ "${SCAN_TYPE}" == "CONTAINER_SCAN" ]; then
    # Search for container tar files in the specific directory
    files=($(find "$PROJECT_ROOT" -name \*.tar -print 2>/dev/null | sort -V))
    file_type="container image files"
    echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Looking for: *.tar files (container images)"
  fi
  
  IFS=$OIFS;
  
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Initial File Discovery Results:"
  echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Found ${#files[@]} $file_type"
  echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Directory: $PROJECT_ROOT"
  
  # 📏 SIZE-BASED FILE FILTERING (Enhanced Multi-Scan)
  # Filter files by actual size to match the intended size category
  if [ "${ENABLE_ENHANCED_MULTI_SCAN}" == "yes" ] && [ -n "${SCAN_TYPE_SIZE}" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 📏 FILTERING FILES BY SIZE CATEGORY"
    
    # Extract the size category from SCAN_TYPE_SIZE (e.g., BINARY_SCAN_LARGE -> LARGE)
    SIZE_CATEGORY=$(echo "$SCAN_TYPE_SIZE" | sed 's/.*_\([^_]*\)$/\1/')
    echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Target size category: $SIZE_CATEGORY"
    
    # Define size ranges in bytes (aligned with SCASS processing swim lanes)
    # SMALL: < 128MB, MEDIUM: 129MB - 1GB, LARGE: 1GB - 6GB, XLARGE: ≥ 6GB
    case "$SIZE_CATEGORY" in
      "SMALL")
        min_size=0
        max_size=134217727  # 128MB - 1 byte (< 128MB)
        ;;
      "MEDIUM") 
        min_size=135266304   # 129MB
        max_size=1073741824  # 1GB
        ;;
      "LARGE")
        min_size=1073741825   # 1GB + 1 byte  
        max_size=6442450944   # 6GB
        ;;
      "XLARGE")
        min_size=6442450945  # 6GB + 1 byte
        max_size=999999999999999  # Unlimited
        ;;
      *)
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   ⚠️  Unknown size category: $SIZE_CATEGORY, using all files"
        min_size=0
        max_size=999999999999999
        ;;
    esac
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Size range: $((min_size / 1048576))MB - $((max_size / 1048576))MB"
    
    # Filter files by size
    size_filtered_files=()
    total_checked=0
    for file in "${files[@]}"; do
      if [ -f "$file" ]; then
        file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
        total_checked=$((total_checked + 1))
        
        if [ "$file_size" -ge "$min_size" ] && [ "$file_size" -le "$max_size" ]; then
          size_filtered_files+=("$file")
        fi
      fi
    done
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Size Filtering Results:"
    echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Checked: $total_checked files"
    echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Matching size range: ${#size_filtered_files[@]} files"
    
    # Use size-filtered files if any were found, otherwise fall back to all files
    if [ ${#size_filtered_files[@]} -gt 0 ]; then
      files=("${size_filtered_files[@]}")
      echo "$(date '+%Y-%m-%d %H:%M:%S') -   ✅ Using size-filtered files for $SIZE_CATEGORY category"
    else
      echo "$(date '+%Y-%m-%d %H:%M:%S') -   ⚠️  No files match size criteria, using all available files as fallback"
    fi
    
    # Update fileNames array for binary scans if size filtering was applied
    if [ "${SCAN_TYPE}" == "BINARY_SCAN" ] && [ ${#size_filtered_files[@]} -gt 0 ]; then
      fileNames=()
      for file in "${files[@]}"; do
        fileNames+=($(basename "$file"))
      done
    fi
  fi
  
  echo "$(date '+%Y-%m-%d %H:%M:%S') - 📋 Final File Selection Results:"
  echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Using ${#files[@]} $file_type"
  echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Directory: $PROJECT_ROOT"
  
  # Check if any files were found for this specific scan type
  if [ ${#files[@]} -eq 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ⚠️  No $file_type found in $PROJECT_ROOT"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 🔄 Skipping this iteration, will try next scan type selection"
    continue
  fi
  
  # Log first few files found for reference
  echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Sample files found:"
  count=0
  for file in "${files[@]}"; do
    if [ $count -lt 3 ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') -     - $(basename "$file")"
      count=$((count + 1))
    else
      break
    fi
  done
  if [ ${#files[@]} -gt 3 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') -     - ... and $((${#files[@]} - 3)) more files"
  fi
  
  if [ "${repeating}" == "no" ] && [ "${RANDOM_SCANS}" == "yes" ]; then
    start_pos=$(( ( RANDOM % ${#files[@]} ) ))
    if [ "${SCAN_TYPE}" == "SIGNATURE_SCAN" ]; then
      # For signature scans (including snippets), use random number of components
      num_files=$(( ( RANDOM % $MAX_COMPONENTS ) + 1 ))
      # use maximum of num_files OR MIN_COMPONENTS to set lower threshold for number of components
      num_files=$(( num_files > MIN_COMPONENTS ? num_files : MIN_COMPONENTS ))
    else
      # Binary and container scans always use exactly 1 file
      num_files=1
    fi
    end=$((start_pos + num_files))
    if [ $end -gt ${#files[@]} ]
    then
      num_files=$((${#files[@]} - start_pos))
    fi
    project_files=("${files[@]:$start_pos:$num_files}")
    echo "start_pos: $start_pos"
    echo "num_files: $num_files"
    echo "end: $end"
    echo "files in project_files: ${#project_files[@]}"
    echo "project_files: ${project_files[@]}"
  # checking for Random Scans Flag. If the flag is set to No, components chosen to submit scans will be repeatable between releases.
  elif [  "${RANDOM_SCANS}" == "no"  ]; then
    # Use per-scan-type position tracking for consistent sequential selection
    # Get the current scan type identifier for position tracking
    SCAN_TYPE_KEY="${SCAN_TYPE}"
    if [ "${ENABLE_ENHANCED_MULTI_SCAN}" == "yes" ] && [ -n "${SCAN_TYPE_SIZE}" ]; then
      SCAN_TYPE_KEY="${SCAN_TYPE_SIZE}"
    fi
    
    # Initialize position for this scan type if not already set
    if [ -z "${scan_type_positions[$SCAN_TYPE_KEY]}" ]; then
      scan_type_positions[$SCAN_TYPE_KEY]=0
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Initializing file position for scan type: $SCAN_TYPE_KEY"
    fi
    
    # Get current position for this scan type
    current_pos=${scan_type_positions[$SCAN_TYPE_KEY]}
    
    cl_pos=$((cl_pos + 1))

# assigning the number of components to be submitted per scan based on the total number of files available and number of components chosen by the tester.
    if [ "${SCAN_TYPE}" == "SIGNATURE_SCAN" ]; then
      # For signature scans (including snippets), use FIXED_COMPONENTS but cap at available files
      num_files=$(( FIXED_COMPONENTS > ${#files[@]} ? ${#files[@]} : FIXED_COMPONENTS ))
    else
      # Binary and container scans always use exactly 1 file
      num_files=1
    fi
    
    # Calculate end position
    end=$((current_pos + num_files))

#Since the files are submitted by increasing the value of start and end index, condition is added to check
# whether the end index value reached the total number of files and if reached resetting it back to 0
    if [ $end -gt ${#files[@]} ]; then
      current_pos=0
      end=$num_files
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Wrapping around file list for scan type: $SCAN_TYPE_KEY"
    fi
    
    # Use current position for this scan type
    start_pos=$current_pos
    
    #start and end index for choosing the files are assigned.
    project_files=("${files[@]:$start_pos:$num_files}")
    
    # Update position for next iteration of this scan type
    scan_type_positions[$SCAN_TYPE_KEY]=$((start_pos + num_files))
    
    echo "FIXED_COMPONENTS: $FIXED_COMPONENTS"
    echo "SCAN_TYPE_KEY: $SCAN_TYPE_KEY"
    echo "start_pos: $start_pos"
    echo "num_files: $num_files"
    echo "end: $end"
    echo "next_pos_for_${SCAN_TYPE_KEY}: ${scan_type_positions[$SCAN_TYPE_KEY]}"
    echo "files in project_files: ${#project_files[@]}"
    if [ "${SCAN_TYPE}" == "BINARY_SCAN" ]; then
      echo "project_files: ${fileNames[@]}"
    else
      echo "project_files: ${project_files[@]}"
    fi

  fi

  repeating=${REPEAT_SCAN}

  if [ "${SCAN_TYPE}" == "CONTAINER_SCAN" ]; then
    project_name="$PROJECT-$(($RANDOM))-on-${TIMESTAMP}-$pos"
  else
    project_name="$PROJECT-$(($RANDOM))-on-${TIMESTAMP}"
  fi
  echo "project_name: ${project_name}"
  mkdir $project_name

  RANDOM=`date "+%s"`
  versions=$(( ( RANDOM % $MAX_VERSIONS ) + 1 ))
  for ((v=1; v<=$versions;v++))
  do
    echo "version: $v"
    num_codelocations=$MAX_CODELOCATIONS

    for ((cl=0; cl<$num_codelocations;cl++))
    do
      echo "code location: $(( cl + 1 ))"
      RANDOM=`date "+%s"`
      container_id=`cat /etc/hostname`
      echo "Container ID: $container_id"
      
      if [ "${SCAN_TYPE}" == "BINARY_SCAN" ]; then
        cl_name="$container_id-on-${TIMESTAMP}-binary-cl-${cl_pos}"
      elif [ "${SCAN_TYPE}" == "CONTAINER_SCAN" ]; then
        cl_name="$container_id-on-${TIMESTAMP}-container-cl-${cl_pos}"
      else
        cl_name="$container_id-on-${TIMESTAMP}-cl-${cl_pos}"
      fi
      
      echo "code location name: $cl_name"

      mkdir -p $project_name/$cl_name
      echo "$(date '+%Y-%m-%d %H:%M:%S') - file preparation started"
      
      if [ "${USE_MEMORY_MAPPING}" == "yes" ]; then
        # Use Python memory mapping for efficient file access
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Using memory mapping for file access"
        
        if [ "${SCAN_TYPE}" == "SIGNATURE_SCAN" ]; then
          # For signature scans, still need to copy/link files to scan directory
          python3 "$WORKDIR/mmap_file_handler.py" --source-files ${project_files[@]} --dest-dir "$project_name/$cl_name" --verbose
        else
          # For binary and container scans, create memory-mapped links
          prepared_files=($(python3 "$WORKDIR/mmap_file_handler.py" --source-files ${project_files[@]} --dest-dir "$project_name/$cl_name"))
          if [ ${#prepared_files[@]} -eq 0 ]; then
            echo "ERROR: Memory mapping preparation failed"
            exit 1
          fi
        fi
      else
        # Original file handling approach
        if [ "${SCAN_TYPE}" == "SIGNATURE_SCAN" ]; then
          rsync -a ${project_files[@]} $project_name/$cl_name
        elif [ "${SCAN_TYPE}" == "BINARY_SCAN" ]; then
          ln -f ${project_files[@]} $project_name/$cl_name
        elif [ "${SCAN_TYPE}" == "CONTAINER_SCAN" ]; then
          ln -f ${project_files[@]} $project_name/$cl_name
        fi
      fi
      
      echo "$(date '+%Y-%m-%d %H:%M:%S') - file preparation completed"
      
      # Copy .tar.gz files if enabled and using enhanced multi-scan
      if [ "${ENABLE_TARGZ_FILES}" == "yes" ] && [ "${ENABLE_ENHANCED_MULTI_SCAN}" == "yes" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 📦 TAR.GZ FILES PROCESSING"
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   • TAR.GZ files enabled: $ENABLE_TARGZ_FILES"
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Target directory: $project_name/$cl_name"
        copy_targz_files "$project_name/$cl_name"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ TAR.GZ files copy completed"
      else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 📦 TAR.GZ files: DISABLED (ENABLE_TARGZ_FILES=$ENABLE_TARGZ_FILES, ENABLE_ENHANCED_MULTI_SCAN=$ENABLE_ENHANCED_MULTI_SCAN)"
      fi

      echo "$(date '+%Y-%m-%d %H:%M:%S') - ==============================================="
      echo "$(date '+%Y-%m-%d %H:%M:%S') - 🚀 STARTING SCAN EXECUTION"
      echo "$(date '+%Y-%m-%d %H:%M:%S') - ==============================================="
      echo "$(date '+%Y-%m-%d %H:%M:%S') - 🎯 Scan Configuration:"
      echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Scan Type: $SCAN_TYPE"
      if [ -n "$SCAN_TYPE_SIZE" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Full Type: $SCAN_TYPE_SIZE"
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Size Variant: $SCAN_SIZE"
      fi
      echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Project: $project_name"
      echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Version: $v"
      echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Code Location: $cl_name"
      echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Source Path: $project_name/$cl_name"
      
      DETECT_OPTIONS="--blackduck.url=${BD_HUB_URL} --blackduck.api.token=${API_TOKEN}"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.project.name=${project_name} --detect.project.version.name=${v}"
      DETECT_OPTIONS="${DETECT_OPTIONS} --blackduck.trust.cert=true"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.timeout=${API_TIMEOUT}"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.tools=${SCAN_TYPE}"
      
      echo "$(date '+%Y-%m-%d %H:%M:%S') - 🔧 Detect Tool Configuration: --detect.tools=${SCAN_TYPE}"
      
      if [ "${SCAN_TYPE}" == "SIGNATURE_SCAN" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ⚙️  SIGNATURE_SCAN specific configuration:"
        DETECT_OPTIONS="${DETECT_OPTIONS} --detect.code.location.name=${cl_name}"
        DETECT_OPTIONS="${DETECT_OPTIONS} --detect.parallel.processors=-1"
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Code location: ${cl_name}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Parallel processors: -1 (auto)"
        DETECT_OPTIONS="${DETECT_OPTIONS} --detect.source.path=${project_name}/${cl_name}"
        
        if [ "${STRING_SEARCH}" == "yes" ]; then
          DETECT_OPTIONS="${DETECT_OPTIONS} --detect.blackduck.signature.scanner.license.search=true"
          DETECT_OPTIONS="${DETECT_OPTIONS} --detect.blackduck.signature.scanner.copyright.search=true"
        fi
        if [ "${SNIPPETS}" == "yes" ]; then
          DETECT_OPTIONS="${DETECT_OPTIONS} --detect.blackduck.signature.scanner.snippet.matching=SNIPPET_MATCHING"
          DETECT_OPTIONS="${DETECT_OPTIONS} --detect.blackduck.signature.scanner.upload.source.mode=true"
        fi
        
      elif [ "${SCAN_TYPE}" == "BINARY_SCAN" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ⚙️  BINARY_SCAN specific configuration:"
        DETECT_OPTIONS="${DETECT_OPTIONS} --detect.code.location.name=${cl_name}"
        DETECT_OPTIONS="${DETECT_OPTIONS} --detect.parallel.processors=-1"
        DETECT_OPTIONS="${DETECT_OPTIONS} --detect.binary.scan.file.path=${project_name}/${cl_name}/${fileNames[start_pos]}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Code location: ${cl_name}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Binary file: ${fileNames[start_pos]}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Full path: ${project_name}/${cl_name}/${fileNames[start_pos]}"
        
      elif [ "${SCAN_TYPE}" == "CONTAINER_SCAN" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ⚙️  CONTAINER_SCAN specific configuration:"
        DETECT_OPTIONS="${DETECT_OPTIONS} --detect.cleanup=false"
        if [ "${DEBUG}" == "yes" ]; then
          DETECT_OPTIONS="${DETECT_OPTIONS} --detect.diagnostic=true"
          echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Diagnostics enabled: true (DEBUG mode)"
        else
          echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Diagnostics disabled: false (DEBUG=no)"
        fi
        DETECT_OPTIONS="${DETECT_OPTIONS} --detect.container.scan.file.path=${project_files[@]}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Container files: ${project_files[@]}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Cleanup disabled: false"
      fi

      if [ "${DEBUG}" == "yes" ]; then
        DETECT_OPTIONS="${DETECT_OPTIONS} --logging.level.detect=TRACE"
      fi
      if [ "${SYNCHRONOUS_SCANS}" == "yes" ]; then
        DETECT_OPTIONS="${DETECT_OPTIONS} --detect.wait.for.results=true"
      fi
      if [ "${FAIL_ON_SEVERITIES}" != "NONE" ]; then
        DETECT_OPTIONS="${DETECT_OPTIONS} --detect.policy.check.fail.on.severities=${FAIL_ON_SEVERITIES}"
      fi

      detect_log=/tmp/detect_$$.log
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Final Detect Options: $DETECT_OPTIONS"
      
      if [ "${DRY_RUN}" == "yes" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - DRY_RUN mode: Skipping detect execution"
        # Simulate elapsed time for dry run
        elapsed_time=30
        echo "DRY_RUN: Simulated scan completed in ${elapsed_time} seconds" > ${detect_log}
      else
        bash <(curl -s -L ${DETECT_CURL_OPTS} https://detect.blackduck.com/detect10.sh) ${DETECT_OPTIONS} | tee ${detect_log}
        elapsed_time=$(get_elapsed_time $detect_log)
      fi

      echo "$(date '+%Y-%m-%d %H:%M:%S') - Elapsed time for scan was ${elapsed_time} seconds"
      WAIT_TIME=$(( TARGET_DURATION  - elapsed_time ))
      rm $detect_log

      ((scans++))
      
      # Increment scan type counters
      ((scan_type_counts["$SCAN_TYPE"]++))
      
      # Increment size-specific counter if SCAN_TYPE_SIZE is available
      if [ -n "$SCAN_TYPE_SIZE" ]; then
        ((size_specific_counts["$SCAN_TYPE_SIZE"]++))
      fi
      
      echo "$(date '+%Y-%m-%d %H:%M:%S') - ==============================================="
      echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ SCAN ITERATION $scans COMPLETED"
      echo "$(date '+%Y-%m-%d %H:%M:%S') - ==============================================="
      echo "$(date '+%Y-%m-%d %H:%M:%S') - 📊 Iteration Summary:"
      echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Scan type used: $SCAN_TYPE"
      if [ -n "$SCAN_TYPE_SIZE" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Full scan type: $SCAN_TYPE_SIZE"
      fi
      echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Project: $project_name"
      echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Completed: $scans / $MAX_SCANS scans"
      echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Execution time: ${elapsed_time}s"
      echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Target duration: ${TARGET_DURATION}s"
      
      # Only sleep between scans (skip first scan and dry run mode)
      if [ "${DRY_RUN}" == "yes" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ⏭️  Skipping sleep in DRY_RUN mode"
      elif [ $scans -gt 1 ] && [ $scans -le $MAX_SCANS ]; then
        if [ $WAIT_TIME -gt 0 ]; then
          echo "$(date '+%Y-%m-%d %H:%M:%S') - ⏱️  Sleeping for ${WAIT_TIME} seconds to maintain ${TARGET_DURATION}s per scan cadence"
          sleep "$WAIT_TIME"
        else
          echo "$(date '+%Y-%m-%d %H:%M:%S') - ⚡ Scan exceeded target duration (${elapsed_time}s > ${TARGET_DURATION}s), no sleep needed"
        fi
      elif [ $scans -eq 1 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ⏭️  Skipping sleep for first scan"
      fi
      
      # Show progress and continuation status
      if [ $scans -lt $MAX_SCANS ]; then
        remaining=$((MAX_SCANS - scans))
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 🔄 CONTINUING TO NEXT ITERATION"
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Remaining scans: $remaining"
        echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Next scan will be: $(($scans + 1)) / $MAX_SCANS"
      else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 🏁 ALL SCANS COMPLETED - EXITING LOOP"
      fi
    done
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 🔄 Completed inner loop for project batch"
  done
  echo "$(date '+%Y-%m-%d %H:%M:%S') - 🧹 Cleaning up project directory: ${project_name}"
  rm -rf $project_name
  
  if [ "${SCAN_TYPE}" == "CONTAINER_SCAN" ]; then
    pos=$((pos + num_files + 1))
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 📍 Advanced container scan position to: $pos"
  fi
done

echo "$(date '+%Y-%m-%d %H:%M:%S') - ==============================================="
echo "$(date '+%Y-%m-%d %H:%M:%S') - 🎉 LOAD TESTING SESSION COMPLETED"
echo "$(date '+%Y-%m-%d %H:%M:%S') - ==============================================="
echo "$(date '+%Y-%m-%d %H:%M:%S') - 📊 Final Summary:"
echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Total scans completed: $scans"
echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Target scans: $MAX_SCANS"
echo "$(date '+%Y-%m-%d %H:%M:%S') - 📋 Detailed Scan Type Breakdown:"
echo "$(date '+%Y-%m-%d %H:%M:%S') -   • BINARY_SCAN: ${scan_type_counts["BINARY_SCAN"]} scans"
# Calculate size-grouped totals for Binary scans
binary_small_medium=$((${size_specific_counts["BINARY_SCAN_SMALL"]} + ${size_specific_counts["BINARY_SCAN_MEDIUM"]}))
binary_large=${size_specific_counts["BINARY_SCAN_LARGE"]}
binary_xlarge=${size_specific_counts["BINARY_SCAN_XLARGE"]}
echo "$(date '+%Y-%m-%d %H:%M:%S') -     ◦ Small & Medium: $binary_small_medium scans"
echo "$(date '+%Y-%m-%d %H:%M:%S') -     ◦ Large: $binary_large scans"
echo "$(date '+%Y-%m-%d %H:%M:%S') -     ◦ XLarge: $binary_xlarge scans"

echo "$(date '+%Y-%m-%d %H:%M:%S') -   • SIGNATURE_SCAN: ${scan_type_counts["SIGNATURE_SCAN"]} scans"
# Calculate size-grouped totals for Signature scans
signature_small_medium=$((${size_specific_counts["SIGNATURE_SCAN_SMALL"]} + ${size_specific_counts["SIGNATURE_SCAN_MEDIUM"]}))
signature_large=${size_specific_counts["SIGNATURE_SCAN_LARGE"]}
signature_xlarge=${size_specific_counts["SIGNATURE_SCAN_XLARGE"]}
echo "$(date '+%Y-%m-%d %H:%M:%S') -     ◦ Small & Medium: $signature_small_medium scans"
echo "$(date '+%Y-%m-%d %H:%M:%S') -     ◦ Large: $signature_large scans"
echo "$(date '+%Y-%m-%d %H:%M:%S') -     ◦ XLarge: $signature_xlarge scans"

echo "$(date '+%Y-%m-%d %H:%M:%S') -   • CONTAINER_SCAN: ${scan_type_counts["CONTAINER_SCAN"]} scans"
# Calculate size-grouped totals for Container scans
container_small_medium=$((${size_specific_counts["CONTAINER_SCAN_SMALL"]} + ${size_specific_counts["CONTAINER_SCAN_MEDIUM"]}))
container_large=${size_specific_counts["CONTAINER_SCAN_LARGE"]}
container_xlarge=${size_specific_counts["CONTAINER_SCAN_XLARGE"]}
echo "$(date '+%Y-%m-%d %H:%M:%S') -     ◦ Small & Medium: $container_small_medium scans"
echo "$(date '+%Y-%m-%d %H:%M:%S') -     ◦ Large: $container_large scans"
echo "$(date '+%Y-%m-%d %H:%M:%S') -     ◦ XLarge: $container_xlarge scans"

# Include snippet scans if any were executed
snippet_total=$((${size_specific_counts["SNIPPET_SCAN_SMALL"]} + ${size_specific_counts["SNIPPET_SCAN_MEDIUM"]} + ${size_specific_counts["SNIPPET_SCAN_LARGE"]} + ${size_specific_counts["SNIPPET_SCAN_XLARGE"]}))
if [ $snippet_total -gt 0 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') -   • SNIPPET_SCAN: $snippet_total scans"
  snippet_small_medium=$((${size_specific_counts["SNIPPET_SCAN_SMALL"]} + ${size_specific_counts["SNIPPET_SCAN_MEDIUM"]}))
  snippet_large=${size_specific_counts["SNIPPET_SCAN_LARGE"]}
  snippet_xlarge=${size_specific_counts["SNIPPET_SCAN_XLARGE"]}
  echo "$(date '+%Y-%m-%d %H:%M:%S') -     ◦ Small & Medium: $snippet_small_medium scans"
  echo "$(date '+%Y-%m-%d %H:%M:%S') -     ◦ Large: $snippet_large scans"
  echo "$(date '+%Y-%m-%d %H:%M:%S') -     ◦ XLarge: $snippet_xlarge scans"
fi
echo "$(date '+%Y-%m-%d %H:%M:%S') - ⚙️  Configuration Details:"
echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Multi-scan mode: $ENABLE_MULTI_SCAN"
echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Enhanced multi-scan: $ENABLE_ENHANCED_MULTI_SCAN"
if [ -n "$MULTI_SCAN_CONFIG" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Scan distribution: $MULTI_SCAN_CONFIG"
fi
echo "$(date '+%Y-%m-%d %H:%M:%S') -   • Storage backend: $([ "$USE_GCS" == "yes" ] && echo "GCS (gs://$GCS_BUCKET/$GCS_PREFIX)" || echo "Local ($PROJECT_ROOT)")"
echo "$(date '+%Y-%m-%d %H:%M:%S') - 🏁 Hub load testing session finished successfully"
