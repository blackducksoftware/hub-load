#!/bin/bash
  
#
# Sample script for running container scan of hub-load
# sh hub-load_container.sh MAX_SCANS="3" TEST_DURATION="3" IMAGE_PATH="http://sig-os192113060/prasad-sca-test-data/container.zip" BD_HUB_URL="dummy_url" API_TOKEN="dummytoken"
#


for ARGUMENT in "$@"
do
   KEY=$(echo $ARGUMENT | cut -f1 -d=)

   KEY_LENGTH=${#KEY}
   VALUE="${ARGUMENT:$KEY_LENGTH+1}"

   export "$KEY"="$VALUE"
done

# use here your expected variables

echo "BD_HUB_URL = $BD_HUB_URL"
echo "API_TOKEN = "****************""
echo "MAX_SCANS = $MAX_SCANS"
echo "TEST_DURATION = $TEST_DURATION"
echo "IMAGE_PATH = $IMAGE_PATH"


#Need jq command for edit yaml file

snap install yq


#clone hub-load

git clone https://github.com/blackducksoftware/hub-load.git

cd hub-load

git checkout perflab_container

git pull


#go to hub-load/src folder for edit yaml file to

#Accept parameters like Max scans , / Hour Test Duration

cd src


export huburl="BD_HUB_URL=$BD_HUB_URL"
export apitoken="API_TOKEN=$API_TOKEN"
export maxscan="MAX_SCAN=$MAX_SCANS"
export testduration="TEST_DURATION=$TEST_DURATION"


yq e -i '.services.hub-load.environment.0 = env(huburl)' hubload-latest.yaml

yq e -i '.services.hub-load.environment.1 = env(apitoken)' hubload-latest.yaml

yq e -i '.services.hub-load.environment.3 = env(maxscan)' hubload-latest.yaml

yq e -i '.services.hub-load.environment.8 = env(testduration)' hubload-latest.yaml



#download images under folder hub-load/src/hub_load/images/

if [ -z "$IMAGE_PATH" ]
  then
    export IMAGE_PATH="http://sig-os192113060.internal.synopsys.com:8082/artifactory/prasad-sca-test-data/container.zip"
    echo "no image path passing its take default image path $IMAGE_PATH"
 

fi

#remove image folder

rm -rf hub_load/images

echo "downloading images from  $IMAGE_PATH"

wget $IMAGE_PATH

unzip -q container.zip

mv container/images hub_load

rm -rf container container.zip

# build the hub-load

docker stack rm hubload-latest

docker build -t hubload-latest .

docker stack deploy -c hubload-latest.yaml hubload-latest







