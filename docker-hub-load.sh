#!/bin/bash

# Hub Load Docker Build and Deployment Script
# Enhanced with Memory Mapping Optimization

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Configuration
IMAGE_NAME="hub-load"
IMAGE_TAG="enhanced"
CONTAINER_NAME="hub-load-performance"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
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
    echo "Hub Load Docker Management Script"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  build                 Build the Docker image"
    echo "  run                   Run the container with default settings"
    echo "  start                 Start container with docker-compose"
    echo "  stop                  Stop the container"
    echo "  logs                  Show container logs"
    echo "  shell                 Access container shell"
    echo "  test                  Run memory mapping tests"
    echo "  test-docker           Test Docker memory mapping integration"
    echo "  validate              Validate memory mapping performance"
    echo "  clean                 Clean up containers and images"
    echo "  status                Show container status"
    echo "  help                  Show this help message"
    echo ""
    echo "Build Options:"
    echo "  --no-cache            Build without using cache"
    echo "  --tag TAG             Custom image tag (default: enhanced)"
    echo ""
    echo "Run Options:"
    echo "  --data-dir DIR        Local test data directory"
    echo "  --log-dir DIR         Log output directory"
    echo "  --config-dir DIR      Configuration directory"
    echo "  --scan-count N        Number of scans to run"
    echo "  --parallel            Enable parallel scans"
    echo "  --debug               Enable debug mode"
    echo "  --dry-run             Run in dry-run mode"
    echo ""
    echo "Examples:"
    echo "  $0 build --no-cache"
    echo "  $0 run --data-dir /path/to/data --scan-count 5"
    echo "  $0 start"
    echo "  $0 test"
}

build_image() {
    local no_cache=""
    local custom_tag="$IMAGE_TAG"
    
    # Parse build options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-cache)
                no_cache="--no-cache"
                shift
                ;;
            --tag)
                custom_tag="$2"
                shift 2
                ;;
            *)
                warning "Unknown build option: $1"
                shift
                ;;
        esac
    done
    
    log "Building Docker image: ${IMAGE_NAME}:${custom_tag}"
    log "Memory mapping optimization: ENABLED (27.5% performance improvement)"
    
    # Check if required files exist
    if [[ ! -f "Dockerfile.enhanced" ]]; then
        error "Dockerfile.enhanced not found!"
        exit 1
    fi
    
    if [[ ! -f "src/hub_load/core/submit_scans_fixed.sh" ]]; then
        error "Main scan script not found!"
        exit 1
    fi
    
    # Build the image
    docker build $no_cache \
        -f Dockerfile.enhanced \
        -t "${IMAGE_NAME}:${custom_tag}" \
        -t "${IMAGE_NAME}:latest" \
        .
    
    success "Docker image built successfully: ${IMAGE_NAME}:${custom_tag}"
    
    # Show image info
    log "Image details:"
    docker images "${IMAGE_NAME}:${custom_tag}"
}

run_container() {
    local data_dir=""
    local log_dir="./logs"
    local config_dir="./config"
    local scan_count="10"
    local parallel_scans="no"
    local debug="no"
    local dry_run="no"
    local extra_env=""
    
    # Parse run options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --data-dir)
                data_dir="$2"
                shift 2
                ;;
            --log-dir)
                log_dir="$2"
                shift 2
                ;;
            --config-dir)
                config_dir="$2"
                shift 2
                ;;
            --scan-count)
                scan_count="$2"
                shift 2
                ;;
            --parallel)
                parallel_scans="yes"
                shift
                ;;
            --debug)
                debug="yes"
                shift
                ;;
            --dry-run)
                dry_run="yes"
                shift
                ;;
            *)
                warning "Unknown run option: $1"
                shift
                ;;
        esac
    done
    
    # Create directories if they don't exist
    mkdir -p "$log_dir"
    mkdir -p "$config_dir"
    
    # Build volume mounts
    local volume_mounts="-v $(pwd)/$log_dir:/app/logs"
    volume_mounts="$volume_mounts -v $(pwd)/$config_dir:/app/config:ro"
    
    if [[ -n "$data_dir" ]]; then
        if [[ -d "$data_dir" ]]; then
            volume_mounts="$volume_mounts -v $data_dir:/app/test-data:ro"
            log "Mounting test data: $data_dir"
        else
            warning "Data directory not found: $data_dir"
        fi
    fi
    
    # Stop existing container if running
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    
    log "Starting Hub Load container with optimizations..."
    log "Configuration:"
    log "  - Scan count: $scan_count"
    log "  - Parallel scans: $parallel_scans"
    log "  - Memory mapping: ENABLED"
    log "  - Debug mode: $debug"
    log "  - Dry run: $dry_run"
    
    # Run the container
    docker run -d \
        --name "$CONTAINER_NAME" \
        --restart unless-stopped \
        -e "SCAN_COUNT=$scan_count" \
        -e "PARALLEL_SCANS=$parallel_scans" \
        -e "DEBUG=$debug" \
        -e "DRY_RUN=$dry_run" \
        -e "USE_MEMORY_MAPPING=yes" \
        $volume_mounts \
        "${IMAGE_NAME}:${IMAGE_TAG}" \
        scan
    
    success "Container started: $CONTAINER_NAME"
    log "View logs with: $0 logs"
    log "Access shell with: $0 shell"
}

