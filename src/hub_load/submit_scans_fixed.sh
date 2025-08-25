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

# Set woring directory
#
WORKDIR=$(dirname $0)
cd $WORKDIR

#
# Defaults
#
BD_HUB_URL=${BD_HUB_URL:-https://}
API_TOKEN=${API_TOKEN:-Y2Y0N}
API_TIMEOUT=${API_TIMEOUT:-300}
MAX_SCANS=${MAX_SCANS:-3}
MAX_CODELOCATIONS=${MAX_CODELOCATIONS:-1}
MAX_COMPONENTS=${MAX_COMPONENTS:-400}
MIN_COMPONENTS=${MIN_COMPONENTS:-200}
FIXED_COMPONENTS=${FIXED_COMPONENTS:-100}
MAX_VERSIONS=${MAX_VERSIONS:-1}
SYNCHRONOUS_SCANS=${SYNCHRONOUS_SCANS:-yes}
REPEAT_SCAN=${REPEAT_SCAN:-no}
RANDOM_SCANS=${RANDOM_SCANS:-no}
DETECT_VERSION=${DETECT_VERSION}
FAIL_ON_SEVERITIES=${FAIL_ON_SEVERITIES}
INSECURE_CURL=${INSECURE_CURL:-no}
STRING_SEARCH=${STRING_SEARCH:-no}
DEBUG=${DEBUG:-no}
SCAN_TYPE=${SCAN_TYPE:-SIGNATURE_SCAN}
SNIPPETS=${SNIPPETS:-no}
WAIT_TIME=${WAIT_TIME:-30}
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

INT_PARAMS="BD_HUB_URL API_TOKEN API_TIMEOUT FIXED_COMPONENTS SNIPPETS MAX_SCANS MAX_CODELOCATIONS MIN_COMPONENTS MAX_COMPONENTS MAX_VERSIONS REPEAT_SCAN SYNCHRONOUS_SCANS DETECT_VERSION FAIL_ON_SEVERITIES INSECURE_CURL DEBUG SCAN_TYPE"


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
PROJECT_ROOT="$WORKDIR/../.."
if [ ! -d "$PROJECT_ROOT" ]; then
  PROJECT_ROOT="."
fi

if [ "${SCAN_TYPE}" == "SIGNATURE_SCAN" ]; then
  if [ "${SNIPPETS}" == "yes" ]; then
    # Search in multiple possible locations for snippet files
    files=($(find "$PROJECT_ROOT" -name \*.tar.gz -print 2>/dev/null))
    file_type="tar.gz files for snippet scanning"
  else
    # Search in multiple possible locations for jar files
    files=($(find "$PROJECT_ROOT" -name \*.jar -print 2>/dev/null))
    file_type="jar files for signature scanning"
  fi
elif [ "${SCAN_TYPE}" == "BINARY_SCAN" ]; then
  # Search for binary files in multiple locations, prioritizing the binaries directory
  files=($(find "$PROJECT_ROOT" \( -name "*.exe" -o -name "*.tar.gz"  -o -name "*.tgz" -o -name "*.dmg" -o -name "*.iso" -o -name "*.ISO" -o -name "*.msi" -o -name "*.rpm" \) -print 2>/dev/null | sort -V))
  fileNames=($(find "$PROJECT_ROOT" -type f \( -name "*.exe" -o -name "*.tar.gz" -o -name "*.tgz" -o -name "*.dmg" -o -name "*.iso" -o -name "*.ISO" -o -name "*.msi" -o -name "*.rpm" \) -print 2>/dev/null | sort -V | xargs -r basename -a))
  file_type="binary files"
elif [ "${SCAN_TYPE}" == "CONTAINER_SCAN" ]; then
  # Search for container tar files
  files=($(find "$PROJECT_ROOT" -name \*.tar -print 2>/dev/null | sort -V))
  file_type="container image files"
fi

IFS=$OIFS;

echo "$(date '+%Y-%m-%d %H:%M:%S') - ${#files[@]} $file_type located"

# Check if any files were found
if [ ${#files[@]} -eq 0 ]; then
  echo "ERROR: No $file_type found in $PROJECT_ROOT"
  echo "For $SCAN_TYPE, please ensure test files are available:"
  case "$SCAN_TYPE" in
    "SIGNATURE_SCAN")
      if [ "${SNIPPETS}" == "yes" ]; then
        echo "  - Place *.tar.gz files in the project directory for snippet scanning"
      else
        echo "  - Place *.jar files in the project directory for signature scanning"
      fi
      ;;
    "BINARY_SCAN")
      echo "  - Place binary files (*.exe, *.tar.gz, *.tar, *.tgz, *.dmg, *.iso, *.msi, *.rpm) in the project directory"
      ;;
    "CONTAINER_SCAN")
      echo "  - Place container *.tar files in the project directory"
      ;;
  esac
  exit 1
fi

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
# while [ $pos -lt ${#jars[@]} ]
SLEEP_TIME=$((10 + $(date +%s%N) % 291)); echo "Sleeping for $SLEEP_TIME seconds"; sleep $SLEEP_TIME; echo "Woke up after sleeping";

