#!/bin/bash
# GCP Service Account Setup Script for hub-load

set -e

echo "🔧 GCP SERVICE ACCOUNT SETUP FOR HUB-LOAD"
echo "=========================================="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Configuration variables
PROJECT_ID="${GCP_PROJECT_ID:-your-project-id}"
SERVICE_ACCOUNT_NAME="hub-load-perftest"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
KEY_FILE="hub-load-service-key.json"
BUCKET_NAME="${GCS_BUCKET:-performance_test_bdios}"

# Validate prerequisites
echo "🔍 Validating prerequisites..."

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI not found. Please install Google Cloud SDK."
    echo "   https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if user is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    echo "❌ Not authenticated with gcloud. Please run:"
    echo "   gcloud auth login"
    exit 1
fi

# Validate project ID
echo "📋 Current project: $(gcloud config get-value project 2>/dev/null || echo 'Not set')"
if [ "$PROJECT_ID" == "your-project-id" ]; then
    echo "⚠️  Please set GCP_PROJECT_ID environment variable:"
    echo "   export GCP_PROJECT_ID=your-actual-project-id"
    echo "   Or modify the PROJECT_ID variable in this script"
    exit 1
fi

# Set project
gcloud config set project "$PROJECT_ID"
echo "✅ Using project: $PROJECT_ID"
echo ""

# Create service account
echo "👤 Creating service account..."
if gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" &>/dev/null; then
    echo "✅ Service account already exists: $SERVICE_ACCOUNT_EMAIL"
else
    gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
        --display-name="Hub Load Performance Testing" \
        --description="Service account for hub-load performance testing with memory mapping and GCS access"
    echo "✅ Created service account: $SERVICE_ACCOUNT_EMAIL"
fi

# Grant storage permissions
echo ""
echo "🔐 Granting storage permissions..."

# Option 1: Project-level permissions (simpler but broader access)
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/storage.objectViewer" \
    --quiet

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/storage.legacyBucketReader" \
    --quiet

echo "✅ Granted project-level storage permissions"

# Grant logging permissions (optional but recommended)
echo ""
echo "📊 Granting logging permissions..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/logging.logWriter" \
    --quiet

echo "✅ Granted logging permissions"

# Create service account key
echo ""
echo "🔑 Creating service account key..."
if [ -f "$KEY_FILE" ]; then
    echo "⚠️  Key file already exists: $KEY_FILE"
    echo "   Remove it if you want to create a new one"
else
    gcloud iam service-accounts keys create "$KEY_FILE" \
        --iam-account="$SERVICE_ACCOUNT_EMAIL"
    echo "✅ Created service account key: $KEY_FILE"
fi

# Validate bucket access (if bucket exists)
echo ""
echo "🪣 Validating bucket access..."
if gsutil ls "gs://$BUCKET_NAME" &>/dev/null; then
    echo "✅ Bucket exists and is accessible: gs://$BUCKET_NAME"
    
    # Test service account access
    echo "🧪 Testing service account access..."
    if gcloud auth activate-service-account --key-file="$KEY_FILE" --quiet; then
        if gsutil ls "gs://$BUCKET_NAME" &>/dev/null; then
            echo "✅ Service account can access bucket successfully"
        else
            echo "❌ Service account cannot access bucket"
            echo "   You may need bucket-specific permissions:"
            echo "   gsutil iam ch serviceAccount:$SERVICE_ACCOUNT_EMAIL:objectViewer gs://$BUCKET_NAME"
        fi
        
        # Switch back to user account
        gcloud auth activate-service-account --key-file="$KEY_FILE" --revoke --quiet 2>/dev/null || true
    else
        echo "⚠️  Could not test service account access"
    fi
else
    echo "⚠️  Bucket not found or not accessible: gs://$BUCKET_NAME"
    echo "   Create the bucket or check permissions"
fi

# Cost estimation
echo ""
echo "💰 COST ESTIMATION"
echo "------------------"

if gsutil du -s "gs://$BUCKET_NAME" 2>/dev/null; then
    bucket_size=$(gsutil du -s "gs://$BUCKET_NAME" 2>/dev/null | awk '{print $1}')
    bucket_size_gb=$(echo "scale=2; $bucket_size / 1024 / 1024 / 1024" | bc -l 2>/dev/null || echo "Unknown")
    
    # Estimate monthly storage cost
    storage_cost=$(echo "scale=2; $bucket_size_gb * 0.020" | bc -l 2>/dev/null || echo "Unknown")
    
    echo "  • Bucket size: ${bucket_size_gb}GB"
    echo "  • Estimated monthly storage cost: \$${storage_cost}"
    echo "  • API calls cost: ~\$0.01-0.10/month (minimal)"
    echo "  • Network egress: FREE (same region) or \$0.085/GB (external)"
else
    echo "  • Could not determine bucket size"
    echo "  • Typical costs: \$0.020/GB/month for standard storage"
fi

# Setup summary
echo ""
echo "📋 SETUP SUMMARY"
echo "----------------"
echo "  • Project ID: $PROJECT_ID"
echo "  • Service Account: $SERVICE_ACCOUNT_EMAIL"
echo "  • Key File: $KEY_FILE"
echo "  • Bucket: gs://$BUCKET_NAME"
echo ""

# Next steps
echo "🚀 NEXT STEPS"
echo "-------------"
echo "1. Test memory mapping with GCS:"
echo "   export GOOGLE_APPLICATION_CREDENTIALS=\"$(pwd)/$KEY_FILE\""
echo "   export USE_GCS=yes"
echo "   export GCS_BUCKET=$BUCKET_NAME"
echo "   ./validate_memory_mapping.sh"
echo ""
echo "2. For production use, consider:"
echo "   - Using Workload Identity (instead of key files)"
echo "   - Setting up monitoring and alerting"
echo "   - Implementing cost controls and budgets"
echo ""
echo "3. Environment variables for hub-load:"
echo "   export GOOGLE_APPLICATION_CREDENTIALS=\"$(pwd)/$KEY_FILE\""
echo "   export USE_GCS=yes"
echo "   export GCS_BUCKET=$BUCKET_NAME"
echo "   export USE_MEMORY_MAPPING=yes"
echo ""

# Security reminder
echo "🔒 SECURITY REMINDER"
echo "-------------------"
echo "  • Keep the key file secure and never commit it to version control"
echo "  • Consider using Workload Identity for production workloads"
echo "  • Regularly rotate service account keys"
echo "  • Monitor usage and costs in GCP Console"
echo ""
echo "✅ Setup completed: $(date '+%Y-%m-%d %H:%M:%S')"