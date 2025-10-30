# Memory Mapping for Efficient File Access

This implementation adds memory mapping capabilities to the `submit_scans_fixed.sh` script, enabling efficient access to large test data files (TBs) without copying data.

## Benefits

- **Zero Copy Overhead**: Files are accessed directly without duplication
- **Fast Access**: OS-level memory mapping provides efficient file access
- **Reduced Storage**: No temporary copies of large files
- **Scalable**: Works with files of any size, limited only by virtual memory
- **Minimal Changes**: Existing script behavior preserved when disabled

## Files Added

1. `mmap_file_handler.py` - Python script for memory mapping functionality
2. `mmap_wrapper.sh` - Bash wrapper for easy integration
3. `test_memory_mapping.sh` - Test script to verify functionality

## Usage

### Enable Memory Mapping

Set the environment variable to enable memory mapping:

```bash
export USE_MEMORY_MAPPING=yes
```

### Run Tests with Memory Mapping

```bash
# Example with binary scans
USE_MEMORY_MAPPING=yes SCAN_TYPE=BINARY_SCAN ./submit_scans_fixed.sh

# Example with container scans
USE_MEMORY_MAPPING=yes SCAN_TYPE=CONTAINER_SCAN MAX_SCANS=10 ./submit_scans_fixed.sh
```

### Test the Implementation

```bash
# Run the test script to verify everything works
./test_memory_mapping.sh
```

## How It Works

### Traditional Approach (without memory mapping):
1. Find test files
2. Copy/link files to temporary directories
3. Run Black Duck scans
4. Clean up temporary files

### Memory Mapping Approach:
1. Find test files
2. Create efficient hard links (zero copy)
3. Memory map files for access (OS handles caching)
4. Run Black Duck scans with direct file paths
5. Clean up links only (original files untouched)

### Python Memory Mapping Handler

The `mmap_file_handler.py` script provides:

- **Memory mapping**: Using Python's `mmap` module for efficient file access
- **Hard linking**: Creates hard links to avoid data duplication
- **File information**: Gets file stats without loading full file
- **Batch processing**: Handles multiple files efficiently
- **Automatic cleanup**: Manages temporary resources

## Configuration Options

| Variable | Default | Description |
|----------|---------|-------------|
| `USE_MEMORY_MAPPING` | `no` | Enable memory mapping functionality |

## Performance Benefits

For 2TB of test data:

| Aspect | Traditional | Memory Mapping |
|--------|-------------|----------------|
| Storage Overhead | 100% (2TB copies) | ~0% (links only) |
| Setup Time | Hours (copying) | Seconds (linking) |
| Memory Usage | High (full copies) | Low (on-demand paging) |
| Scalability | Limited by disk space | Limited by virtual memory |

## Requirements

- Python 3.x
- Operating system with memory mapping support (Linux, macOS, Windows)
- Sufficient virtual memory address space for large files

## Troubleshooting

### Common Issues

1. **"Python 3 not found"**
   - Install Python 3: `sudo apt-get install python3` (Ubuntu) or `brew install python3` (macOS)

2. **"Permission denied" when creating links**
   - Ensure write permissions to destination directory
   - Check if filesystem supports hard links

3. **"Memory mapping failed"**
   - File may be empty or corrupted
   - Check available virtual memory space

### Debug Mode

Enable verbose logging:

```bash
USE_MEMORY_MAPPING=yes DEBUG=yes ./submit_scans_fixed.sh
```

## Limitations

1. **Virtual Memory**: Large files require adequate virtual memory address space
2. **File System**: Some network filesystems may not support hard links efficiently
3. **Platform**: Memory mapping behavior varies slightly between operating systems

## Google Cloud Storage (GCS) Integration

### Overview

The script now supports direct integration with Google Cloud Storage through GCSFuse mounting, combining the benefits of cloud storage with memory mapping efficiency.

### Prerequisites

1. **Google Cloud SDK**: Install and authenticate
   ```bash
   # Install gcloud
   curl https://sdk.cloud.google.com | bash
   source ~/.bashrc
   
   # Authenticate
   gcloud auth login
   gcloud auth application-default login
   ```

