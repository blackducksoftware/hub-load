#!/bin/bash
#
#  Generates and submits test loads for HUB
#

# Set woring directory
#
WORKDIR=$(dirname $0)
cd $WORKDIR

#
BD_HUB_USER=sysadmin
BD_HUB_PASS=blackduck
MAX_SCANS=10
MAX_CODELOCATIONS=1
MAX_COMPONENTS=100
MAX_VERSIONS=20
SCANNER_OPTS=-Dspring.profiles.active=bds-disable-scan-graph
SCANNER_AUTH="BD_HUB_PASSWORD=blackduck $scanner -v --project $project_name --name $cl_name --release $v --host $HUB --port 443 --insecure --username sysadmin $project_name/$cl_name"
PROJECT="Project-$HOSTNAME"
TIMESTAMP=$(date +%Y%m%d.%H%M%S)

if [ "$BD_HUB" = "" ]
then
   echo -n "Enter HUB hostname [$BD_HUB] " 
   read BD_HUB
fi

#
#  Validate and or download the scanner
#
#
if [ ! -s scannercmd ]
then
   SCAN_PACKAGE="https://$BD_HUB/download/scan.cli.zip"
   curl -k -o scan.cli.zip $SCAN_PACKAGE
   unzip scan.cli.zip 
   find . -name scan.cli.sh | head -n 1 > scannercmd
fi

SCANNER=$(cat scannercmd)

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
while [ $pos -lt ${#jars[@]} ]
do
  echo "do"
  num_jars=$(( ( RANDOM % $MAX_COMPONENTS ) + 1 ))
  end=$((pos + num_jars))
  if [ $end -gt ${#jars[@]} ]
  then
    num_jars=$((#jars[@] - pos))
  fi
  project_jars=("${jars[@]:$pos:$num_jars}")
  project_name="$PROJECT-$(($RANDOM))-on-${TIMESTAMP}"
  mkdir $project_name

  RANDOM=`date "+%s"`
  versions=$(( ( RANDOM % $MAX_VERSIONS ) + 1 ))
  for ((v=1; v<=$versions;v++))
  do
    echo "do agian"
    num_codelocations=$(( ( RANDOM % 10 ) + 1 ))
    # We don't want to overload code-locations unnecessafily.
    # Theres enough slowness as is.  MAX_CODELOCATIONS is a good handbrake
    if [ $num_codelocations -gt $MAX_CODELOCATIONS ]
    then 
      num_codelocations=1
    fi
    for ((cl=0; cl<$num_codelocations;cl++))
    do
      echo "here we goooo"
      RANDOM=`date "+%s"`
      cl_name="codelocation-$((RANDOM))"
      echo "1"
      set +e

      mkdir -p $project_name/$cl_name
      echo "copy"
      ln -f ${project_jars[@]} $project_name/$cl_name

      echo "scanning"
      SCAN_CLI_OPTS=-Dspring.profiles.active=bds-disable-scan-graph BD_HUB_PASSWORD=blackduck $SCANNER -v --project $project_name --name $cl_name --release $v --host $BD_HUB --port 443 --insecure --username sysadmin $project_name/$cl_name
 echo "incr"
      ((scans++))
      echo "Total scans submitted: $scans"
      if [ $scans -ge $MAX_SCANS ]
      then
        exit 0
      fi
    done
    echo "looping"
  done
  rm -rf $project_name
  pos=$((pos + num_jars + 1))
done
