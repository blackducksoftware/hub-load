#
# PgBadger to be used alongside HUB containers to collect 
# and process Postgres log data
#

FROM ubuntu:bionic

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y curl wget unzip

# need java8 to run detect
RUN apt-get install openjdk-8-jre-headless -y

ADD hub_load /home/hub_load

# download-packages downloads a collection of jar files from S3 and places them in /home/hub_load/jars
RUN chmod +x /home/hub_load/download-packages.sh
RUN cd /home/hub_load && /home/hub_load/download-packages.sh
RUN pwd
