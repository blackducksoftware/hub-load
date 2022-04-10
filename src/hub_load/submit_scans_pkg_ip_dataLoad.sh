#!/bin/bash
#
#  Generates and submits test loads for HUB
#

function readvar() {
  echo -n "Enter value for $1 [${!1}] "
  read temp
  if [ ! -z $temp ]; then
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

  total_elapsed_seconds=$(($hours * 3600 + $minutes * 60 + $seconds))
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
BD_HUB_URL=${BD_HUB_URL:-https://karthik-bd-xxlarge.saas-staging.blackduck.com}
API_TOKEN=${API_TOKEN:-NTJjZGVkY2EtNTQxZC00ZGUxLTg4MDYtMDU4YTk2ZjVkY2NjOmVlNWJkNjNiLTFiMjAtNGJkYS1hNmI5LWExYmY2NjY4ODgwNw==}
API_TIMEOUT=${API_TIMEOUT:-300}
MAX_SCANS=${MAX_SCANS:-3}
MAX_CODELOCATIONS=${MAX_CODELOCATIONS:-1}
MAX_VERSIONS=${MAX_VERSIONS:-1}
DETECT_VERSION=${DETECT_VERSION}
FAIL_ON_SEVERITIES=${FAIL_ON_SEVERITIES}
INSECURE_CURL=${INSECURE_CURL:-no}
WAIT_TIME=${WAIT_TIME:-30}
#TEST_DURATION=${TEST_DURATION:-0}
TARGET_DURATION=0


if [ -z "$TEST_DURATION" ]; then
  echo "Scans will be submitted as fast it can, continuing."
  exit 1
else
  #target rate / Scan
  TARGET_DURATION=$(((TEST_DURATION * 3600) / MAX_SCANS))
  echo "Scans will be submitted at the rate of 1 scan per ${TARGET_DURATION} seconds"
fi

if [ -z "${DETECT_VERSION}" ]; then
  echo "Default Detect Version"
  DETECT_VERSION="LATEST"
fi

if [ -z "${FAIL_ON_SEVERITIES}" ]; then
  echo "Default Fail on severities"
  FAIL_ON_SEVERITIES="NONE"
fi

PROJECT="Project-$HOSTNAME"
TIMESTAMP=$(date +%Y%m%d.%H%M%S)

INT_PARAMS="BD_HUB_URL API_TOKEN API_TIMEOUT MAX_SCANS MAX_CODELOCATIONS MAX_VERSIONS  DETECT_VERSION FAIL_ON_SEVERITIES INSECURE_CURL  "
if [ "$INTERACTIVE" = "yes" ]; then
  for i in $INT_PARAMS; do
    readvar $i
  done
fi

echo
echo "Submitting with the following parameters:"
echo
for i in $INT_PARAMS; do
  echo $'\t' $i ${!i}
done

echo
if [ "$INTERACTIVE" = "yes" ]; then
  continue=Y
  readvar continue
  if [[ ! "$continue" == "Y" ]]; then exit 1; fi
fi

echo Starting ...

if [ -z "$BD_HUB_URL" ]; then
  echo No Black Duck URL specified, Exiting.
  exit 1
fi

if [ -z "$API_TOKEN" ]; then
  echo No API token specified, Exiting.
  exit 1
fi


if [ "${DETECT_VERSION}" != "LATEST" ]; then
  echo "Using Detect Version ${DETECT_VERSION}"
  export DETECT_LATEST_RELEASE_VERSION=${DETECT_VERSION}
else
  echo "Using Latest Detect Version"
fi

if [ "${FAIL_ON_SEVERITIES}" != "NONE" ]; then
  echo "Using FAIL_ON_SEVERITIES ${FAIL_ON_SEVERITIES}"
else
  echo "Not specifying FAIL_ON_SEVERITIES"
fi

if [ "${INSECURE_CURL}" == "yes" ]; then
  echo "Setting environment variable DETECT_CURL_OPTS=--insecure"
  export DETECT_CURL_OPTS=--insecure
fi

#
#  Generate an array of available JAR files
#
echo ".............................."
OIFS=$IFS
IFS=$'\n'

directories=($(find . -maxdepth 4 -type d -exec ls -ld "{}" \;))
IFS=$OIFS

echo ${#directories[@]} directories  located
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

# while [ $pos -lt ${#jars[@]} ]

while ((scans < MAX_SCANS)); do
  echo "do"

    if [ $start_pos -gt ${#directories[@]} ]; then #if [ $end -gt 744 ]
      start_pos=0
    fi

    project_directory=("${directories[@]:start_pos:start_pos}")
    echo "start_pos: $start_pos"
    echo "project_directory: $project_directory"
    echo "project_jars: ${project_directory[@]}"


  project_name="$PROJECT-$(($RANDOM))-on-${TIMESTAMP}"
  echo "project_name: ${project_name}"
  mkdir $project_name

  RANDOM=$(date "+%s")
  versions=$(((RANDOM % $MAX_VERSIONS) + 1))

  for ((v = 1; v <= $versions; v++)); do
    echo "version: $v"
    num_codelocations=$MAX_CODELOCATIONS

    for ((cl = 0; cl < $num_codelocations; cl++)); do
      echo "code location: $((cl + 1))"
      RANDOM=$(date "+%s")
      container_id=`cat /etc/hostname`
      echo "Container ID: $container_id"
      cl_name="$container_id-cl-${cl_pos}"
      echo "code location name: $cl_name"
      # echo "1"
      # set +e


      echo "scanning"
      DETECT_OPTIONS="--blackduck.url=${BD_HUB_URL} --blackduck.api.token=${API_TOKEN}"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.project.name=${project_name} --detect.project.version.name=${v}"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.code.location.name=${cl_name}"
      DETECT_OPTIONS="${DETECT_OPTIONS} --blackduck.trust.cert=true"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.timeout=${API_TIMEOUT}"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.gradle.include.unresolved.configurations=true --detect.detector.buildless=true"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.detector.search.depth=20"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.tools=DETECTOR"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.source.path=${project_directory[@]}"


      detect_log=/tmp/detect_$$.log
      echo "Final Detect Options: $DETECT_OPTIONS"
      #bash <(curl -s -L ${DETECT_CURL_OPTS} https://detect.synopsys.com/detect.sh) ${DETECT_OPTIONS} | tee ${detect_log}
      elapsed_time=$(get_elapsed_time $detect_log)
      echo "Elapsed time for scan was ${elapsed_time} seconds"
      WAIT_TIME=$(( TARGET_DURATION  - elapsed_time ))
      rm $detect_log
      ((scans++))
    done
    echo "looping"
  done
  echo "Removing ${project_name}"
  rm -rf $project_name
  echo "Sleeping for ${WAIT_TIME} seconds based on the ${TARGET_DURATION} seconds per scan"
  sleep "$WAIT_TIME"
  # pos=$((pos + num_jars + 1))
done
