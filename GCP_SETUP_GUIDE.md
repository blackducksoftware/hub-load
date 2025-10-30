# GCP Service Account Setup for hub-load Memory Mapping
# =====================================================

## Required GCP Services
# - Google Cloud Storage (for test data)
# - Compute Engine (for running workloads)
# - IAM (for service account management)

## Service Account Permissions Required

### 1. Storage Permissions (for GCS access)
roles/storage.objectViewer      # Read objects from GCS buckets
roles/storage.legacyBucketReader # List bucket contents

### 2. Compute Permissions (if using GCE)
roles/compute.instanceAdmin.v1   # Manage compute instances
roles/compute.storageAdmin       # Attach persistent disks

### 3. Monitoring/Logging (recommended)
roles/logging.logWriter         # Write logs to Cloud Logging
roles/monitoring.metricWriter   # Write custom metrics

## Minimal Service Account Setup Commands

# 1. Create service account
gcloud iam service-accounts create hub-load-perftest \
    --display-name="Hub Load Performance Testing" \
    --description="Service account for hub-load performance testing with memory mapping"

# 2. Grant necessary permissions
gcloud projects add-iam-policy-binding PROJECT_ID \
    --member="serviceAccount:hub-load-perftest@PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/storage.objectViewer"

gcloud projects add-iam-policy-binding PROJECT_ID \
    --member="serviceAccount:hub-load-perftest@PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/storage.legacyBucketReader"

# 3. Create and download key
gcloud iam service-accounts keys create hub-load-service-key.json \
    --iam-account=hub-load-perftest@PROJECT_ID.iam.gserviceaccount.com

## Bucket-Specific Permissions (More Secure)
# Instead of project-level permissions, grant bucket-specific access:

gsutil iam ch serviceAccount:hub-load-perftest@PROJECT_ID.iam.gserviceaccount.com:objectViewer gs://performance_test_bdios
gsutil iam ch serviceAccount:hub-load-perftest@PROJECT_ID.iam.gserviceaccount.com:legacyBucketReader gs://performance_test_bdios

## Cost Implications

### GCS Storage Costs (primary cost driver)
# Standard Storage: $0.020 per GB per month
# Nearline Storage: $0.010 per GB per month  
# Coldline Storage: $0.004 per GB per month

### Network Egress Costs
# GCS to same region: FREE
# GCS to other regions: $0.01-0.12 per GB
# GCS to internet: $0.085-0.23 per GB

### API Request Costs (minimal)
# Class A operations (write): $0.005 per 1,000 operations
# Class B operations (read): $0.0004 per 1,000 operations

### Compute Costs (if using GCE)
# Depends on machine type and usage duration
# Preemptible instances: ~70% cost reduction

## Memory Mapping Specific Considerations

### Storage Access Patterns
# Memory mapping = more random access patterns
# May result in slightly higher API call costs
# But reduces data transfer if files are accessed partially

### Caching Benefits
# GCS has built-in caching
# Repeated access to same files = reduced costs
# Memory mapping can leverage this effectively

## Estimated Monthly Costs for Performance Testing

### Scenario 1: Small Dataset (100GB)
# Storage: 100GB × $0.020 = $2.00/month
# API calls: ~1000 operations × $0.0004 = $0.0004/month
# Total: ~$2.00/month

### Scenario 2: Large Dataset (1TB)  
# Storage: 1000GB × $0.020 = $20.00/month
# API calls: ~10000 operations × $0.0004 = $0.004/month  
# Total: ~$20.00/month

### Network Costs (if accessing from outside GCP)
# Egress: Dataset size × usage frequency × $0.085/GB
# Example: 100GB × 10 accesses/month × $0.085 = $85/month

## Cost Optimization Strategies

### 1. Use Regional Storage
# Keep GCS bucket in same region as compute
# Eliminates network egress charges

### 2. Use Nearline/Coldline for Archival
# Move old test data to cheaper storage classes
# Automated lifecycle policies

### 3. Implement Caching
# Local caching reduces repeated GCS access
# Memory mapping naturally provides this

### 4. Use Preemptible/Spot Instances
# Significant cost reduction for batch workloads
# Perfect for performance testing scenarios

### 5. Monitor and Alert
# Set up billing alerts and quotas
# Monitor usage patterns and optimize

## Security Best Practices

### 1. Least Privilege Access
# Grant minimal required permissions only
# Use bucket-specific IAM instead of project-level

### 2. Key Rotation
# Regularly rotate service account keys
# Use Workload Identity when possible (GKE)

### 3. Audit and Monitoring
# Enable Cloud Audit Logs
# Monitor service account usage

### 4. Network Security
# Use VPC endpoints when possible
# Restrict network access to authorized sources