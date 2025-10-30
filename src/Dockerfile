#
# PgBadger to be used alongside HUB containers to collect 
# and process Postgres log data
#

FROM ubuntu:22.04

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install system dependencies including Python, FUSE, and GCS tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl wget unzip rsync \
        openjdk-17-jre-headless \
        python3 python3-pip \
        fuse \
        ca-certificates \
        gnupg \
        lsb-release \
        apt-transport-https && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Google Cloud SDK
RUN mkdir -p /usr/share/keyrings && \
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
    gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | \
    tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends google-cloud-cli && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install gcsfuse for mounting GCS buckets
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt gcsfuse-jammy main" | \
    tee /etc/apt/sources.list.d/gcsfuse.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends gcsfuse && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ADD hub_load /home/hub_load

# Set up permissions for memory mapping and GCS integration
RUN chmod +x /home/hub_load/download-packages.sh && \
    chmod +x /home/hub_load/submit_scans_fixed.sh && \
    chmod +x /home/hub_load/test_memory_mapping.sh && \
    chmod +x /home/hub_load/mmap_wrapper.sh && \
    chmod +x /home/hub_load/mmap_file_handler.py

# Create mount points and cache directories for GCS
RUN mkdir -p /tmp/gcs-mount /tmp/gcs-cache && \
    chmod 755 /tmp/gcs-mount /tmp/gcs-cache

# download-packages downloads a collection of jar files from S3 and places them in /home/hub_load/jars
RUN cd /home/hub_load && /home/hub_load/download-packages.sh

# Set up Docker entrypoint
RUN chmod +x /home/hub_load/docker-entrypoint.sh

# Set working directory
WORKDIR /home/hub_load

# Set environment variables for Docker-friendly defaults
ENV USE_MEMORY_MAPPING=yes
ENV USE_GCS=yes
ENV GCS_BUCKET=performance_test_bdios
ENV GCS_PREFIX=SCASS/SCA_NON_BDIOS_BINARY_SM_MEDIUM/
ENV GCS_MOUNT_POINT=/tmp/gcs-mount
ENV GCS_CACHE_SIZE=10G

# Set the entrypoint
ENTRYPOINT ["/home/hub_load/docker-entrypoint.sh"]

# Default command is to run tests
CMD ["./test_memory_mapping.sh"]
