#!/bin/bash
#
#

WORKDIR=$(dirname $0)
mkdir -p $WORKDIR/jars

echo "Downloading and unpacking jars.zip from S3"
wget https://bds-sa-data-files.s3.us-east-2.amazonaws.com/jars.zip
unzip jars.zip
echo "Removing jars.zip now that we have unzipped it"
rm jars.zip

