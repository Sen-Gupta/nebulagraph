#!/bin/bash

# Quick Dependencies Startup Script
# Starts only NebulaGraph dependencies in Docker

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${BLUE}======================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}======================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Get the script directory and set paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
DEPENDENCIES_DIR="$SCRIPT_DIR/dependencies"

case "${1:-start}" in
    "start"|"up")
        print_header "Starting NebulaGraph Dependencies"
        cd "$DEPENDENCIES_DIR"
        
        print_info "Starting NebulaGraph cluster..."
        docker-compose up -d
        
        print_info "Waiting for services to initialize..."
        sleep 5
        
        print_success "NebulaGraph dependencies are ready!"
        print_info "Access NebulaGraph Studio at: http://localhost:7001"
        print_info "You can now run: ./apps.sh start"
        ;;
    "stop"|"down")
        print_header "Stopping NebulaGraph Dependencies"
        cd "$DEPENDENCIES_DIR"
        docker-compose down
        print_success "NebulaGraph dependencies stopped"
        ;;
    "status")
        print_header "NebulaGraph Dependencies Status"
        cd "$DEPENDENCIES_DIR"
        docker-compose ps
        ;;
    "logs")
        print_header "NebulaGraph Dependencies Logs"
        cd "$DEPENDENCIES_DIR"
        docker-compose logs -f
        ;;
    "clean")
        print_header "Cleaning NebulaGraph Dependencies"
        cd "$DEPENDENCIES_DIR"
        docker-compose down -v --remove-orphans
        print_success "NebulaGraph dependencies cleaned"
        ;;
    "init")
        print_header "Initializing NebulaGraph Cluster"
        cd "$DEPENDENCIES_DIR"
        ./init_nebula.sh
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [COMMAND]"
        echo ""
        echo "NebulaGraph Dependencies Management - Docker containers only"
        echo ""
        echo "Commands:"
        echo "  start     Start NebulaGraph dependencies (metad, storaged, graphd, studio, console)"
        echo "  stop      Stop NebulaGraph dependencies"
        echo "  status    Show dependency status"
        echo "  logs      Show dependency logs"
        echo "  init      Initialize NebulaGraph cluster (run after first start)"
        echo "  clean     Clean up dependencies (volumes and networks)"
        echo "  help      Show this help"
        echo ""
        echo "Note: Use ../apps.sh to manage Dapr components and TestAPI"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac
