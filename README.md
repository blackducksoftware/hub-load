# HUB Load

Containerized version of hub_load package provied by OPS team (joel)
Generates large anounts of HUB projects with versions and components.

### Pull command

Container is available from gcr.io
```
docker pull gcr.io/gke-verification/github-blackducksoftware-hub-load:master
```

## Usage

Container will look for the following environment variables. Default values could be overriden as necessary

| Variable          | Description (default)                                        |
| ----------------- | ------------------------------------------------------------ |
| BD_HUB_URL        | The Black Duck URL (None)                                    |
| API_TOKEN         | An API token with sufficient rights to perform scans and create project-versions(None) |
| MAX_SCANS         | Maximum number of scans to perform before quitting (10)      |
| MAX_CODELOCATIONS | Maximum number of code locations per version (1)             |
| MAX_COMPONENTS    | Maximum number of randomly selected components (150)         |
| MAX_VERSIONS      | Maximum number of versions per project (5)                   |
| REPEAT_SCAN       | If 'yes' repeat the scan using the same components each time (no) |
| SYNCHRONOUS_SCANS | If 'yes' do a policy check to force detect to wait for scan processing to finish, otherwise do asynchronous scan (yes) |

### Non-interactive invocation

Submitting scans with default parameters to . testhub.blackducksoftware.com 
```
$ docker run --rm -e BD_HUB_URL=https:///testhub.blackducksoftware.com \
									-e API_TOKEN=<the-token>
                    gcr.io/gke-verification/github-blackducksoftware-hub-load:master \
		    /home/hub_load/submit_scans.sh
```

Submitting scans overriding default parameters 

```
$ docker run --rm -e BD_HUB=testhub.blackducksoftware.com \
										-e API_TOKEN=<the-token> \
                    -e MAX_SCANS=1 \
                    gcr.io/gke-verification/github-blackducksoftware-hub-load:master \
		    /home/hub_load/submit_scans.sh

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
                      gcr.io/gke-verification/github-blackducksoftware-hub-load:master
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

Note: Build  process will download archives listed in hub-load/src/packagelist. This will result in a container ~5GB in size. 

# Releases

- Oct 2, 2019
  - Switching from scan.cli.sh to Synopsys Detect
  - Updating defaults as appropriate
  - Switching from username/password to api_token
  - Added support for repeating the scan on the same set of components/jars
  - Added elapsed time in seconds which is scraped from detect log output
  - Added support for synchronous scans
  - Replaced the component/jar download to use a much larger collection (>7000) of jars hosted on S3