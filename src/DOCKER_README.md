# Docker Setup for Hub Load Testing with Memory Mapping and GCS

This guide explains how to run the Hub Load testing with memory mapping and GCS integration using Docker.

## Quick Start

### 1. Build the Docker Image

```bash
cd /Users/karth/Library/CloudStorage/OneDrive-BlackDuckSoftware/Documents/Automation/blackducksoftware/hub-load/src
docker build -t hub-load-test .
```

### 2. Run Tests (No GCS)

Test memory mapping functionality without GCS:

```bash
docker run --rm \
  --privileged \
  --cap-add SYS_ADMIN \
  --device /dev/fuse \
  -e USE_MEMORY_MAPPING=yes \
  -e USE_GCS=no \
  hub-load-test
```

### 3. Run with GCS Integration

**Option A: Using Service Account Key File**

```bash
# Place your service account key in the current directory
docker run --rm \
  --privileged \
  --cap-add SYS_ADMIN \
  --device /dev/fuse \
  -v $(pwd)/service-account-key.json:/tmp/gcs-key.json:ro \
  -e USE_MEMORY_MAPPING=yes \
  -e USE_GCS=yes \
  -e GOOGLE_APPLICATION_CREDENTIALS=/tmp/gcs-key.json \
  -e GCS_BUCKET=performance_test_bdios \
  -e GCS_PREFIX=SCASS/SCA_NON_BDIOS_BINARY_SM_MEDIUM/ \
  hub-load-test
```

**Option B: Using Service Account Key as Environment Variable**

```bash
export GCS_SERVICE_ACCOUNT_KEY="$(cat service-account-key.json)"

docker run --rm \
  --privileged \
  --cap-add SYS_ADMIN \
  --device /dev/fuse \
  -e USE_MEMORY_MAPPING=yes \
  -e USE_GCS=yes \
  -e GCS_SERVICE_ACCOUNT_KEY="$GCS_SERVICE_ACCOUNT_KEY" \
  -e GCS_BUCKET=performance_test_bdios \
  -e GCS_PREFIX=SCASS/SCA_NON_BDIOS_BINARY_SM_MEDIUM/ \
  hub-load-test
```

## Using Docker Compose

### 1. Setup Environment

Create a `.env` file:

```bash
# .env file
BD_HUB_URL=https://your-hub-url.com
API_TOKEN=your-api-token-here
GCS_SERVICE_ACCOUNT_KEY=$(cat service-account-key.json)
SCAN_TYPE=BINARY_SCAN
MAX_SCANS=50
```

### 2. Run with Docker Compose

```bash
# Run main service with GCS
docker-compose up hub-load-test

# Run test-only service (no GCS)
docker-compose --profile testing up hub-load-test-runner

# Run in background
docker-compose up -d hub-load-test
```

## Running Black Duck Scans

### Memory Mapping + GCS Integration

```bash
docker run --rm \
  --privileged \
  --cap-add SYS_ADMIN \
  --device /dev/fuse \
  -v $(pwd)/service-account-key.json:/tmp/gcs-key.json:ro \
  -v $(pwd)/results:/home/hub_load/results \
  -e USE_MEMORY_MAPPING=yes \
  -e USE_GCS=yes \
  -e GOOGLE_APPLICATION_CREDENTIALS=/tmp/gcs-key.json \
  -e GCS_BUCKET=performance_test_bdios \
  -e GCS_PREFIX=SCASS/SCA_NON_BDIOS_BINARY_SM_MEDIUM/ \
  -e BD_HUB_URL=https://your-hub-url.com \
  -e API_TOKEN=your-api-token \
  -e SCAN_TYPE=BINARY_SCAN \
  -e MAX_SCANS=100 \
  -e DEBUG=yes \
  hub-load-test \
  ./submit_scans_fixed.sh
```

## Configuration Options