while (( scans < MAX_SCANS ))
do
  echo "do"
  if [ "${repeating}" == "no" ] && [ "${RANDOM_SCANS}" == "yes" ]; then
    start_pos=$(( ( RANDOM % ${#files[@]} ) ))
    if [ "${SCAN_TYPE}" == "SIGNATURE_SCAN" ]; then
      num_files=$(( ( RANDOM % $MAX_COMPONENTS ) + 1 ))
      # use maximum of num_files OR MIN_COMPONENTS to set lower threshold for number of components
      num_files=$(( num_files > MIN_COMPONENTS ? num_files : MIN_COMPONENTS ))
    else
      num_files=1  # Binary and container scans typically handle one file at a time
    fi
    end=$((start_pos + num_files))
    if [ $end -gt ${#files[@]} ]
    then
      num_files=$((${#files[@]} - start_pos))
    fi
    project_files=("${files[@]:$pos:$num_files}")
    echo "start_pos: $start_pos"
    echo "num_files: $num_files"
    echo "end: $end"
    echo "files in project_files: ${#project_files[@]}"
    echo "project_files: ${project_files[@]}"
  # checking for Random Scans Flag. If the flag is set to No, components chosen to submit scans will be repeatable between releases.
  elif [  "${RANDOM_SCANS}" == "no"  ]; then
    start_pos=$((start_pos + 1))
    cl_pos=$((cl_pos + 1))

# assigning the number of components to be submitted per scan based on the total number of files available and number of components chosen by the tester.
    if [ "${SCAN_TYPE}" == "SIGNATURE_SCAN" ]; then
      num_files=$(( FIXED_COMPONENTS > ${#files[@]} ? ${#files[@]} : FIXED_COMPONENTS ))
    else
      num_files=1  # Binary and container scans typically handle one file at a time
    fi
    end=$((start_pos + num_files))

#Since the files are submitted by increasing the value of start and end index, condition is added to check
# whether the end index value reached the total number of files and if reached resetting it back to 0
    if [ $end -gt ${#files[@]} ]
    then
      start_pos=0
      end=$num_files
    fi
    #start and end index for choosing the files are assigned.
    project_files=("${files[@]:$start_pos:$num_files}")
    echo "FIXED_COMPONENTS: $FIXED_COMPONENTS"
    echo "start_pos: $start_pos"
    echo "num_files: $num_files"
    echo "end: $end"
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
        cl_name="$container_id-binary-cl-${cl_pos}"
      elif [ "${SCAN_TYPE}" == "CONTAINER_SCAN" ]; then
        cl_name="$container_id-container-cl-${cl_pos}"
      else
        cl_name="$container_id-cl-${cl_pos}"
      fi
      
      echo "code location name: $cl_name"

      mkdir -p $project_name/$cl_name
      echo "$(date '+%Y-%m-%d %H:%M:%S') - copy started"
      
      if [ "${SCAN_TYPE}" == "SIGNATURE_SCAN" ]; then
        rsync -a ${project_files[@]} $project_name/$cl_name
      elif [ "${SCAN_TYPE}" == "BINARY_SCAN" ]; then
        ln -f ${project_files[@]} $project_name/$cl_name
      elif [ "${SCAN_TYPE}" == "CONTAINER_SCAN" ]; then
        ln -f ${project_files[@]} $project_name/$cl_name
      fi
      
      echo "$(date '+%Y-%m-%d %H:%M:%S') - copy completed"

      echo "$(date '+%Y-%m-%d %H:%M:%S') - scanning"
      DETECT_OPTIONS="--blackduck.url=${BD_HUB_URL} --blackduck.api.token=${API_TOKEN}"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.project.name=${project_name} --detect.project.version.name=${v}"
      DETECT_OPTIONS="${DETECT_OPTIONS} --blackduck.trust.cert=true"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.timeout=${API_TIMEOUT}"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.tools=${SCAN_TYPE}"
      
      if [ "${SCAN_TYPE}" == "SIGNATURE_SCAN" ]; then
        DETECT_OPTIONS="${DETECT_OPTIONS} --detect.code.location.name=${cl_name}"
        DETECT_OPTIONS="${DETECT_OPTIONS} --detect.parallel.processors=-1"
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
        DETECT_OPTIONS="${DETECT_OPTIONS} --detect.code.location.name=${cl_name}"
        DETECT_OPTIONS="${DETECT_OPTIONS} --detect.parallel.processors=-1"
        DETECT_OPTIONS="${DETECT_OPTIONS} --detect.binary.scan.file.path=${project_name}/${cl_name}/${fileNames[start_pos]}"
        
      elif [ "${SCAN_TYPE}" == "CONTAINER_SCAN" ]; then
        DETECT_OPTIONS="${DETECT_OPTIONS} --detect.cleanup=false --detect.diagnostic=true"
        DETECT_OPTIONS="${DETECT_OPTIONS} --detect.container.scan.file.path=${project_files[@]}"
        #DETECT_OPTIONS="${DETECT_OPTIONS} --logging.level.detect=TRACE"
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
      bash <(curl -s -L ${DETECT_CURL_OPTS} https://detect.blackduck.com/detect10.sh) ${DETECT_OPTIONS} | tee ${detect_log}
      elapsed_time=$(get_elapsed_time $detect_log)

      echo "$(date '+%Y-%m-%d %H:%M:%S') - Elapsed time for scan was ${elapsed_time} seconds"
      WAIT_TIME=$(( TARGET_DURATION  - elapsed_time ))
      rm $detect_log

      ((scans++))
    done
    echo "$(date '+%Y-%m-%d %H:%M:%S') - looping"
  done
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Removing ${project_name}"
  rm -rf $project_name

  echo "$(date '+%Y-%m-%d %H:%M:%S') - Sleeping for ${WAIT_TIME} seconds based on the ${TARGET_DURATION} seconds per scan"
  sleep "$WAIT_TIME"
  if [ "${SCAN_TYPE}" == "CONTAINER_SCAN" ]; then
    pos=$((pos + num_files + 1))
  fi
done
