#!/bin/bash

HUB=$1
MAX_SCANS=$2
echo "SCANS TO SUMIT = $2, ok?"
read x

echo ".............................."
OIFS=$IFS; IFS=$'\n';
jars=($(find . -name \*.jar -print))
IFS=$OIFS;

echo $jars
exit 1
echo "...................................."
suffix=j-`date +%s`

scanner="scan.cli-4.7.0/bin/scan.cli.sh"

echo "starting" 
pos=0
iscans=0
MAX_CODELOCATIONS=1
while [ $pos -lt ${#jars[@]} ]
do
  echo "do"
  num_jars=$(( ( RANDOM % 10 ) + 1 ))
  end=$((pos + num_jars))
  if [ $end -gt ${#jars[@]} ]
  then
    num_jars=$((#jars[@] - pos))
  fi
  project_jars=("${jars[@]:$pos:$num_jars}")
  project_name="joel1-proj-$(($RANDOM))-${suffix}"
  mkdir $project_name

  RANDOM=`date "+%s"`
  versions=$(( ( RANDOM % 10 ) + 1 ))
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
      cp -f ${project_jars[@]} $project_name/$cl_name

 echo "scanning"
      SCAN_CLI_OPTS=-Dspring.profiles.active=bds-disable-scan-graph BD_HUB_PASSWORD=blackduck $scanner -v --project $project_name --name $cl_name --release $v --host $HUB --port 443 --insecure --username sysadmin $project_name/$cl_name
 echo "incr"
      ((scans++))
      echo "Total scans submitted: $scans"
      if [ $scans -gt $MAX_SCANS ]
      then
        exit 0
      fi
    done
    echo "looping"
  done
  rm -rf $project_name
  pos=$((pos + num_jars + 1))
done
