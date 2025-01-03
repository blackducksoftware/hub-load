#
# PgBadger to be used alongside HUB containers to collect 
# and process Postgres log data
#

FROM ubuntu:focal

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y curl wget unzip rsync openjdk-17-jre-headless && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ADD hub_load /home/hub_load

# download-packages downloads a collection of jar files from S3 and places them in /home/hub_load/jars
RUN chmod +x /home/hub_load/download-packages.sh
RUN cd /home/hub_load && /home/hub_load/download-packages.sh
RUN chmod +x /home/hub_load/submit_scans_fixed.sh
RUN pwd
