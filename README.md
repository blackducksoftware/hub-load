# HUB Load

Containerized version of hub_load package provided by OPS team (joel)
Generates large amounts of HUB projects with versions and components.

**Enhanced Version**: Now supports SIGNATURE_SCAN, BINARY_SCAN, and CONTAINER_SCAN in a unified script.

### Pull command

Container is available from gcr.io
```
docker pull gsasig/hub-load
```

## Usage

Container will look for the following environment variables. Default values could be overriden as necessary

| Variable          | Description (default)                                        |
| ----------------- | ------------------------------------------------------------ |
| **SCAN_TYPE**     | **Scan type: SIGNATURE_SCAN, BINARY_SCAN, or CONTAINER_SCAN (SIGNATURE_SCAN)** |
| BD_HUB_URL        | The Black Duck URL (None)                                    |
| API_TOKEN         | An API token with sufficient rights to perform scans and create project-versions(None) |
| API_TIMEOUT       | The Synopsys detect timeout value (300). This value is passed to --detect.timeout on Synopsys detect |
| MAX_SCANS         | Maximum number of scans to perform before quitting (3)       |
| SNIPPETS          | For SIGNATURE_SCAN: Perform source code scan with snippets (no) |
| STRING_SEARCH     | For SIGNATURE_SCAN: Enable license/copyright string search (no) |
| MAX_CODELOCATIONS | Maximum number of code locations per version (1)             |
| MIN_COMPONENTS    | For SIGNATURE_SCAN: Minimum number of randomly selected components (200) |
| MAX_COMPONENTS    | For SIGNATURE_SCAN: Maximum number of randomly selected components (400) |
| FIXED_COMPONENTS  | Number of components per scan - signature: 100, binary/container: 1 |
| MAX_VERSIONS      | Maximum number of versions per project (1)                   |
| REPEAT_SCAN       | If 'yes' repeat the scan using the same components each time (no) |
| RANDOM_SCANS      | If 'yes' use random component selection (no)                 |
| SYNCHRONOUS_SCANS | If 'yes' will pass --detect.wait.for.results=true to Detect (yes) |
| TEST_DURATION     | Duration in hours for test execution (1)                     |
| FAIL_ON_SEVERITIES | If passed in will do a policy check for the specified severity (NONE) |
| DETECT_VERSION    | The Detect Version to use, you can specify the version e.g. 6.5.0 or if omitted will use the latest (LATEST) |
| INSECURE_CURL     | Whether to use CURL in --insecure mode for Detect and downloading Detect (no) |
| DEBUG             | Enable debug logging with TRACE level (no)                   |

### Non-interactive invocation

#### Signature Scans (default)
```bash
$ docker run --rm -e BD_HUB_URL=https://testhub.blackducksoftware.com \
                   -e API_TOKEN=<the-token> \
                   gsasig/hub-load \
                   /home/hub_load/submit_scans_fixed.sh
```

#### Binary Scans
```bash
$ docker run --rm -e SCAN_TYPE=BINARY_SCAN \
                   -e BD_HUB_URL=https://testhub.blackducksoftware.com \
                   -e API_TOKEN=<the-token> \
                   -e MAX_SCANS=5 \
                   gsasig/hub-load \
                   /home/hub_load/submit_scans_fixed.sh
```

#### Container Scans
```bash
$ docker run --rm -e SCAN_TYPE=CONTAINER_SCAN \
                   -e BD_HUB_URL=https://testhub.blackducksoftware.com \
                   -e API_TOKEN=<the-token> \
                   -e MAX_SCANS=3 \
                   gsasig/hub-load \
                   /home/hub_load/submit_scans_fixed.sh
```

#### Custom Parameters Example
```bash
$ docker run --rm -e SCAN_TYPE=SIGNATURE_SCAN \
                 -e BD_HUB_URL=https://testhub.blackducksoftware.com \
                 -e API_TOKEN=<the-token> \
                 -e MAX_SCANS=1 \
                 -e SNIPPETS=yes \
                 gsasig/hub-load \
                 /home/hub_load/submit_scans_fixed.sh

Processing defaults

Submitting with the following parameters:

	 BD_HUB_URL https://ip-172-31-8-206.ec2.internal
	 API_TOKEN the-token
	 MAX_SCANS 1
	 MAX_CODELOCATIONS 1
	 MAX_COMPONENTS 150
	 MAX_VERSIONS 5
	 SYNCHRONOUS_SCANS yes

Starting ...
...
...
Total scans submitted: 1
$
```

