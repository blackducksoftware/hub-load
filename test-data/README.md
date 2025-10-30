# Black Duck Load Test Data (Minimal)

This directory contains minimal test data (2-3 files per directory) organized to match the GCS bucket structure.

## Directory Structure

```
test-data/
└── SCASS/
    ├── SCA_NON_BDIOS_BINARY_LARGE/      # 3 test jar files
    ├── SCA_NON_BDIOS_BINARY_SM_MEDIUM/  # 2 test jar files
    ├── SCA_NON_BDIOS_BINARY_XLARGE/     # 3 test jar files
    ├── SCA_NON_BDIOS_CONTAINER_LARGE/   # 3 Dockerfiles + placeholders
    ├── SCA_NON_BDIOS_CONTAINER_SM_MEDIUM/ # 2 Dockerfiles + placeholders
    ├── SCA_NON_BDIOS_CONTAINER_XLARGE/  # 3 Dockerfiles + placeholders
    ├── SCA_NON_BDIOS_LARGE/            # 3 Java source files + pom.xml
    └── SCA_NON_BDIOS_SM_MEDIUM/        # 2 Java source files + pom.xml
```

## Usage

Set these environment variables to use local test data:
```bash
export USE_GCS=no
export LOCAL_TEST_DATA_DIR=/path/to/this/test-data/directory
```

Then run your load testing scripts normally.
