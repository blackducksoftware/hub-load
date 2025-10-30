# Common Configuration Templates
# Copy and modify these configurations for different testing scenarios

# =============================================================================
# BINARY SCAN FOCUSED TESTING
# =============================================================================
# Emphasizes binary scanning with different size distributions
# export USE_GCS=no
# export ENABLE_MULTI_SCAN=yes
# export ENABLE_ENHANCED_MULTI_SCAN=yes
# export MULTI_SCAN_CONFIG="BINARY_SCAN_SMALL:40,BINARY_SCAN_MEDIUM:35,BINARY_SCAN_LARGE:25"

# =============================================================================
# SIGNATURE SCAN FOCUSED TESTING
# =============================================================================
# Emphasizes signature scanning for Java/JAR file analysis
# export USE_GCS=no
# export ENABLE_MULTI_SCAN=yes
# export ENABLE_ENHANCED_MULTI_SCAN=yes
# export MULTI_SCAN_CONFIG="SIGNATURE_SCAN_SMALL:35,SIGNATURE_SCAN_MEDIUM:35,SIGNATURE_SCAN_LARGE:30"

# =============================================================================
# CONTAINER SCAN FOCUSED TESTING
# =============================================================================
# Emphasizes container scanning for Docker/container analysis
# export USE_GCS=no
# export ENABLE_MULTI_SCAN=yes
# export ENABLE_ENHANCED_MULTI_SCAN=yes
# export MULTI_SCAN_CONFIG="CONTAINER_SCAN_SMALL:40,CONTAINER_SCAN_MEDIUM:35,CONTAINER_SCAN_LARGE:25"

# =============================================================================
# BALANCED 4-TYPE TESTING
# =============================================================================
# Balanced distribution across all 4 scan types for comprehensive testing
# export USE_GCS=no
# export ENABLE_MULTI_SCAN=yes
# export ENABLE_ENHANCED_MULTI_SCAN=yes
# export ENABLE_TARGZ_FILES=yes
# export MULTI_SCAN_CONFIG="BINARY_SCAN_SMALL:15,BINARY_SCAN_MEDIUM:10,BINARY_SCAN_LARGE:5,SIGNATURE_SCAN_SMALL:15,SIGNATURE_SCAN_MEDIUM:15,SIGNATURE_SCAN_LARGE:10,CONTAINER_SCAN_SMALL:15,CONTAINER_SCAN_MEDIUM:10,CONTAINER_SCAN_LARGE:5"

# =============================================================================
# HIGH VOLUME TESTING
# =============================================================================
# Configuration for high-volume load testing
# export USE_GCS=no
# export ENABLE_MULTI_SCAN=yes
# export ENABLE_ENHANCED_MULTI_SCAN=yes
# export MAX_SCANS=100
# export ENABLE_TARGZ_FILES=yes
# export MULTI_SCAN_CONFIG="SIGNATURE_SCAN_SMALL:25,SIGNATURE_SCAN_MEDIUM:25,BINARY_SCAN_SMALL:20,CONTAINER_SCAN_SMALL:15,BINARY_SCAN_MEDIUM:10,CONTAINER_SCAN_MEDIUM:5"

# =============================================================================
# DEVELOPMENT/DEBUG TESTING
# =============================================================================
# Quick testing configuration for development and debugging
# export USE_GCS=no
# export ENABLE_MULTI_SCAN=yes
# export ENABLE_ENHANCED_MULTI_SCAN=yes
# export MAX_SCANS=3
# export DRY_RUN=yes
# export DEBUG=yes
# export MULTI_SCAN_CONFIG="SIGNATURE_SCAN_SMALL:50,BINARY_SCAN_SMALL:50"

# =============================================================================
# MEMORY MAPPING TESTING
# =============================================================================
# Configuration with memory mapping enabled for performance testing
# export USE_GCS=no
# export ENABLE_MULTI_SCAN=yes
# export ENABLE_ENHANCED_MULTI_SCAN=yes
# export USE_MEMORY_MAPPING=yes
# export MAX_SCANS=20
# export MULTI_SCAN_CONFIG="BINARY_SCAN_LARGE:40,SIGNATURE_SCAN_LARGE:35,CONTAINER_SCAN_LARGE:25"