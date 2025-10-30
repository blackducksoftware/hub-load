# Docker Implementation Guide for Hub-Load Script

## 🐳 Docker Architecture Alignment Assessment

### ✅ **Current Docker-Friendly Features:**
- **Environment Variable Configuration**: Perfect for Docker
- **Container ID Detection**: Already uses `/etc/hostname`
- **Signal Handling**: Proper cleanup functions
- **Parallel Processing**: Well-suited for container scaling

### 🔧 **Docker Optimizations Applied:**

#### 1. **Filesystem & Volume Management**
```bash
# Before (host assumptions)
GCS_MOUNT_POINT=/tmp/gcs-mount
detect_log=/tmp/detect_$$.log

# After (Docker volumes)
GCS_MOUNT_POINT=/mnt/gcs-data    # Mount as volume
LOG_DIR=/app/logs                # Persistent log volume
GCS_CACHE_DIR=/app/temp/gcs-cache # Writable cache volume
```

#### 2. **Container Environment Detection**
- Auto-detects Docker/Kubernetes environments
- Optimizes `MAX_PARALLEL_JOBS` based on container CPU limits
- Creates required directories with proper permissions

#### 3. **Resource Optimization**
- Container-aware CPU detection for parallel jobs
- Docker-friendly cache and temp directories
- Volume-based persistent storage

## 📦 **Recommended Docker Implementation**

### **Dockerfile Example:**
```dockerfile
FROM ubuntu:22.04

# Install required packages
RUN apt-get update && apt-get install -y \
    openjdk-17-jdk \
    curl \
    python3 \
    python3-pip \
    gcsfuse \
    && rm -rf /var/lib/apt/lists/*

# Set Java environment
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH=$PATH:$JAVA_HOME/bin

# Create application directories
RUN mkdir -p /app/logs /app/temp /mnt/gcs-data /app/config
WORKDIR /app

# Copy application files
COPY src/hub_load/ /app/hub_load/
COPY config/ /app/config/

# Set permissions
RUN chmod +x /app/hub_load/core/submit_scans_fixed.sh

# Define volumes for persistence
VOLUME ["/app/logs", "/mnt/gcs-data", "/app/temp"]

# Set container-optimized defaults
ENV LOG_DIR=/app/logs
ENV GCS_CACHE_DIR=/app/temp/gcs-cache
ENV GCS_MOUNT_POINT=/mnt/gcs-data
ENV CONFIG_DIR=/app/config

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD pgrep -f "submit_scans" || exit 1

# Run the script
ENTRYPOINT ["/app/hub_load/core/submit_scans_fixed.sh"]
```

### **Docker Compose Example:**
```yaml
version: '3.8'
services:
  hub-load:
    build: .
    environment:
      - BD_HUB_URL=https://your-hub.blackduck.com
      - API_TOKEN=${BD_API_TOKEN}
      - PARALLEL_SCANS=yes
      - MAX_PARALLEL_JOBS=4
      - MAX_SCANS=50
      - ENABLE_ENHANCED_MULTI_SCAN=yes
      - USE_GCS=yes
      - GCS_BUCKET=performance_test_bdios
    volumes:
      - ./logs:/app/logs
      - ./temp:/app/temp
      - gcs-data:/mnt/gcs-data
      - ./test-data:/app/test-data:ro
    cap_add:
      - SYS_ADMIN  # Required for FUSE mounts
    devices:
      - /dev/fuse
    security_opt:
      - apparmor:unconfined
      
volumes:
  gcs-data:
```

### **Kubernetes Deployment Example:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hub-load-performance
spec:
  replicas: 3
  selector:
    matchLabels:
      app: hub-load
  template:
    metadata:
      labels:
        app: hub-load
    spec:
      containers:
      - name: hub-load
        image: hub-load:latest
        env:
        - name: BD_HUB_URL
          value: "https://your-hub.blackduck.com"
        - name: API_TOKEN
          valueFrom:
            secretKeyRef:
              name: blackduck-secret
              key: api-token
        - name: PARALLEL_SCANS
          value: "yes"
        - name: MAX_PARALLEL_JOBS
          value: "2"
        - name: MAX_SCANS
          value: "100"
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
        volumeMounts:
        - name: logs
          mountPath: /app/logs
        - name: temp
          mountPath: /app/temp
        - name: gcs-data
          mountPath: /mnt/gcs-data
      volumes:
      - name: logs
        emptyDir: {}
      - name: temp
        emptyDir: {}
      - name: gcs-data
        emptyDir: {}
```

## 🚀 **Docker Benefits for This Script:**

### **1. Scalability**
- Easy horizontal scaling with multiple containers
- Resource isolation and limits
- Load distribution across container replicas

### **2. Environment Consistency**
- Same Java version across environments
- Consistent dependency versions
- Reproducible test environments

### **3. Cloud Integration**
- Perfect for Kubernetes orchestration
- Easy integration with cloud storage (GCS)
- Container registry deployment

### **4. Resource Management**
- CPU/memory limits and requests
- Automatic container resource detection
- Efficient parallel job management

## ⚙️ **Usage Examples:**

### **Basic Docker Run:**
```bash
docker run -e BD_HUB_URL=https://hub.blackduck.com \
           -e API_TOKEN=your-token \
           -e PARALLEL_SCANS=yes \
           -v ./logs:/app/logs \
           hub-load:latest
```

### **Performance Testing at Scale:**
```bash
# Run 5 parallel containers for load testing
docker-compose up --scale hub-load=5
```

### **Cloud Deployment:**
```bash
# Deploy to Kubernetes cluster
kubectl apply -f k8s-deployment.yaml
kubectl scale deployment hub-load-performance --replicas=10
```

## 🔒 **Security Considerations:**

1. **Secrets Management**: Use Docker secrets or Kubernetes secrets for API tokens
2. **FUSE Permissions**: Required for GCS mounting (SYS_ADMIN capability)
3. **Volume Security**: Proper volume permissions and access controls
4. **Network Policies**: Restrict network access as needed

## 📊 **Monitoring & Observability:**

1. **Health Checks**: Container health monitoring
2. **Log Aggregation**: Centralized logging via volume mounts
3. **Metrics Collection**: Container resource usage monitoring
4. **Parallel Job Tracking**: Enhanced visibility into background processes

This Docker implementation maintains all current functionality while optimizing for container environments and enabling easy scaling for performance testing scenarios.