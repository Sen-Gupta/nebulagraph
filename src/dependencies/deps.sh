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
DEPENDENCIES_DIR="$SCRIPT_DIR"

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
        print_info "NebulaGraph Graph Service: localhost:9669"
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
    "test")
        print_header "Testing NebulaGraph Dependencies"
        
        # Test NebulaGraph Graph Service
        print_info "Testing NebulaGraph Graph Service (port 9669)..."
        if nc -z localhost 9669 2>/dev/null; then
            print_success "NebulaGraph Graph Service is responding"
        else
            print_error "NebulaGraph Graph Service is not responding on port 9669"
        fi
        
        # Test NebulaGraph Studio
        print_info "Testing NebulaGraph Studio (port 7001)..."
        if curl -s --connect-timeout 5 http://localhost:7001 >/dev/null 2>&1; then
            print_success "NebulaGraph Studio is responding"
        else
            print_error "NebulaGraph Studio is not responding on port 7001"
        fi
        
        # Test Meta Service
        print_info "Testing NebulaGraph Meta Service (port 9559)..."
        if nc -z localhost 9559 2>/dev/null; then
            print_success "NebulaGraph Meta Service is responding"
        else
            print_error "NebulaGraph Meta Service is not responding on port 9559"
        fi
        
        # Test Storage Service
        print_info "Testing NebulaGraph Storage Service (port 9779)..."
        if nc -z localhost 9779 2>/dev/null; then
            print_success "NebulaGraph Storage Service is responding"
        else
            print_error "NebulaGraph Storage Service is not responding on port 9779"
        fi
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
        echo "  test      Test NebulaGraph services connectivity"
        echo "  clean     Clean up dependencies (volumes and networks)"
        echo "  help      Show this help"
        echo ""
        echo "Access Points:"
        echo "  • NebulaGraph Studio: http://localhost:7001"
        echo "  • NebulaGraph Graph Service: localhost:9669"
        echo "  • NebulaGraph Meta Service: localhost:9559"
        echo "  • NebulaGraph Storage Service: localhost:9779"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac
