#!/bin/bash

# NebulaGraph & ScyllaDB Dapr Pluggable Components Management Script
# Complete management of dual Dapr pluggable components including setup, operations, and testing

set -e

# Load environment configuration if available
if [ -f "../../../.env" ]; then
    source ../../../.env
fi

# Set default values if not already set
NEBULA_HTTP_PORT=${NEBULA_HTTP_PORT:-3501}
NEBULA_GRPC_PORT=${NEBULA_GRPC_PORT:-50001}
DAPR_PLUGABBLE_NETWORK_NAME=${DAPR_PLUGABBLE_NETWORK_NAME:-dapr-pluggable-net}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${BLUE}======================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}======================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get docker compose command (docker-compose or docker compose)
get_docker_compose_cmd() {
    if command_exists docker-compose; then
        echo "docker-compose"
    elif command_exists docker && docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    else
        return 1
    fi
}

# Validate NebulaGraph is running
validate_nebula() {
    print_info "Validating NebulaGraph infrastructure..."
    
    local nebula_deps_dir="../dependencies"
    
    if [ ! -f "$nebula_deps_dir/environment_setup.sh" ]; then
        print_error "NebulaGraph environment_setup.sh not found at $nebula_deps_dir"
        return 1
    fi
    
    # Test NebulaGraph connectivity
    print_info "Testing NebulaGraph services..."
    if ! nc -z localhost 9669 2>/dev/null; then
        print_error "NebulaGraph Graph Service is not responding on port 9669"
        print_info "Please start NebulaGraph first: cd $nebula_deps_dir && ./environment_setup.sh"
        return 1
    fi
    
    if ! nc -z localhost 9559 2>/dev/null; then
        print_error "NebulaGraph Meta Service is not responding on port 9559"
        return 1
    fi
    
    if ! nc -z localhost 9779 2>/dev/null; then
        print_error "NebulaGraph Storage Service is not responding on port 9779"
        return 1
    fi
    
    print_success "NebulaGraph infrastructure is ready"
    return 0
}

# Start Dapr pluggable components (NebulaGraph + ScyllaDB)
start_component() {
    print_info "Starting dual Dapr pluggable components..."
    
    # We're already in the setup/docker directory
    if [ ! -f "docker-compose.yml" ]; then
        print_error "docker-compose.yml not found in current directory"
        return 1
    fi
    
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd) || {
        print_error "Docker Compose is not installed or not in PATH"
        return 1
    }
    
    # Build with updated code changes (allows layer caching for dependencies)
    print_info "Building Docker services with latest code changes..."
    if ! $compose_cmd build; then
        print_error "Failed to build Docker services"
        return 1
    fi
    print_success "Docker services built successfully"
    
    if $compose_cmd up -d; then
        print_success "Dapr pluggable components started"
        
        # Wait for services to initialize
        print_info "Waiting for services to initialize..."
        sleep 10
        
        # Check if containers are running
        if $compose_cmd ps | grep -q "Up"; then
            print_success "All containers are running"
        else
            print_error "Some containers failed to start"
            return 1
        fi
    else
        print_error "Failed to start Dapr pluggable components"
        return 1
    fi
}

# Stop Dapr pluggable components
stop_component() {
    print_header "Stopping Dual Dapr Pluggable Components"
    
    if [ -f "docker-compose.yml" ]; then
        local compose_cmd
        compose_cmd=$(get_docker_compose_cmd) || {
            print_error "Docker Compose is not installed or not in PATH"
            return 1
        }
        $compose_cmd down
        print_success "Dual Dapr pluggable components stopped"
    else
        print_error "docker-compose.yml not found in current directory"
        return 1
    fi
}

# Show component status
show_status() {
    print_header "Dual Dapr Pluggable Components Status"
    
    if [ -f "docker-compose.yml" ]; then
        local compose_cmd
        compose_cmd=$(get_docker_compose_cmd) || {
            print_error "Docker Compose is not installed or not in PATH"
            return 1
        }
        $compose_cmd ps
    else
        print_error "docker-compose.yml not found in current directory"
        return 1
    fi
}

# Show component logs
show_logs() {
    print_header "Dual Dapr Pluggable Components Logs"
    
    if [ -f "docker-compose.yml" ]; then
        local compose_cmd
        compose_cmd=$(get_docker_compose_cmd) || {
            print_error "Docker Compose is not installed or not in PATH"
            return 1
        }
        if [ -n "$1" ]; then
            # Show logs for specific service
            $compose_cmd logs -f "$1"
        else
            # Show logs for all services
            $compose_cmd logs -f
        fi
    else
        print_error "docker-compose.yml not found in current directory"
        return 1
    fi
}

# Clean components (remove volumes and networks)
clean_component() {
    print_header "Cleaning Dual Dapr Pluggable Components"
    
    if [ -f "docker-compose.yml" ]; then
        local compose_cmd
        compose_cmd=$(get_docker_compose_cmd) || {
            print_error "Docker Compose is not installed or not in PATH"
            return 1
        }
        $compose_cmd down -v --remove-orphans
        print_success "Dual Dapr pluggable components cleaned"
    else
        print_error "docker-compose.yml not found in current directory"
        return 1
    fi
}