### GCS Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `USE_GCS` | Enable GCS integration | `yes` |
| `GCS_BUCKET` | GCS bucket name | `performance_test_bdios` |
| `GCS_PREFIX` | Path prefix in bucket | `SCASS/SCA_NON_BDIOS_BINARY_SM_MEDIUM/` |
| `GCS_MOUNT_POINT` | Local mount point | `/tmp/gcs-mount` |
| `GCS_CACHE_SIZE` | Local cache size | `10G` |

### Memory Mapping Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `USE_MEMORY_MAPPING` | Enable memory mapping | `yes` |
| `DEBUG` | Enable debug logging | `no` |

### Black Duck Configuration

| Variable | Description | Required |
|----------|-------------|----------|
| `BD_HUB_URL` | Black Duck Hub URL | Yes |
| `API_TOKEN` | API token for authentication | Yes |
| `SCAN_TYPE` | Type of scan (BINARY_SCAN, SIGNATURE_SCAN, CONTAINER_SCAN) | No |
| `MAX_SCANS` | Maximum number of scans | No |

## Docker Requirements

### Privileges Required

The container needs these privileges for GCS FUSE mounting:

```bash
--privileged              # Full privileges (simplest)
# OR specific capabilities:
--cap-add SYS_ADMIN      # For mounting filesystems
--device /dev/fuse       # Access to FUSE device
```

### Volumes

Recommended volume mounts:

```bash
-v $(pwd)/service-account-key.json:/tmp/gcs-key.json:ro  # GCS auth
-v $(pwd)/results:/home/hub_load/results                 # Results output
-v gcs-cache:/tmp/gcs-cache                             # GCS cache (named volume)
```

## Troubleshooting

### Common Issues

1. **"FUSE device not available"**
   ```bash
   # Ensure FUSE is available on host
   ls -la /dev/fuse
   
   # Add device to container
   --device /dev/fuse
   ```

2. **"Permission denied for mounting"**
   ```bash
   # Use privileged mode
   --privileged
   
   # Or add specific capabilities
   --cap-add SYS_ADMIN
   ```

3. **"GCS authentication failed"**
   ```bash
   # Verify service account key
   docker run --rm -v $(pwd)/key.json:/tmp/key.json:ro ubuntu cat /tmp/key.json
   
   # Check environment variable
   docker run --rm -e GOOGLE_APPLICATION_CREDENTIALS=/tmp/key.json hub-load-test env | grep GOOGLE
   ```

4. **"gcsfuse not found"**
   ```bash
   # Rebuild image to ensure gcsfuse is installed
   docker build --no-cache -t hub-load-test .
   ```

### Debug Mode

Enable comprehensive debugging:

```bash
docker run --rm \
  --privileged \
  --cap-add SYS_ADMIN \
  --device /dev/fuse \
  -e DEBUG=yes \
  -e USE_MEMORY_MAPPING=yes \
  -e USE_GCS=yes \
  hub-load-test
```

## Performance Considerations

1. **Cache Volume**: Use named volumes for GCS cache to persist across runs
2. **Memory**: Allocate sufficient memory for large file memory mapping
3. **Network**: Ensure adequate bandwidth for GCS operations
4. **Storage**: SSD-backed storage recommended for cache directories

## Integration with CI/CD

### Jenkins Pipeline Example

```groovy
pipeline {
    agent any
    stages {
        stage('Hub Load Test') {
            steps {
                script {
                    docker.image('hub-load-test').inside(
                        '--privileged --cap-add SYS_ADMIN --device /dev/fuse ' +
                        '-e USE_MEMORY_MAPPING=yes -e USE_GCS=yes ' +
                        '-e BD_HUB_URL=${BD_HUB_URL} -e API_TOKEN=${API_TOKEN}'
                    ) {
                        sh './submit_scans_fixed.sh'
                    }
                }
            }
        }
    }
}
```

### Kubernetes Deployment

For Kubernetes, you'll need:
- Security context with privileged mode
- FUSE device access
- Service account for GCS authentication
- Persistent volumes for caching