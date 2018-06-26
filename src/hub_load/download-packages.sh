#!/bin/bash
#
#

WORKDIR=$(dirname $0)
mkdir -p $WORKDIR/jars

for i in `cat $WORKDIR/packagelist`
do
  curl -s $i | tar zxvf -  -C $WORKDIR/jars
done
