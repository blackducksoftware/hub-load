#!/bin/bash
#
#

WORKDIR=$(dirname $0)
mkdir -p $WORKDIR/jars

for i in `cat $WORKDIR/packagelist`
do
  echo Expanding $i int $WORKDIR/jars
  curl -s $i | tar zxf -  -C $WORKDIR/jars
done
