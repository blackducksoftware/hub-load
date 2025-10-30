#!/bin/bash
#
# Kubernetes deployment script for Hub Load Testing
#

set -e

# Configuration
NAMESPACE="hub-load"
IMAGE_NAME="hub-load-test"
IMAGE_TAG="latest"
DOCKER_REGISTRY=${DOCKER_REGISTRY:-""}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is required but not installed"
        exit 1
    fi
    
    # Check docker
    if ! command -v docker &> /dev/null; then
        log_error "docker is required but not installed"
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Build Docker image
build_image() {
    log_info "Building Docker image..."
    
    cd "$(dirname "$0")/.."
    
    if [ -n "$DOCKER_REGISTRY" ]; then
        FULL_IMAGE_NAME="$DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
    else
        FULL_IMAGE_NAME="$IMAGE_NAME:$IMAGE_TAG"
    fi
    
    docker build -t "$FULL_IMAGE_NAME" .
    
    if [ -n "$DOCKER_REGISTRY" ]; then
        log_info "Pushing image to registry..."
        docker push "$FULL_IMAGE_NAME"
    fi
    
    log_success "Docker image built: $FULL_IMAGE_NAME"
}

# Create namespace
create_namespace() {
    log_info "Creating namespace..."
    
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_warning "Namespace $NAMESPACE already exists"
    else
        kubectl create namespace "$NAMESPACE"
        log_success "Namespace $NAMESPACE created"
    fi
}

# Deploy base resources
deploy_base() {
    log_info "Deploying base resources..."
    
    kubectl apply -f k8s/hub-load-deployment.yaml
    log_success "Base resources deployed"
}

# Deploy jobs
deploy_jobs() {
    log_info "Deploying job resources..."
    
    kubectl apply -f k8s/hub-load-jobs.yaml
    log_success "Job resources deployed"
}

# Deploy parallel scanning
deploy_parallel() {
    log_info "Deploying parallel scanning resources..."
    
    kubectl apply -f k8s/hub-load-parallel.yaml
    log_success "Parallel scanning resources deployed"
}

# Deploy monitoring
deploy_monitoring() {
    log_info "Deploying monitoring resources..."
    
    if kubectl api-resources | grep -q servicemonitors; then
        kubectl apply -f k8s/hub-load-monitoring.yaml
        log_success "Monitoring resources deployed"
    else
        log_warning "ServiceMonitor CRD not found, skipping monitoring deployment"
        log_warning "Install Prometheus Operator to enable monitoring"
    fi
}

# Update secrets
update_secrets() {
    log_info "Updating secrets..."
    
    # Check if secrets exist
    if kubectl get secret hub-load-secrets -n "$NAMESPACE" &> /dev/null; then
        log_warning "Secrets already exist. Please update them manually if needed."
        log_info "To update BD_HUB_URL: kubectl patch secret hub-load-secrets -n $NAMESPACE -p '{\"data\":{\"BD_HUB_URL\":\"<base64-encoded-url>\"}}'"
        log_info "To update API_TOKEN: kubectl patch secret hub-load-secrets -n $NAMESPACE -p '{\"data\":{\"API_TOKEN\":\"<base64-encoded-token>\"}}'"
    else
        log_warning "Please update the secrets in k8s/hub-load-deployment.yaml with your actual values"
        log_info "Base64 encode your values: echo -n 'your-value' | base64"
    fi
    
    if kubectl get secret gcs-service-account -n "$NAMESPACE" &> /dev/null; then
        log_warning "GCS service account secret already exists"
    else
        log_warning "Please update the GCS service account key in k8s/hub-load-deployment.yaml"
        log_info "Base64 encode your service account JSON: cat service-account.json | base64 -w 0"
    fi
}

# Check deployment status
check_status() {
    log_info "Checking deployment status..."
    
    echo ""
    log_info "Namespace resources:"
    kubectl get all -n "$NAMESPACE"
    
    echo ""
    log_info "Pod status:"
    kubectl get pods -n "$NAMESPACE" -o wide
    
    echo ""
    log_info "PVC status:"
    kubectl get pvc -n "$NAMESPACE"
    
    echo ""
    log_info "Recent events:"
    kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -10
}

