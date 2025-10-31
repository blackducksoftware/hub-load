#!/bin/bash

# Kubernetes Hub Load Deployment Script
# Enhanced with Memory Mapping Optimization and NFS Integration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$SCRIPT_DIR/k8s"

# Configuration
NAMESPACE="hub-load-testing"
IMAGE_NAME="hub-load:enhanced"
NFS_SERVER=""
NFS_PATH=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    echo "Kubernetes Hub Load Deployment Script"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  deploy              Deploy hub-load to Kubernetes"
    echo "  build-and-deploy    Build Docker image and deploy"
    echo "  test                Run test job"
    echo "  perf-test           Run performance test"
    echo "  scale               Scale deployment"
    echo "  logs                View logs"
    echo "  status              Show deployment status"
    echo "  cleanup             Remove all resources"
    echo "  update-nfs          Update NFS configuration"
    echo "  help                Show this help"
    echo ""
    echo "Options:"
    echo "  --nfs-server SERVER    NFS server address"
    echo "  --nfs-path PATH        NFS export path"
    echo "  --image IMAGE          Docker image name (default: hub-load:enhanced)"
    echo "  --namespace NS         Kubernetes namespace (default: hub-load-testing)"
    echo "  --replicas N           Number of replicas for scaling"
    echo "  --scan-count N         Number of scans for test jobs"
    echo "  --dry-run              Show what would be done without executing"
    echo ""
    echo "Examples:"
    echo "  $0 deploy --nfs-server 192.168.1.100 --nfs-path /data/hub-load"
    echo "  $0 build-and-deploy"
    echo "  $0 test --scan-count 20"
    echo "  $0 scale --replicas 5"
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl >/dev/null 2>&1; then
        error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    # Check Docker (if building)
    if ! command -v docker >/dev/null 2>&1; then
        warning "Docker not found. Building will not be available."
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info >/dev/null 2>&1; then
        error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    success "Prerequisites check passed"
}

build_docker_image() {
    log "Building Docker image..."
    
    if [[ ! -f "$SCRIPT_DIR/Dockerfile.enhanced" ]]; then
        error "Dockerfile.enhanced not found in $SCRIPT_DIR"
        exit 1
    fi
    
    cd "$SCRIPT_DIR"
    docker build -f Dockerfile.enhanced -t "$IMAGE_NAME" .
    
    success "Docker image built: $IMAGE_NAME"
    
    # Show image info
    docker images "$IMAGE_NAME"
}

update_nfs_config() {
    local nfs_server="$1"
    local nfs_path="$2"
    
    if [[ -z "$nfs_server" || -z "$nfs_path" ]]; then
        error "NFS server and path required"
        log "Use: $0 update-nfs --nfs-server SERVER --nfs-path PATH"
        exit 1
    fi
    
    log "Updating NFS configuration..."
    log "NFS Server: $nfs_server"
    log "NFS Path: $nfs_path"
    
    # Update the deployment YAML with NFS details
    local pv_file="$K8S_DIR/hub-load-deployment.yaml"
    
    if [[ -f "$pv_file" ]]; then
        # Use sed to update NFS server and path
        sed -i.bak \
            -e "s|server: .*|server: $nfs_server|" \
            -e "s|path: .*|path: $nfs_path|" \
            "$pv_file"
        
        success "NFS configuration updated in $pv_file"
        log "Backup saved as ${pv_file}.bak"
    else
        error "Deployment file not found: $pv_file"
        exit 1
    fi
}