### Interactive invocaion

```
$ docker run -it --rm -e BD_HUB_URL=https://testhub.blackducksoftware.com \
                      -e API_TOKEN=<the-token> \
                      -e MAX_SCANS=1 \
                      gsasig/hub-load
root@714cf6d9a957:/# INTERACTIVE=yes /home/hub_load/submit_scans.sh 

Processing defaults

Enter value for BD_HUB_URL [https://testhub.blackducksoftware.com] 
Enter value for API_TOKEN [the-token] 
Enter value for MAX_SCANS [1] 
Enter value for MAX_CODELOCATIONS [1] 
Enter value for MAX_COMPONENTS [150] 
Enter value for MAX_VERSIONS [5] 
Enter value for SYNCHRONOUS_SCANS [yes]

Submitting with the following parameters:

	 BD_HUB_URL https://testhub.blackducksoftware.com
	 API_TOKEN the-token
	 MAX_SCANS 1
	 MAX_CODELOCATIONS 1
	 MAX_COMPONENTS 150
	 MAX_VERSIONS 5
	 SYNCHRONOUS_SCANS yes

Enter value for continue [Y] 
Starting ...
...
```


## Building from source

```
git clone https://github.com/blackducksoftware/hub-load.git
cd hub-load/src
docker build -t <container tag> . 
```

Note: Build process will download archives listed in hub-load/src/packagelist. This will result in a container ~5GB in size.

## Deployment using Docker Compose/Swarm

### Multi-Service Deployment (All Scan Types)
Deploy all three scan types simultaneously:
```bash
cd src
docker stack deploy -c hubload-latest.yaml hubload
```
This creates three services:
- `hubload_hub-load-signature` - Signature scans (2 replicas)
- `hubload_hub-load-binary` - Binary scans (1 replica) 
- `hubload_hub-load-container` - Container scans (1 replica)

### Single-Service Deployment
Deploy one scan type at a time:
```bash
cd src
# Edit hubload-single-service.yaml to set desired SCAN_TYPE
docker stack deploy -c hubload-single-service.yaml hubload-single
```

### Environment Configuration
Before deployment, update the YAML files with your Black Duck instance details:
- Set `BD_HUB_URL` to your Black Duck server URL
- Set `API_TOKEN` to a valid API token
- Adjust `MAX_SCANS`, `replicas`, and other parameters as needed

### Scaling Services
```bash
# Scale signature scanning service to 5 replicas
docker service scale hubload_hub-load-signature=5

# Scale binary scanning service to 2 replicas  
docker service scale hubload_hub-load-binary=2
``` 

# Releases

- Aug 19, 2025
  - **Enhanced Multi-Scan Type Support**: Unified submit_scans_fixed.sh script now supports SIGNATURE_SCAN, BINARY_SCAN, and CONTAINER_SCAN
  - Added SCAN_TYPE environment variable for easy scan type selection
  - Updated deployment configurations with multi-service YAML (hubload-latest.yaml) and single-service YAML (hubload-single-service.yaml) 
  - Improved file discovery and error handling for different scan types
  - Added comprehensive help documentation and usage examples
  - Maintained backward compatibility with existing deployments

- Aug 14, 2023
  - Updated base image to ubuntu:jammy
  - Updated Java to version 17
  - Added sourece code data to enable snippet scan functionality
  - Added snippet scan capbility
     
- Mar 22, 2021
  - Updated detect.timeout parameter due to old options being deprecated
  - Added INSECURE_CURL option to pass --insecure to curl inside the script and within Synopsys Detect.  By default this is 'no'.
 
- Mar 8, 2021
  - Added FAIL_ON_SEVERITIES to make it possible to specify the level of policy check to apply to cause failures.

- Jan 20, 2021
  - Added DETECT_VERSION so you can specify the version of Synopsys Detect.  However be aware that parameters change over time and so may not be compatible with the parameters being passed via submit_scans.sh.

- Oct 2, 2019
  - Switching from scan.cli.sh to Synopsys Detect
  - Updating defaults as appropriate
  - Switching from username/password to api_token
  - Added support for repeating the scan on the same set of components/jars
  - Added elapsed time in seconds which is scraped from detect log output
  - Added support for synchronous scans
  - Replaced the component/jar download to use a much larger collection (>7000) of jars hosted on S3