2. **GCSFuse**: Install the FUSE adapter for GCS
   ```bash
   # Linux
   curl -L https://github.com/GoogleCloudPlatform/gcsfuse/releases/latest/download/gcsfuse_Linux_x86_64.tar.gz | tar -xz
   sudo mv gcsfuse /usr/local/bin/
   
   # macOS
   brew install gcsfuse
   ```

### GCS Configuration

Enable GCS integration with these environment variables:

```bash
export USE_GCS=yes                    # Enable GCS mounting
export GCS_BUCKET=your-bucket-name    # GCS bucket containing test data
export GCS_PREFIX=test-data/          # Optional: path prefix within bucket
export GCS_MOUNT_POINT=/tmp/gcs       # Local mount point
export GCS_CACHE_SIZE=1GB             # Local cache size for performance
```

### Usage Examples

#### Basic GCS Integration
```bash
USE_GCS=yes \
GCS_BUCKET=my-test-data-bucket \
USE_MEMORY_MAPPING=yes \
SCAN_TYPE=BINARY_SCAN \
./submit_scans_fixed.sh
```

#### With Custom Prefix and Cache
```bash
USE_GCS=yes \
GCS_BUCKET=blackduck-test-data \
GCS_PREFIX=java-binaries/ \
GCS_MOUNT_POINT=/mnt/gcs-cache \
GCS_CACHE_SIZE=5GB \
USE_MEMORY_MAPPING=yes \
SCAN_TYPE=BINARY_SCAN \
MAX_SCANS=100 \
./submit_scans_fixed.sh
```

#### Combined with Debug Mode
```bash
USE_GCS=yes \
GCS_BUCKET=my-bucket \
USE_MEMORY_MAPPING=yes \
DEBUG=yes \
SCAN_TYPE=CONTAINER_SCAN \
./submit_scans_fixed.sh
```

### GCS Performance Optimization

1. **Cache Size**: Set `GCS_CACHE_SIZE` based on available local storage
2. **Bucket Location**: Use buckets in the same region as your compute resources
3. **File Organization**: Structure files in GCS with logical prefixes
4. **Network**: Ensure adequate bandwidth for initial file access

### Troubleshooting GCS Integration

#### Common Issues

1. **"gsutil not found"**
   ```bash
   # Install Google Cloud SDK
   curl https://sdk.cloud.google.com | bash
   ```

2. **"gcsfuse not found"**
   ```bash
   # Install gcsfuse (see prerequisites above)
   ```

3. **"Authentication failed"**
   ```bash
   # Re-authenticate
   gcloud auth login
   gcloud auth application-default login
   ```

4. **"Bucket not found"**
   ```bash
   # List available buckets
   gsutil ls
   
   # Create bucket if needed
   gsutil mb gs://your-bucket-name
   ```

5. **"Mount failed"**
   - Check mount point permissions
   - Verify bucket access permissions
   - Check network connectivity

#### GCS Debug Mode

Enable detailed GCS debugging:

```bash
USE_GCS=yes DEBUG=yes GCS_BUCKET=your-bucket ./submit_scans_fixed.sh
```

This provides:
- GCSFuse debug output
- Mount status information
- Performance metrics
- Error details

### Cost Considerations

- **Storage**: Standard GCS storage costs (~$0.020/GB/month)
- **Operations**: List/read operations (minimal cost for scanning)
- **Network**: Egress charges for data transfer out of GCS
- **Cache**: Local storage for GCS cache (reduces repeat downloads)

### Integration with Existing Storage

GCS integration works alongside existing storage:

- **Primary**: Use GCS for large test data archives
- **Cache**: Local NFS (`/netapp/eng`) for frequently accessed files
- **Hybrid**: Combine both based on access patterns

## Integration with Cloud Storage

The memory mapping approach works well with:

- **Local NFS mounts** (like your current `/netapp/eng` setup)
- **GCSFuse** mounted buckets (with new GCS integration)
- **Local SSD storage** with cloud sync

For best performance with cloud storage, consider:
1. Use local SSD cache with memory mapping
2. Pre-populate frequently accessed files
3. Monitor network bandwidth usage
4. Combine GCS with local caching for optimal performance

## Future Enhancements

Potential improvements:
1. **Prefetching**: Intelligent pre-loading of files based on access patterns
2. **Compression**: On-the-fly decompression for compressed archives
3. **Distributed Caching**: Share memory-mapped files across multiple nodes
4. **Metrics**: Detailed performance monitoring and reporting