deploy_to_kubernetes() {
    local dry_run="$1"
    
    log "Deploying hub-load to Kubernetes..."
    
    # Check if k8s directory exists
    if [[ ! -d "$K8S_DIR" ]]; then
        error "Kubernetes manifests directory not found: $K8S_DIR"
        exit 1
    fi
    
    # Apply manifests
    local kubectl_cmd="kubectl apply"
    if [[ "$dry_run" == "true" ]]; then
        kubectl_cmd="kubectl apply --dry-run=client"
    fi
    
    # Create namespace first
    log "Creating namespace: $NAMESPACE"
    $kubectl_cmd -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
  labels:
    app: hub-load
    version: enhanced
EOF
    
    # Apply all manifests
    log "Applying hub-load manifests..."
    for manifest in "$K8S_DIR"/*.yaml; do
        if [[ -f "$manifest" ]]; then
            log "Applying $(basename $manifest)..."
            $kubectl_cmd -f "$manifest"
        fi
    done
    
    if [[ "$dry_run" != "true" ]]; then
        success "Hub-load deployed to Kubernetes"
        
        # Wait for deployment to be ready
        log "Waiting for deployment to be ready..."
        kubectl wait --for=condition=available --timeout=300s deployment/hub-load-deployment -n "$NAMESPACE"
        
        success "Deployment is ready!"
    else
        success "Dry run completed - no resources were created"
    fi
}

run_test_job() {
    local scan_count="${1:-10}"
    local job_name="hub-load-test-$(date +%s)"
    
    log "Running test job with $scan_count scans..."
    
    # Create test job
    kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: $job_name
  namespace: $NAMESPACE
  labels:
    app: hub-load
    type: adhoc-test
spec:
  backoffLimit: 2
  activeDeadlineSeconds: 3600
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: hub-load-test
        image: $IMAGE_NAME
        imagePullPolicy: IfNotPresent
        command: ["/app/entrypoint.sh"]
        args: ["scan"]
        env:
        - name: USE_MEMORY_MAPPING
          value: "yes"
        - name: SCAN_COUNT
          value: "$scan_count"
        - name: PARALLEL_SCANS
          value: "yes"
        - name: MAX_PARALLEL_JOBS
          value: "3"
        - name: DEBUG
          value: "yes"
        - name: LOCAL_TEST_DATA_DIR
          value: "/app/nfs-data"
        resources:
          requests:
            memory: "2Gi"
            cpu: "1"
          limits:
            memory: "6Gi"
            cpu: "3"
        volumeMounts:
        - name: nfs-data
          mountPath: /app/nfs-data
          readOnly: true
        - name: logs-volume
          mountPath: /app/logs
        securityContext:
          runAsNonRoot: true
          runAsUser: 1001
      volumes:
      - name: nfs-data
        persistentVolumeClaim:
          claimName: hub-load-nfs-pvc
      - name: logs-volume
        emptyDir:
          sizeLimit: 5Gi
EOF
    
    success "Test job created: $job_name"
    
    # Watch job progress
    log "Watching job progress... (Ctrl+C to stop watching)"
    kubectl wait --for=condition=complete --timeout=3600s job/$job_name -n "$NAMESPACE" || true
    
    # Show job logs
    log "Job logs:"
    kubectl logs -f job/$job_name -n "$NAMESPACE" || true
}

run_performance_test() {
    log "Running performance test..."
    
    local perf_job_name="hub-load-perf-$(date +%s)"
    
    kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: $perf_job_name
  namespace: $NAMESPACE
  labels:
    app: hub-load
    type: performance-test
spec:
  backoffLimit: 1
  activeDeadlineSeconds: 1800
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: hub-load-perf
        image: $IMAGE_NAME
        imagePullPolicy: IfNotPresent
        command: ["/app/entrypoint.sh"]
        args: ["test-docker-mmap"]
        env:
        - name: USE_MEMORY_MAPPING
          value: "yes"
        - name: LOCAL_TEST_DATA_DIR
          value: "/app/nfs-data"
        resources:
          requests:
            memory: "1Gi"
            cpu: "0.5"
          limits:
            memory: "4Gi"
            cpu: "2"
        volumeMounts:
        - name: nfs-data
          mountPath: /app/nfs-data
          readOnly: true
        - name: logs-volume
          mountPath: /app/logs
        securityContext:
          runAsNonRoot: true
          runAsUser: 1001
      volumes:
      - name: nfs-data
        persistentVolumeClaim:
          claimName: hub-load-nfs-pvc
      - name: logs-volume
        emptyDir:
          sizeLimit: 2Gi
EOF
    
    success "Performance test job created: $perf_job_name"
    
    # Watch and show results
    kubectl wait --for=condition=complete --timeout=1800s job/$perf_job_name -n "$NAMESPACE" || true
    kubectl logs job/$perf_job_name -n "$NAMESPACE"
}

scale_deployment() {
    local replicas="$1"
    
    if [[ -z "$replicas" ]]; then
        error "Number of replicas required"
        log "Use: $0 scale --replicas N"
        exit 1
    fi
    
    log "Scaling deployment to $replicas replicas..."
    
    kubectl scale deployment/hub-load-deployment --replicas="$replicas" -n "$NAMESPACE"
    
    # Wait for scaling to complete
    kubectl wait --for=condition=available --timeout=300s deployment/hub-load-deployment -n "$NAMESPACE"
    
    success "Deployment scaled to $replicas replicas"
}

show_logs() {
    log "Showing hub-load logs..."
    
    # Get pod names
    local pods=$(kubectl get pods -n "$NAMESPACE" -l app=hub-load -o jsonpath='{.items[*].metadata.name}')
    
    if [[ -z "$pods" ]]; then
        warning "No hub-load pods found"
        return
    fi
    
    # Show logs from all pods
    for pod in $pods; do
        log "Logs from pod: $pod"
        kubectl logs "$pod" -n "$NAMESPACE" --tail=50
        echo ""
    done
}

show_status() {
    log "Hub Load Kubernetes Status"
    echo ""
    
    # Check namespace
    if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        success "Namespace exists: $NAMESPACE"
    else
        error "Namespace not found: $NAMESPACE"
        return 1
    fi
    
    # Show deployments
    log "Deployments:"
    kubectl get deployments -n "$NAMESPACE" -o wide
    echo ""
    
    # Show pods
    log "Pods:"
    kubectl get pods -n "$NAMESPACE" -o wide
    echo ""
    
    # Show services
    log "Services:"
    kubectl get services -n "$NAMESPACE"
    echo ""
    
    # Show PVCs
    log "Persistent Volume Claims:"
    kubectl get pvc -n "$NAMESPACE"
    echo ""
    
    # Show jobs
    log "Recent Jobs:"
    kubectl get jobs -n "$NAMESPACE" --sort-by=.metadata.creationTimestamp | tail -10
    
    # Show resource usage
    log "Resource Usage:"
    kubectl top pods -n "$NAMESPACE" 2>/dev/null || log "Metrics server not available"
}

cleanup_deployment() {
    log "Cleaning up hub-load deployment..."
    
    # Delete all resources in namespace
    kubectl delete all,pvc,secret,configmap --all -n "$NAMESPACE"
    
    # Delete namespace
    kubectl delete namespace "$NAMESPACE"
    
    success "Cleanup completed"
}

# Parse command line arguments
COMMAND=""
DRY_RUN="false"
REPLICAS=""
SCAN_COUNT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        deploy|build-and-deploy|test|perf-test|scale|logs|status|cleanup|update-nfs)
            COMMAND="$1"
            shift
            ;;
        --nfs-server)
            NFS_SERVER="$2"
            shift 2
            ;;
        --nfs-path)
            NFS_PATH="$2"
            shift 2
            ;;
        --image)
            IMAGE_NAME="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --replicas)
            REPLICAS="$2"
            shift 2
            ;;
        --scan-count)
            SCAN_COUNT="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check prerequisites
check_prerequisites

# Execute command
case "$COMMAND" in
    deploy)
        if [[ -n "$NFS_SERVER" && -n "$NFS_PATH" ]]; then
            update_nfs_config "$NFS_SERVER" "$NFS_PATH"
        fi
        deploy_to_kubernetes "$DRY_RUN"
        ;;
    build-and-deploy)
        build_docker_image
        if [[ -n "$NFS_SERVER" && -n "$NFS_PATH" ]]; then
            update_nfs_config "$NFS_SERVER" "$NFS_PATH"
        fi
        deploy_to_kubernetes "$DRY_RUN"
        ;;
    test)
        run_test_job "${SCAN_COUNT:-10}"
        ;;
    perf-test)
        run_performance_test
        ;;
    scale)
        scale_deployment "$REPLICAS"
        ;;
    logs)
        show_logs
        ;;
    status)
        show_status
        ;;
    cleanup)
        cleanup_deployment
        ;;
    update-nfs)
        update_nfs_config "$NFS_SERVER" "$NFS_PATH"
        ;;
    "")
        log "No command specified. Showing help..."
        show_help
        ;;
    *)
        error "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac