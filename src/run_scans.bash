#!/bin/bash
  
#
# Sample script for running multiple instances of hub-load concurrently
#

NUM_SCAN_CLIENTS=${1:-5}

# Set these environment variables before running this script:
# export BD_HUB_URL=https://your-blackduck-server.com
# export API_TOKEN=your-api-token-here
export BD_HUB_URL="${BD_HUB_URL:-https://your-blackduck-server.com}"
export API_TOKEN="${API_TOKEN:?Error: API_TOKEN environment variable must be set}"
export API_TIMEOUT=600000
export MAX_SCANS=2
export MAX_VERSIONS=1
export MIN_COMPONENTS=50
export MAX_COMPONENTS=150
export REPEAT_SCAN=yes

date
echo "Launching ${NUM_SCAN_CLIENTS} hub-load instances, each will run ${MAX_SCANS} scans"
for i in $(seq ${NUM_SCAN_CLIENTS})
do
        echo "Launching hub-load instance: $i"
        docker run --rm -e BD_HUB_URL -e API_TOKEN -e API_TIMEOUT -e MAX_SCANS -e MAX_VERSIONS -e MIN_COMPONENTS -e MAX_COMPONENTS \
                -e REPEAT_SCAN gsnyderbds/hub-load /home/hub_load/submit_scans.sh > scans-$i.log 2>&1 &
        wait_time=10
        echo "Waiting $wait_time seconds to stagger start of each hub-load instance"
        sleep $wait_time
done
wait
echo "Done with all scans"
date