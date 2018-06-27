# HUB Load

Containerized version of hub_load package provied by OPS team (joel)
Generates large anounts of HUB projects with versions and components.

## Usage

Container will look for the following environment variables. Default values could be overriden as necessary


```
Variable              Default Value
--------------------- -------------
BD_HUB                  
BD_HUB_USER           sysadmin
BD_HUB_PASS           blackduck
MAX_SCANS             10
MAX_CODELOCATIONS     1
MAX_COMPONENTS        100
MAX_VERSIONS          20
```

### Non-interactive invocation

Submitting scans with default parameters to . testhub.blackducksoftware.com 
```
docker run --rm -e BD_HUB=testhub.blackducksoftware.com hub-load /home/hub_load/submit_scans.sh
```

### Interactive invocaion

```
$ docker run -it hub-load
root@60f526a5f9fc:/# INTERACTIVE=yes /home/hub_load/submit_scans.sh
Enter value for BD_HUB []ip-172-31-8-206.ec2.internal
Enter value for BD_HUB_USER [sysadmin]
Enter value for BD_HUB_PASS [blackduck]
Enter value for MAX_SCANS [10]
Enter value for MAX_CODELOCATIONS [1]
Enter value for MAX_COMPONENTS [100]
Enter value for MAX_VERSIONS [20]
BD_HUB ip-172-31-8-206.ec2.internal
BD_HUB_USER sysadmin
BD_HUB_PASS blackduck
MAX_SCANS 10
MAX_CODELOCATIONS 1
MAX_COMPONENTS 100
MAX_VERSIONS 20
. . .
```


## Building from source

```
git clone https://github.com/blackducksoftware/hub-load.git
cd hub-load/src
docker build -t <container tag> . 
```

Note: Build  process will download archives listed in hub-load/src/packagelist. This will result in a container ~5GB in size. 
