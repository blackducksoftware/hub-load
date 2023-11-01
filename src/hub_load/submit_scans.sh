#!/bin/bash
#
#  Generates and submits test loads for HUB
#

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

  total_elapsed_seconds=$(( $hours * 3600 + $minutes * 60 + $seconds))
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
#BD_HUB_URL=https://karthik-bd-med.saas-staging.blackduck.com
#API_TOKEN=MzhjNTliNGYtYTk5Mi00NTI3LThjNDEtNmNiMjA4NDZmNjdiOmRiNmIxYTM4LTgxOWEtNGUwNC1iZWY3LWU4Y2Q3YTFiODhlNQ==
BD_HUB_URL=https://broadcom-sw-clone-2023-08-17.saas-staging.blackduck.com
API_TOKEN=NjJlNTRlNDAtZDI2MS00NzVmLTkxODktZjA4OWZmYzk4ZjcwOjc0ZjRmOGZkLWVmNzEtNDdlMi1iM2VhLWZhMzJiYmEzM2FkNA==
API_TIMEOUT=${API_TIMEOUT:-300}
MAX_SCANS=${MAX_SCANS:-10}
SNIPPETS=${SNIPPETS:-yes}
MAX_CODELOCATIONS=${MAX_CODELOCATIONS:-1}
MAX_COMPONENTS=${MAX_COMPONENTS:-400}
MIN_COMPONENTS=${MIN_COMPONENTS:-200}
FIXED_COMPONENTS=${FIXED_COMPONENTS:-20}
MAX_VERSIONS=${MAX_VERSIONS:-5}
if [ "${SNIPPETS}" == "yes" ]; then
    MAX_COMPONENTS=${MAX_COMPONENTS:-15}
    MIN_COMPONENTS=${MIN_COMPONENTS:-10}
    FIXED_COMPONENTS=${FIXED_COMPONENTS:-20}
    MAX_VERSIONS=${MAX_VERSIONS:-5}
fi
SYNCHRONOUS_SCANS=${SYNCHRONOUS_SCANS:-no}
REPEAT_SCAN=${REPEAT_SCAN:-no}
RANDOM_SCANS=${RANDOM_SCANS:-no}
DETECT_VERSION=${DETECT_VERSION}
FAIL_ON_SEVERITIES=${FAIL_ON_SEVERITIES}
INSECURE_CURL=${INSECURE_CURL:-no}
SNIPPETS=${SNIPPETS:-no}
WAIT_TIME=${WAIT_TIME:-30}
TEST_DURATION=${TEST_DURATION:-1}
TARGET_DURATION=0

if [ -z "$TEST_DURATION" ]; then
  echo "Scans will be submitted as fast it can, continuing."
  exit 1
else
#target rate / Scan
TARGET_DURATION=$(((TEST_DURATION * 3600) / MAX_SCANS))
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

INT_PARAMS="BD_HUB_URL API_TOKEN API_TIMEOUT FIXED_COMPONENTS SNIPPETS MAX_SCANS MAX_CODELOCATIONS MIN_COMPONENTS MAX_COMPONENTS MAX_VERSIONS REPEAT_SCAN SYNCHRONOUS_SCANS DETECT_VERSION FAIL_ON_SEVERITIES INSECURE_CURL"

if [ "$INTERACTIVE" = "yes" ]
then
   for i in $INT_PARAMS
   do
     readvar $i
   done
fi

echo 
echo "Submitting with the following parameters:"
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

echo Starting ...

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

#
#  Generate an array of available JAR files
#
echo ".............................."
OIFS=$IFS; IFS=$'\n';
if [ "${SNIPPETS}" == "yes" ]
then
	jars=($(find . -name \*.tar.gz -print))
else
	jars=($(find . -name \*.jar -print))
fi
IFS=$OIFS;

