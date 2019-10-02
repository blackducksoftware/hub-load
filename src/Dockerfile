#
# PgBadger to be used alongside HUB containers to collect 
# and process Postgres log data
#

FROM ubuntu:bionic

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y wget unzip

ADD hub_load /home/hub_load
RUN chmod +x /home/hub_load/download-packages.sh
RUN /home/hub_load/download-packages.sh

RUN pwd