# Test Dapr components functionality
test_component() {
    print_header "Testing Dual Dapr Pluggable Components"
    
    # Test Dapr HTTP API availability
    print_info "Testing Dapr HTTP API (port $NEBULA_HTTP_PORT)..."
    if curl -s --connect-timeout 5 http://localhost:$NEBULA_HTTP_PORT/v1.0/healthz >/dev/null 2>&1; then
        print_success "Dapr HTTP API is responding"
    else
        print_error "Dapr HTTP API is not responding on port $NEBULA_HTTP_PORT"
        return 1
    fi
    
    # Test Dapr gRPC API availability
    print_info "Testing Dapr gRPC API (port 50001)..."
    if nc -z localhost 50001 2>/dev/null; then
        print_success "Dapr gRPC API is responding"
    else
        print_error "Dapr gRPC API is not responding on port 50001"
    fi
    
    # Test state store operations
    print_info "Testing NebulaGraph state store operations..."
    
    # Test SET operation
    if curl -s -X POST "http://localhost:$NEBULA_HTTP_PORT/v1.0/state/nebulagraph-state" \
        -H "Content-Type: application/json" \
        -d '[{"key": "test-key", "value": "Hello NebulaGraph!"}]' >/dev/null 2>&1; then
        print_success "State store SET operation successful"
    else
        print_error "State store SET operation failed"
        return 1
    fi
    
    # Test GET operation
    local response=$(curl -s "http://localhost:$NEBULA_HTTP_PORT/v1.0/state/nebulagraph-state/test-key" 2>/dev/null)
    if [ "$response" = '"Hello NebulaGraph!"' ]; then
        print_success "State store GET operation successful"
        print_info "Retrieved value: $response"
    else
        print_error "State store GET operation failed"
        print_info "Expected: \"Hello NebulaGraph!\", Got: $response"
        return 1
    fi
    
    # Test DELETE operation
    if curl -s -X DELETE "http://localhost:$NEBULA_HTTP_PORT/v1.0/state/nebulagraph-state/test-key" >/dev/null 2>&1; then
        print_success "State store DELETE operation successful"
    else
        print_error "State store DELETE operation failed"
    fi
    
    print_success "All Dapr components tests passed!"
}

# Simple health check for quick validation
quick_health_check() {
    print_header "Quick Health Check"
    
    # Test Dapr HTTP API availability
    print_info "Testing Dapr HTTP API (port $NEBULA_HTTP_PORT)..."
    if curl -s --connect-timeout 5 http://localhost:$NEBULA_HTTP_PORT/v1.0/healthz >/dev/null 2>&1; then
        print_success "Dapr HTTP API is responding"
    else
        print_error "Dapr HTTP API is not responding on port $NEBULA_HTTP_PORT"
        return 1
    fi
    
    # Test Dapr gRPC API availability
    print_info "Testing Dapr gRPC API (port 50001)..."
    if nc -z localhost 50001 2>/dev/null; then
        print_success "Dapr gRPC API is responding"
    else
        print_warning "Dapr gRPC API is not responding on port 50001"
    fi
    
    print_success "Basic health check completed!"
}



# Run comprehensive test using the proper test suite
run_comprehensive_test() {
    print_header "Running Comprehensive Test Suite"
    
    # Use the comprehensive test suite from the tests directory
    local test_all_script="tests/test_all.sh"
    local test_http_script="stores/nebulagraph/tests/test_http.sh"
    local test_grpc_script="stores/nebulagraph/tests/test_grpc.sh"
    
    if [ -f "$test_all_script" ]; then
        print_info "Running complete test suite (HTTP + gRPC) - 54 tests..."
        cd tests/
        if ./test_all.sh; then
            print_success "Comprehensive test suite completed successfully!"
        else
            print_error "Comprehensive test suite failed"
            cd - > /dev/null
            return 1
        fi
        cd - > /dev/null
    elif [ -f "$test_http_script" ] && [ -f "$test_grpc_script" ]; then
        print_info "Running individual test scripts..."
        cd tests/
        
        print_info "Running HTTP interface tests..."
        if ./test_http.sh; then
            print_success "HTTP tests passed"
        else
            print_error "HTTP tests failed"
            cd - > /dev/null
            return 1
        fi
        
        print_info "Running gRPC interface tests..."
        if ./test_grpc.sh; then
            print_success "gRPC tests passed"
        else
            print_error "gRPC tests failed"
            cd - > /dev/null
            return 1
        fi
        
        cd - > /dev/null
        print_success "All individual test scripts completed successfully!"
    elif [ -f "$test_http_script" ]; then
        print_warning "Only HTTP tests available, running HTTP test suite..."
        cd tests/
        if ./test_http.sh; then
            print_success "HTTP test suite completed successfully!"
        else
            print_error "HTTP test suite failed"
            cd - > /dev/null
            return 1
        fi
        cd - > /dev/null
    else
        print_error "No comprehensive test scripts found in tests/"
        print_info "Please ensure the test suite is available at tests/test_all.sh"
        return 1
    fi
}