# Show logs
show_logs() {
    log_info "Recent logs from hub-load pods..."
    
    PODS=$(kubectl get pods -n "$NAMESPACE" -l app=hub-load -o jsonpath='{.items[*].metadata.name}')
    
    for pod in $PODS; do
        echo ""
        log_info "Logs from pod: $pod"
        kubectl logs -n "$NAMESPACE" "$pod" --tail=20 || true
    done
}

# Scale deployment
scale_deployment() {
    local replicas=$1
    if [ -z "$replicas" ]; then
        log_error "Please specify number of replicas"
        exit 1
    fi
    
    log_info "Scaling parallel scanner to $replicas replicas..."
    kubectl scale deployment hub-load-parallel-scanner -n "$NAMESPACE" --replicas="$replicas"
    log_success "Deployment scaled to $replicas replicas"
}

# Run test job
run_test() {
    log_info "Running test job..."
    
    # Create a test job based on the existing job template
    kubectl create job hub-load-test-$(date +%s) \
        --from=cronjob/hub-load-scheduled-scan \
        -n "$NAMESPACE"
    
    log_success "Test job created"
    log_info "Monitor with: kubectl logs -f job/hub-load-test-* -n $NAMESPACE"
}

# Clean up resources
cleanup() {
    log_info "Cleaning up resources..."
    
    log_warning "This will delete all hub-load resources. Are you sure? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        kubectl delete namespace "$NAMESPACE" --ignore-not-found=true
        log_success "Resources cleaned up"
    else
        log_info "Cleanup cancelled"
    fi
}

# Show usage
usage() {
    echo "Hub Load Kubernetes Deployment Script"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  deploy-all          Deploy all resources (recommended for first time)"
    echo "  deploy-base         Deploy base resources only"
    echo "  deploy-jobs         Deploy job resources only"
    echo "  deploy-parallel     Deploy parallel scanning resources only"
    echo "  deploy-monitoring   Deploy monitoring resources only"
    echo "  build              Build and optionally push Docker image"
    echo "  status             Check deployment status"
    echo "  logs               Show recent logs"
    echo "  scale <replicas>   Scale parallel deployment"
    echo "  test               Run a test job"
    echo "  cleanup            Delete all resources"
    echo "  help               Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  DOCKER_REGISTRY    Docker registry to push images to"
    echo "  IMAGE_TAG          Docker image tag (default: latest)"
    echo ""
    echo "Examples:"
    echo "  $0 deploy-all                    # Deploy everything"
    echo "  $0 scale 10                      # Scale to 10 parallel scanners"
    echo "  DOCKER_REGISTRY=gcr.io/my-project $0 build  # Build and push to GCR"
}

# Main execution
main() {
    case "$1" in
        deploy-all)
            check_prerequisites
            build_image
            create_namespace
            deploy_base
            deploy_jobs
            deploy_parallel
            deploy_monitoring
            update_secrets
            check_status
            ;;
        deploy-base)
            check_prerequisites
            create_namespace
            deploy_base
            update_secrets
            ;;
        deploy-jobs)
            check_prerequisites
            deploy_jobs
            ;;
        deploy-parallel)
            check_prerequisites
            deploy_parallel
            ;;
        deploy-monitoring)
            check_prerequisites
            deploy_monitoring
            ;;
        build)
            check_prerequisites
            build_image
            ;;
        status)
            check_status
            ;;
        logs)
            show_logs
            ;;
        scale)
            scale_deployment "$2"
            ;;
        test)
            run_test
            ;;
        cleanup)
            cleanup
            ;;
        help|--help|-h)
            usage
            ;;
        "")
            log_error "No command specified"
            usage
            exit 1
            ;;
        *)
            log_error "Unknown command: $1"
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"