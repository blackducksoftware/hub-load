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
BD_HUB_URL=${BD_HUB_URL:-https://resource-2022-4-2.saas-staging.blackduck.com}
API_TOKEN=${API_TOKEN:-NTJjZGVkY2EtNTQxZC00ZGUxLTg4MDYtMDU4YTk2ZjVkY2NjOmVlNWJkNjNiLTFiMjAtNGJkYS1hNmI5LWExYmY2NjY4ODgwNw==}
API_TIMEOUT=${API_TIMEOUT:-120}
MAX_SCANS=${MAX_SCANS:-3}
FIXED_COMPONENTS=${FIXED_COMPONENTS:-10}
DETECT_VERSION=${DETECT_VERSION:-8.2.0}
INSECURE_CURL=${INSECURE_CURL:-no}
MAX_CODELOCATIONS=${MAX_CODELOCATIONS:-1}

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

INT_PARAMS="BD_HUB_URL API_TOKEN API_TIMEOUT MAX_SCANS  DETECT_VERSION FAIL_ON_SEVERITIES INSECURE_CURL FIXED_COMPONENTS"

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
jars=($(find . -name \*.jar -print | sort -V))
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
#num_jars=100
end=10
# while [ $pos -lt ${#jars[@]} ]

while (( scans < MAX_SCANS ))
do
  echo "do"
  # components chosen to submit scans will be repeatable between releases.
    start_pos=$((start_pos + 1))
    cl_pos=$((cl_pos + 1))

# assigning the number of components to be submitted per scan based on the total number of jar files available and number of components chosen by the tester.
    num_jars=$(( FIXED_COMPONENTS > ${#jars[@]} ? ${#jars[@]} : FIXED_COMPONENTS ))
    end=$((start_pos + num_jars))


# Since the jar files files are submitted by increasing the value of start and end index, condition is added to check
# whether the end index value reached the total number of files and if reached resetting it back to 0
    if [ $end -gt ${#jars[@]} ]
    #if [ $end -gt 744 ]
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


  project_name="$PROJECT-$(($RANDOM))-on-${TIMESTAMP}"
  echo "project_name: ${project_name}"
  mkdir $project_name

  RANDOM=`date "+%s"`

    num_codelocations=$MAX_CODELOCATIONS

    for ((cl=0; cl<$num_codelocations;cl++))
    do
      echo "code location: $(( cl + 1 ))"
      RANDOM=`date "+%s"`
      container_id=`cat /etc/hostname`
      echo "Container ID: $container_id"
      cl_name="$container_id-cl-${cl_pos}"
      echo "code location name: $cl_name"
      # echo "1"
      # set +e

      mkdir -p $project_name/$cl_name
      echo "copy"
      ln -f ${project_jars[@]} $project_name/$cl_name

      echo "scanning"
      DETECT_OPTIONS="--blackduck.url=${BD_HUB_URL} --blackduck.api.token=${API_TOKEN}"
      DETECT_OPTIONS="${DETECT_OPTIONS} --blackduck.trust.cert=true"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.timeout=${API_TIMEOUT}"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.parallel.processors=-1"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.tools=SIGNATURE_SCAN"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.source.path=${project_name}/${cl_name}"
      DETECT_OPTIONS="${DETECT_OPTIONS} --detect.wait.for.results=true --detect.blackduck.scan.mode=EPHEMERAL"
      detect_log=/tmp/detect_$$.log
      echo "Final Detect Options: $DETECT_OPTIONS"
      bash <(curl -s -L ${DETECT_CURL_OPTS} https://detect.synopsys.com/detect.sh) ${DETECT_OPTIONS} | tee ${detect_log}
      elapsed_time=$(get_elapsed_time $detect_log)
      echo "Elapsed time for scan was ${elapsed_time} seconds"
      rm $detect_log
      ((scans++))
    echo "looping"
  done
  echo "Removing ${project_name}"
  rm -rf $project_name
  # pos=$((pos + num_jars + 1))
done