# Main setup function
main() {
    print_header "NebulaGraph & ScyllaDB Dapr Pluggable Components Setup"
    echo -e "This script sets up and manages the dual Dapr pluggable components for NebulaGraph and ScyllaDB.\n"
    
    # 1. Validate NebulaGraph
    print_header "1. NebulaGraph Validation"
    validate_nebula
    
    # 2. Start Dapr components
    print_header "2. Dual Dapr Components Setup"
    start_component
    
    # 3. Quick health check
    print_header "3. Components Health Check"
    quick_health_check
    
    # 4. Final summary
    print_header "Dual Dapr Pluggable Components Ready"
    
    print_success "🎉 Dapr pluggable components setup completed successfully!"
    echo -e "\n${GREEN}Your dual Dapr components are ready!${NC}"
    echo -e "\n${BLUE}Available APIs:${NC}"
    echo -e "  • Dapr HTTP API: http://localhost:$NEBULA_HTTP_PORT"
    echo -e "  • Dapr gRPC API: localhost:$NEBULA_GRPC_PORT"
    echo -e "  • State Store (NebulaGraph): nebulagraph-state"
    echo -e "  • State Store (ScyllaDB): scylladb-state"
    
    echo -e "\n${BLUE}Next steps:${NC}"
    echo -e "  • Test NebulaGraph state: curl http://localhost:$NEBULA_HTTP_PORT/v1.0/state/nebulagraph-state/your-key"
    echo -e "  • Test ScyllaDB state: curl http://localhost:$NEBULA_HTTP_PORT/v1.0/state/scylladb-state/your-key"
    echo -e "  • View logs: ./run_dapr_pluggables.sh logs"
    echo -e "  • Stop components: ./run_dapr_pluggables.sh stop"
    echo -e "  • Check status: ./run_dapr_pluggables.sh status"
    echo -e "  • Run comprehensive tests: ./run_dapr_pluggables.sh test (54 tests via tests/test_all.sh)"
    echo -e "  • Quick health check: ./run_dapr_pluggables.sh health"
    
    echo ""
}

# Handle command line arguments
case "${1:-start}" in
    "start"|"setup")
        main
        ;;
    "stop"|"down")
        stop_component
        ;;
    "status")
        show_status
        ;;
    "logs")
        show_logs "$2"
        ;;
    "clean")
        clean_component
        ;;
    "health"|"health-check")
        quick_health_check
        ;;
    "test"|"test-comprehensive"|"test-full")
        run_comprehensive_test
        ;;
    "test-basic")
        test_component
        ;;
    "validate")
        validate_nebula
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [COMMAND] [OPTIONS]"
        echo ""
        echo "NebulaGraph & ScyllaDB Dapr Pluggable Components Management"
        echo ""
        echo "Commands:"
        echo "  start, setup  Set up and start the Dapr pluggable components (default)"
        echo "  stop, down    Stop the Dapr pluggable components"
        echo "  status        Show components status"
        echo "  logs [SERVICE] Show component logs (optionally for specific service)"
        echo "  health        Quick health check (API availability)"
        echo "  test          Run comprehensive test suite (HTTP + gRPC via tests/test_all.sh)"
        echo "  test-basic    Run basic component functionality test"
        echo "  validate      Validate NebulaGraph infrastructure only"
        echo "  clean         Clean up components (volumes and networks)"
        echo "  help          Show this help message"
        echo ""
        echo "Services for logs command:"
        echo "  • dapr-pluggable-component        - The Dapr pluggable component (multi-store support)"
        echo "  • dapr-pluggable-component-sidecar - The Dapr runtime sidecar"
        echo "  • nebulagraph-test-app            - The test application"
        echo ""
        echo "Setup will:"
        echo "  1. Validate NebulaGraph infrastructure is running"
        echo "  2. Start Dapr pluggable component container"
        echo "  3. Test component functionality"
        echo ""
        echo "Components deployed:"
        echo "  • Multi-Store Support (STORE_TYPES=nebulagraph,scylladb)"
        echo "  • NebulaGraph State Store: nebulagraph-state"
        echo "  • ScyllaDB State Store: scylladb-state"
        echo ""
        echo "Prerequisites:"
        echo "  • NebulaGraph must be running (use ../../../dependencies/environment_setup.sh)"
        echo "  • Docker and Docker Compose"
        echo ""
        echo "API Endpoints:"
        echo "  • Dapr HTTP API: http://localhost:$NEBULA_HTTP_PORT"
        echo "  • Dapr gRPC API: localhost:$NEBULA_GRPC_PORT"
        echo "  • Health Check: http://localhost:$NEBULA_HTTP_PORT/v1.0/healthz"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
