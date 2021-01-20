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
  hours=$(echo $duration_line | awk '{print $8}' | sed -e "s/h//")
  # echo "Hours: $hours"  1>&2
  minutes=$(echo $duration_line | awk '{print $9}' | sed -e "s/m//")
  # echo "Minutes: $minutes"  1>&2
  seconds=$(echo $duration_line | awk '{print $10}' | sed -e "s/s//")
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
BD_TIMEOUT=${BD_TIMEOUT:-120}
API_TIMEOUT=${API_TIMEOUT:-300}
MAX_SCANS=${MAX_SCANS:-10}
MAX_CODELOCATIONS=${MAX_CODELOCATIONS:-1}
MAX_COMPONENTS=${MAX_COMPONENTS:-400}
MIN_COMPONENTS=${MIN_COMPONENTS:-200}
MAX_VERSIONS=${MAX_VERSIONS:-5}
SYNCHRONOUS_SCANS=${SYNCHRONOUS_SCANS:-yes}
REPEAT_SCAN=${REPEAT_SCAN:-no}
DETECT_VERSION=${DETECT_VERSION:"LATEST"}


PROJECT="Project-$HOSTNAME"
TIMESTAMP=$(date +%Y%m%d.%H%M%S)

INT_PARAMS="BD_HUB_URL API_TOKEN BD_TIMEOUT API_TIMEOUT MAX_SCANS MAX_CODELOCATIONS MIN_COMPONENTS MAX_COMPONENTS MAX_VERSIONS REPEAT_SCAN SYNCHRONOUS_SCANS DETECT_VERSION"

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

#
#  Generate an array of available JAR files
#
echo ".............................."
OIFS=$IFS; IFS=$'\n';
jars=($(find . -name \*.jar -print))
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
# while [ $pos -lt ${#jars[@]} ]

while (( scans < MAX_SCANS ))
do
  echo "do"
  if [ "${repeating}" == "no" ]; then
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
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.report.timeout=${API_TIMEOUT}"
      DETECT_OPTIONS="${DETECT_OPTIONS} --blackduck.timeout=${BD_TIMEOUT}"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.parallel.processors=-1"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.tools=SIGNATURE_SCAN"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.source.path=${project_name}/${cl_name}"
      if [ "${SYNCHRONOUS_SCANS}" == "yes" ]; then
        DETECT_OPTIONS="${DETECT_OPTIONS} --detect.policy.check.fail.on.severities=ALL"
      fi
      detect_log=/tmp/detect_$$.log
      bash <(curl -s -L https://detect.synopsys.com/detect.sh) ${DETECT_OPTIONS} | tee ${detect_log}
      elapsed_time=$(get_elapsed_time $detect_log)
      echo "Elapsed time for scan was ${elapsed_time} seconds"
      rm $detect_log

      ((scans++))
    done
    echo "looping"
  done
  echo "Removing ${project_name}"
  rm -rf $project_name
  # pos=$((pos + num_jars + 1))
done