start_compose() {
    log "Starting with docker-compose..."
    
    # Check if docker-compose.yml exists
    if [[ ! -f "docker-compose.yml" ]]; then
        error "docker-compose.yml not found!"
        exit 1
    fi
    
    docker-compose up -d
    success "Hub Load service started with docker-compose"
    
    log "Service status:"
    docker-compose ps
}

stop_container() {
    log "Stopping Hub Load containers..."
    
    # Stop single container
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    
    # Stop compose services
    if [[ -f "docker-compose.yml" ]]; then
        docker-compose down
    fi
    
    success "Containers stopped"
}

show_logs() {
    log "Showing container logs..."
    
    if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        docker logs -f "$CONTAINER_NAME"
    elif docker-compose ps -q hub-load | grep -q .; then
        docker-compose logs -f hub-load
    else
        warning "No running container found"
        log "Recent logs from stopped container:"
        docker logs --tail 50 "$CONTAINER_NAME" 2>/dev/null || echo "No logs available"
    fi
}

access_shell() {
    log "Accessing container shell..."
    
    if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        docker exec -it "$CONTAINER_NAME" /bin/bash
    elif docker-compose ps -q hub-load | grep -q .; then
        docker-compose exec hub-load /bin/bash
    else
        log "No running container found. Starting temporary shell..."
        docker run --rm -it \
            -v "$(pwd)/logs:/app/logs" \
            -v "$(pwd)/config:/app/config:ro" \
            "${IMAGE_NAME}:${IMAGE_TAG}" \
            shell
    fi
}

run_tests() {
    log "Running memory mapping performance tests..."
    
    echo "1. Testing Docker memory mapping integration..."
    docker run --rm -it \
        -v "$(pwd)/logs:/app/logs" \
        "${IMAGE_NAME}:${IMAGE_TAG}" \
        test-docker-mmap
    
    echo ""
    echo "2. Testing memory mapping performance..."
    docker run --rm -it \
        -v "$(pwd)/logs:/app/logs" \
        "${IMAGE_NAME}:${IMAGE_TAG}" \
        test-mmap
}

test_docker_integration() {
    log "Testing Docker memory mapping integration..."
    
    docker run --rm -it \
        -v "$(pwd)/logs:/app/logs" \
        "${IMAGE_NAME}:${IMAGE_TAG}" \
        test-docker-mmap
}

validate_setup() {
    log "Validating memory mapping setup..."
    
    docker run --rm -it \
        -v "$(pwd)/logs:/app/logs" \
        "${IMAGE_NAME}:${IMAGE_TAG}" \
        validate
}

cleanup() {
    log "Cleaning up Docker resources..."
    
    # Stop and remove containers
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    
    if [[ -f "docker-compose.yml" ]]; then
        docker-compose down -v
    fi
    
    # Remove images (optional)
    read -p "Remove Docker images? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker rmi "${IMAGE_NAME}:${IMAGE_TAG}" 2>/dev/null || true
        docker rmi "${IMAGE_NAME}:latest" 2>/dev/null || true
        success "Images removed"
    fi
    
    # Clean up unused resources
    docker system prune -f
    success "Cleanup completed"
}

show_status() {
    log "Hub Load Container Status"
    echo ""
    
    # Check if image exists
    if docker images -q "${IMAGE_NAME}:${IMAGE_TAG}" | grep -q .; then
        success "Image available: ${IMAGE_NAME}:${IMAGE_TAG}"
        docker images "${IMAGE_NAME}:${IMAGE_TAG}"
    else
        warning "Image not found: ${IMAGE_NAME}:${IMAGE_TAG}"
        log "Run '$0 build' to create the image"
    fi
    
    echo ""
    
    # Check container status
    if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        success "Container running: $CONTAINER_NAME"
        docker ps -f name="$CONTAINER_NAME"
    elif docker ps -aq -f name="$CONTAINER_NAME" | grep -q .; then
        warning "Container exists but stopped: $CONTAINER_NAME"
        docker ps -a -f name="$CONTAINER_NAME"
    else
        log "No container found: $CONTAINER_NAME"
    fi
    
    echo ""
    
    # Check compose status
    if [[ -f "docker-compose.yml" ]]; then
        log "Docker Compose Status:"
        docker-compose ps 2>/dev/null || log "Docker Compose not running"
    fi
}

# Main script logic
case "${1:-help}" in
    build)
        shift
        build_image "$@"
        ;;
    run)
        shift
        run_container "$@"
        ;;
    start)
        start_compose
        ;;
    stop)
        stop_container
        ;;
    logs)
        show_logs
        ;;
    shell)
        access_shell
        ;;
    test)
        run_tests
        ;;
    test-docker)
        test_docker_integration
        ;;
    validate)
        validate_setup
        ;;
    clean)
        cleanup
        ;;
    status)
        show_status
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac