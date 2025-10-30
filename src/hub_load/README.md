# Hub Load Testing - Modular Architecture

This directory contains the modular Black Duck SCA load testing system supporting 4 scan types with enhanced multi-scan capabilities.

## Directory Structure

```
hub_load/
├── hub_load_test.sh              # Main entry point script
├── core/                         # Core load testing functionality
│   └── submit_scans_fixed.sh    # Main load testing engine
├── config/                       # Configuration files
│   └── enhanced_multi_scan_config.sh  # Multi-scan type configuration
├── scripts/                      # Utility scripts
│   └── download-packages.sh     # Package download functionality
├── memory_mapping/               # Memory mapping functionality
│   ├── mmap_file_handler.py     # Python memory mapping handler
│   ├── mmap_wrapper.sh          # Shell wrapper for memory mapping
│   ├── multi_type_mmap_handler.py  # Multi-type memory mapping
│   └── __pycache__/             # Python cache files
├── docker/                       # Docker-related files
│   └── docker-entrypoint.sh     # Docker container entry point
└── docs/                         # Documentation
    └── MEMORY_MAPPING_README.md  # Memory mapping documentation
```

## Usage

### Basic Usage
```bash
# Run with default settings
./hub_load_test.sh

# Run with custom configuration
USE_GCS=no ENABLE_MULTI_SCAN=yes ENABLE_ENHANCED_MULTI_SCAN=yes MAX_SCANS=10 ./hub_load_test.sh
```

### Supported Scan Types
1. **SIGNATURE_SCAN** - Signature scanning with .jar files
2. **BINARY_SCAN** - Binary scanning with executable files
3. **CONTAINER_SCAN** - Container scanning
4. **TAR.GZ File Handling** - Archive file processing (replaces snippet scans)

### Key Features
- **Multi-Type Scanning**: Support for 4 different scan types with configurable distributions
- **Size Variants**: SMALL, MEDIUM, LARGE, XLARGE variants for each scan type
- **Local Test Data**: No dependency on Google Cloud Storage
- **Sleep Optimization**: Skip first scan sleep for faster testing
- **Memory Mapping**: Optional memory mapping for efficient file access
- **Modular Architecture**: Clean separation of concerns for maintainability

## Configuration

### Environment Variables
- `USE_GCS`: Enable/disable Google Cloud Storage (default: no)
- `ENABLE_MULTI_SCAN`: Enable multi-scan functionality (default: no)
- `ENABLE_ENHANCED_MULTI_SCAN`: Enable enhanced multi-scan with size variants (default: no)
- `ENABLE_TARGZ_FILES`: Enable TAR.GZ file copying (default: yes)
- `MAX_SCANS`: Maximum number of scans to execute (default: 3)
- `MULTI_SCAN_CONFIG`: Distribution configuration for scan types (see config/enhanced_multi_scan_config.sh)

### Scan Distribution Configuration
Edit `config/enhanced_multi_scan_config.sh` to customize scan type distributions:

```bash
# Example: Binary-focused testing
MULTI_SCAN_CONFIG="BINARY_SCAN_SMALL:40,BINARY_SCAN_MEDIUM:35,BINARY_SCAN_LARGE:25"

# Example: Balanced across all types
MULTI_SCAN_CONFIG="BINARY_SCAN_SMALL:15,SIGNATURE_SCAN_MEDIUM:25,CONTAINER_SCAN_SMALL:20,BINARY_SCAN_MEDIUM:15,SIGNATURE_SCAN_LARGE:15,CONTAINER_SCAN_MEDIUM:10"
```

## Architecture Benefits

### Modular Design
- **Separation of Concerns**: Each directory has a specific purpose
- **Easy Maintenance**: Locate and modify specific functionality quickly
- **Scalable**: Add new modules without affecting existing code
- **Testable**: Individual components can be tested in isolation

### Backward Compatibility
- **Legacy Support**: Existing scripts continue to work
- **Gradual Migration**: Can migrate to modular structure incrementally
- **Path Resolution**: Automatic detection of modular vs legacy setups

### Development Workflow
- **Core Logic**: Modify `core/submit_scans_fixed.sh` for main functionality
- **Configuration**: Update `config/enhanced_multi_scan_config.sh` for scan settings
- **Utilities**: Add new utilities to `scripts/` directory
- **Memory Mapping**: Enhance memory mapping in `memory_mapping/` directory
- **Docker**: Update containerization in `docker/` directory

## Migration from Legacy Structure

The modular structure is backward compatible. Existing deployments can continue using the original file layout, while new deployments can use the modular structure for better maintainability.

## Test Data Structure

The system expects test data in the following structure (relative to project root):
```
test-data/SCASS/
├── SCA_NON_BDIOS_BINARY_LARGE/
├── SCA_NON_BDIOS_BINARY_SM_MEDIUM/
├── SCA_NON_BDIOS_CONTAINER_LARGE/
├── SCA_NON_BDIOS_CONTAINER_SM_MEDIUM/
├── SCA_NON_BDIOS_LARGE/
├── SCA_NON_BDIOS_SM_MEDIUM/
└── SCA_SNIPPETS/
```

Each directory should contain appropriate test files for the respective scan type.