echo ${#jars[@]} jar files located
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
end=10
# while [ $pos -lt ${#jars[@]} ]

while (( scans < MAX_SCANS ))
do
  echo "do"
  if [ "${repeating}" == "no" ] && [ "${RANDOM_SCANS}" == "yes" ]; then
    start_pos=$(( ( RANDOM % ${#jars[@]} ) ))
    num_jars=$(( ( RANDOM % $MAX_COMPONENTS ) + 1 ))
    # use maximum of num_jars OR MIN_COMPONENTS to set lower threshold for number of components
    num_jars=$(( num_jars > MIN_COMPONENTS ? num_jars : MIN_COMPONENTS ))
    end=$((start_pos + num_jars))
    if [ $end -gt ${#jars[@]} ]
    then
      num_jars=$((${#jars[@]} - start_pos))
    fi
    project_jars=("${jars[@]:$pos:$num_jars}")
    echo "start_pos: $start_pos"
    echo "num_jars: $num_jars"
    echo "end: $end"
    echo "jars in project_jars: ${#project_jars[@]}"
    echo "project_jars: ${project_jars[@]}"
  # checking for Random Scans Flag. If the flag is set to No, components chosen to submit scans will be repeatable between releases.
  elif [  "${RANDOM_SCANS}" == "no"  ]; then
  start_pos=$((start_pos + 1))
  cl_pos=$((cl_pos + 1))

  # assigning the number of components to be submitted per scan based on the total number of jar files available and number of components chosen by the tester.
  num_jars=$(( FIXED_COMPONENTS > ${#jars[@]} ? ${#jars[@]} : FIXED_COMPONENTS ))
  end=$((start_pos + num_jars))

  #Since the jar files files are submited by increasing the value of start and end index, condition is added to check
  # whether the end index value reached the total number of files and if reached resetting it back to 0
  if [ $end -gt ${#jars[@]} ]
  then
  start_pos=0
  end=$num_jars
  fi
  #start and end index for choosing the jars are assigned.
  project_jars=("${jars[@]:$start_pos:$num_jars}")
  echo "FIXED_COMPONENTS: $FIXED_COMPONENTS"
  echo "start_pos: $start_pos"
  echo "num_jars: $num_jars"
  echo "end: $end"
  echo "jars in project_jars: ${#project_jars[@]}"
  echo "project_jars: ${project_jars[@]}"

  fi

  repeating=${REPEAT_SCAN}

  project_name="$PROJECT-$(($RANDOM))-on-${TIMESTAMP}"
  echo "project_name: ${project_name}"
  mkdir $project_name

  RANDOM=`date "+%s"`
  versions=$(( ( RANDOM % $MAX_VERSIONS ) + 1 ))
  for ((v=1; v<=$versions;v++))
  do
    echo "version: $v"
    num_codelocations=$(( ( RANDOM % 10 ) + 1 ))
    # We don't want to overload code-locations unnecessafily.
    # Theres enough slowness as is.  MAX_CODELOCATIONS is a good handbrake
    if [ $num_codelocations -gt $MAX_CODELOCATIONS ]
    then 
      num_codelocations=1
    fi
    for ((cl=0; cl<$num_codelocations;cl++))
    do
      echo "code location: $(( cl + 1 ))"
      RANDOM=`date "+%s"`
      cl_name="${project_name}-v${v}-cl-$((RANDOM))"
      echo "code location name: $cl_name"
      # echo "1"
      # set +e

      mkdir -p $project_name/$cl_name
      echo "copy"
      ln -f ${project_jars[@]} $project_name/$cl_name

      echo "scanning"
      DETECT_OPTIONS="--blackduck.url=${BD_HUB_URL} --blackduck.api.token=${API_TOKEN}"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.project.name=${project_name} --detect.project.version.name=${v}"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.code.location.name=${cl_name}"
      DETECT_OPTIONS="${DETECT_OPTIONS} --blackduck.trust.cert=true"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.timeout=${API_TIMEOUT}"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.parallel.processors=-1"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.tools=SIGNATURE_SCAN"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.source.path=${project_name}/${cl_name}"
      if  [ "${SNIPPETS}" == "yes" ]; then
	      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.blackduck.signature.scanner.snippet.matching=SNIPPET_MATCHING"
	      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.blackduck.signature.scanner.upload.source.mode=true"
      fi
      if [ "${SYNCHRONOUS_SCANS}" == "yes" ]; then
        DETECT_OPTIONS="${DETECT_OPTIONS} --detect.wait.for.results=true"
      fi
      if [ "${FAIL_ON_SEVERITIES}" != "NONE" ]; then
        DETECT_OPTIONS="${DETECT_OPTIONS} --detect.policy.check.fail.on.severities=${FAIL_ON_SEVERITIES}"
      fi
      detect_log=/tmp/detect_$$.log
      bash <(curl -s -L ${DETECT_CURL_OPTS} https://detect.synopsys.com/detect8.sh) ${DETECT_OPTIONS} | tee ${detect_log}
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
