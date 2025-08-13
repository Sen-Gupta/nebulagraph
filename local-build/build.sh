#!/bin/bash

# NebulaGraph Dapr Pluggable Components - Local Build Script
# Usage: ./build.sh [options]
#
# This script handles everything: login, build, and push to Docker Hub
# Run from anywhere - it will find the correct directories automatically

set -e

# Load environment variables from root .env file if it exists
if [ -f "../src/.env" ]; then
    source ../src/.env
fi

# Configuration (can be overridden by .env file)
REGISTRY_USERNAME="${DOCKER_REGISTRY_USERNAME:-foodinvitesadmin}"
IMAGE_NAME="${DOCKER_IMAGE_NAME:-experiom}"
DEFAULT_TAG="${DOCKER_DEFAULT_TAG:-latest}"
COMPONENT_DIR="../src/dapr-pluggable-components"
TOKEN_FILE=".docker_token"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Parse command line arguments
PUSH_IMAGE=true
TAG="$DEFAULT_TAG"
FORCE_LOGIN=false
QUIET=false

print_help() {
    echo -e "${CYAN}NebulaGraph Dapr Pluggable Components - Local Build Script${NC}"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -t, --tag TAG          Set image tag (default: latest)"
    echo "  -n, --no-push          Build only, don't push to Docker Hub"
    echo "  -f, --force-login      Force re-authentication"
    echo "  -q, --quiet            Minimal output"
    echo "  -h, --help             Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                     # Build and push foodinvitesadmin/experiom:latest"
    echo "  $0 -t v1.0.0          # Build and push foodinvitesadmin/experiom:v1.0.0"
    echo "  $0 -n                 # Build only, no push"
    echo "  $0 -t dev-\$(date +%s) # Build with timestamp tag"
    echo ""
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -n|--no-push)
            PUSH_IMAGE=false
            shift
            ;;
        -f|--force-login)
            FORCE_LOGIN=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_help
            exit 1
            ;;
    esac
done

FULL_IMAGE_NAME="${REGISTRY_USERNAME}/${IMAGE_NAME}:${TAG}"

# Function to print colored output
print_status() {
    if [ "$QUIET" = false ]; then
        echo -e "${GREEN}[INFO]${NC} $1"
    fi
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    if [ "$QUIET" = false ]; then
        echo -e "${BLUE}================================================${NC}"
        echo -e "${BLUE}  NebulaGraph Dapr Pluggable Components${NC}"
        echo -e "${BLUE}           Local Build Script${NC}"
        echo -e "${BLUE}================================================${NC}"
        echo ""
    fi
}

# Check prerequisites
check_prerequisites() {
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi

    # Find component directory
    if [ ! -d "$COMPONENT_DIR" ]; then
        print_error "Component directory not found: $COMPONENT_DIR"
        print_error "Please run this script from the local-build directory"
        exit 1
    fi

    # Check if Dockerfile exists
    if [ ! -f "$COMPONENT_DIR/Dockerfile" ]; then
        print_error "Dockerfile not found in $COMPONENT_DIR"
        exit 1
    fi

    # Check if main.go exists
    if [ ! -f "$COMPONENT_DIR/main.go" ]; then
        print_warning "main.go not found in $COMPONENT_DIR"
    fi
}

# Docker Hub authentication
handle_docker_login() {
    if [ "$PUSH_IMAGE" = false ]; then
        return 0
    fi

    # Check if already logged in and not forcing re-login
    if [ "$FORCE_LOGIN" = false ] && docker info 2>/dev/null | grep -q "Username: ${REGISTRY_USERNAME}"; then
        print_status "Already logged in to Docker Hub as ${REGISTRY_USERNAME}"
        return 0
    fi

    print_status "Authenticating with Docker Hub..."
    
    # Check if token file exists
    if [ -f "${TOKEN_FILE}" ] && [ "$FORCE_LOGIN" = false ]; then
        print_status "Using saved authentication token..."
        TOKEN=$(cat "${TOKEN_FILE}")
        echo "${TOKEN}" | docker login -u "${REGISTRY_USERNAME}" --password-stdin > /dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            print_status "Successfully authenticated with saved token"
            return 0
        else
            print_warning "Saved token expired or invalid, requesting new token..."
        fi
    fi

    # Request new token
    echo ""
    echo -e "${CYAN}Docker Hub Authentication Required${NC}"
    echo "Username: ${REGISTRY_USERNAME}"
    echo ""
    read -s -p "Enter Docker Hub Token: " TOKEN
    echo ""
    
    # Test login
    echo "${TOKEN}" | docker login -u "${REGISTRY_USERNAME}" --password-stdin > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        # Save token for future use
        echo "${TOKEN}" > "${TOKEN_FILE}"
        chmod 600 "${TOKEN_FILE}"
        print_status "Authentication successful and token saved"
    else
        print_error "Authentication failed!"
        exit 1
    fi
}

