#!/bin/bash
#
#

WORKDIR=$(dirname $0)

for i in `cat $WORKDIR/packagelist`
do
  curl -s $i | tar zxvf -  -C $WORKDIR/jars
done
