#!/bin/bash
#
#

WORKDIR=$(dirname $0)
mkdir -p $WORKDIR/jars

#
# if the jars directory already exists it is assumed that you have created and populated the jars
# directory locally (not in git) with a bunch of jars that will be used when creating the docker image
# by virtue of the ADD directive which will add the jars directory to the image
#
# Otherwise, this script will pull down a jars.zip from S3 and unpack it to populate the jars directory
# on the image by running this script in the docker build
#
if [ ! -d jars ]; then
	echo "Downloading and unpacking jars.zip from S3"
	wget https://bds-sa-data-files.s3.us-east-2.amazonaws.com/jars.zip
	unzip jars.zip
	echo "Removing jars.zip now that we have unzipped it"
	rm jars.zip
fi