# Build Docker image
build_image() {
    print_status "Building Docker image: ${FULL_IMAGE_NAME}"
    
    # Use environment variables from .env file, with fallbacks
    BUILD_TIME="${BUILDTIME:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"
    BUILD_VERSION="${VERSION:-${TAG}}"
    
    # Get git revision, use env variable as fallback
    if git rev-parse --git-dir > /dev/null 2>&1; then
        BUILD_REVISION=$(git rev-parse --short HEAD)
    else
        BUILD_REVISION="${REVISION:-unknown}"
    fi

    if [ "$QUIET" = false ]; then
        echo "  - Build Time: ${BUILD_TIME}"
        echo "  - Version: ${BUILD_VERSION}"
        echo "  - Revision: ${BUILD_REVISION}"
        echo ""
    fi

    # Change to component directory for build
    cd "$COMPONENT_DIR"
    
    # Build the image
    if [ "$QUIET" = true ]; then
        docker build \
            --build-arg BUILDTIME="${BUILD_TIME}" \
            --build-arg VERSION="${BUILD_VERSION}" \
            --build-arg REVISION="${BUILD_REVISION}" \
            --tag "${FULL_IMAGE_NAME}" \
            --platform linux/amd64 \
            . > /dev/null 2>&1
    else
        docker build \
            --build-arg BUILDTIME="${BUILD_TIME}" \
            --build-arg VERSION="${BUILD_VERSION}" \
            --build-arg REVISION="${BUILD_REVISION}" \
            --tag "${FULL_IMAGE_NAME}" \
            --platform linux/amd64 \
            .
    fi

    if [ $? -eq 0 ]; then
        print_status "Build completed successfully"
    else
        print_error "Build failed!"
        exit 1
    fi
    
    # Return to original directory
    cd - > /dev/null
}

# Push to Docker Hub
push_image() {
    if [ "$PUSH_IMAGE" = false ]; then
        print_status "Skipping push (--no-push specified)"
        return 0
    fi

    print_status "Pushing image to Docker Hub..."
    
    if [ "$QUIET" = true ]; then
        docker push "${FULL_IMAGE_NAME}" > /dev/null 2>&1
    else
        docker push "${FULL_IMAGE_NAME}"
    fi
    
    if [ $? -eq 0 ]; then
        print_status "Push completed successfully!"
        echo ""
        echo -e "${GREEN}✓ Image available at: https://hub.docker.com/r/${REGISTRY_USERNAME}/${IMAGE_NAME}${NC}"
        echo -e "${GREEN}✓ Pull command: docker pull ${FULL_IMAGE_NAME}${NC}"
    else
        print_error "Push failed!"
        exit 1
    fi
}

# Show image information
show_image_info() {
    if [ "$QUIET" = false ]; then
        echo ""
        print_status "Local Images:"
        docker images "${REGISTRY_USERNAME}/${IMAGE_NAME}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" 2>/dev/null || true
    fi
}

# Main execution
main() {
    print_header
    
    if [ "$QUIET" = false ]; then
        echo "Configuration:"
        echo "  - Image: ${FULL_IMAGE_NAME}"
        echo "  - Push: ${PUSH_IMAGE}"
        echo "  - Component Dir: ${COMPONENT_DIR}"
        echo ""
    fi
    
    check_prerequisites
    handle_docker_login
    build_image
    push_image
    show_image_info
    
    if [ "$QUIET" = false ]; then
        echo ""
        echo -e "${BLUE}================================================${NC}"
        echo -e "${GREEN}Build Script Completed Successfully!${NC}"
        echo -e "${BLUE}================================================${NC}"
    fi
}

# Handle script interruption
trap 'echo -e "\n${RED}Build interrupted!${NC}"; exit 1' INT TERM

# Run main function
main "$@"
