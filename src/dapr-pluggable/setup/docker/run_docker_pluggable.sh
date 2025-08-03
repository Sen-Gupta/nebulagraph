#!/bin/bash

# NebulaGraph Dapr Pluggable Component Management Script
# Complete management of Dapr pluggable component including setup, operations, and testing

set     print_info "Testing Dapr HTTP API (port 3501)..."
    if curl -s --connect-timeout 5 http://localhost:3501/v1.0/healthz >/dev/null 2>&1; then
        print_success "Dapr HTTP API is accessible"
    else
        print_error "Dapr HTTP API is not responding on port 3501" Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper function          echo "  test-full     Run comprehensive tests (uses tests/test_component.sh if available)"
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

# Validate NebulaGraph is running
validate_nebula() {
    print_info "Validating NebulaGraph infrastructure..."
    
    local nebula_deps_dir="../../../dependencies"
    
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

# Start Dapr pluggable component
start_component() {
    print_info "Starting Dapr pluggable component..."
    
    # We're already in the setup/docker directory
    if [ ! -f "docker-compose.yml" ]; then
        print_error "docker-compose.yml not found in current directory"
        return 1
    fi
    
    if docker-compose up -d; then
        print_success "Dapr pluggable component started"
        
        # Wait for services to initialize
        print_info "Waiting for Dapr runtime to initialize..."
        sleep 10
        
        # Check if containers are running
        if docker-compose ps | grep -q "Up"; then
            print_success "All containers are running"
        else
            print_error "Some containers failed to start"
            return 1
        fi
    else
        print_error "Failed to start Dapr pluggable component"
        return 1
    fi
}

# Stop Dapr pluggable component
stop_component() {
    print_header "Stopping Dapr Pluggable Component"
    
    if [ -f "docker-compose.yml" ]; then
        docker-compose down
        print_success "Dapr pluggable component stopped"
    else
        print_error "docker-compose.yml not found in current directory"
        return 1
    fi
}

# Show component status
show_status() {
    print_header "Dapr Pluggable Component Status"
    
    if [ -f "docker-compose.yml" ]; then
        docker-compose ps
    else
        print_error "docker-compose.yml not found in current directory"
        return 1
    fi
}

# Show component logs
show_logs() {
    print_header "Dapr Pluggable Component Logs"
    
    if [ -f "docker-compose.yml" ]; then
        if [ -n "$1" ]; then
            # Show logs for specific service
            docker-compose logs -f "$1"
        else
            # Show logs for all services
            docker-compose logs -f
        fi
    else
        print_error "docker-compose.yml not found in current directory"
        return 1
    fi
}

# Clean component (remove volumes and networks)
clean_component() {
    print_header "Cleaning Dapr Pluggable Component"
    
    if [ -f "docker-compose.yml" ]; then
        docker-compose down -v --remove-orphans
        print_success "Dapr pluggable component cleaned"
    else
        print_error "docker-compose.yml not found in current directory"
        return 1
    fi
}

# Test Dapr component functionality
test_component() {
    print_header "Testing Dapr Pluggable Component"
    
    # Test Dapr HTTP API availability
    print_info "Testing Dapr HTTP API (port 3501)..."
    if curl -s --connect-timeout 5 http://localhost:3501/v1.0/healthz >/dev/null 2>&1; then
        print_success "Dapr HTTP API is responding"
    else
        print_error "Dapr HTTP API is not responding on port 3501"
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
    if curl -s -X POST "http://localhost:3501/v1.0/state/nebulagraph-state" \
        -H "Content-Type: application/json" \
        -d '[{"key": "test-key", "value": "Hello NebulaGraph!"}]' >/dev/null 2>&1; then
        print_success "State store SET operation successful"
    else
        print_error "State store SET operation failed"
        return 1
    fi
    
    # Test GET operation
    local response=$(curl -s "http://localhost:3501/v1.0/state/nebulagraph-state/test-key" 2>/dev/null)
    if [ "$response" = '"Hello NebulaGraph!"' ]; then
        print_success "State store GET operation successful"
        print_info "Retrieved value: $response"
    else
        print_error "State store GET operation failed"
        print_info "Expected: \"Hello NebulaGraph!\", Got: $response"
        return 1
    fi
    
    # Test DELETE operation
    if curl -s -X DELETE "http://localhost:3501/v1.0/state/nebulagraph-state/test-key" >/dev/null 2>&1; then
        print_success "State store DELETE operation successful"
    else
        print_error "State store DELETE operation failed"
    fi
    
    print_success "All Dapr component tests passed!"
}

# Run comprehensive test using test_all.sh (HTTP + gRPC) if available
run_comprehensive_test() {
    print_header "Running Comprehensive Component Test (HTTP + gRPC)"
    
    # Look for test_all.sh in the tests directory (comprehensive test suite)
    local test_all_script="../../tests/test_all.sh"
    local test_http_script="../../tests/test_component.sh"
    
    if [ -f "$test_all_script" ]; then
        print_info "Running complete test suite (HTTP + gRPC)..."
        cd ../../tests/
        ./test_all.sh
        cd - > /dev/null
    elif [ -f "$test_http_script" ]; then
        print_warning "Complete test suite not found, running HTTP tests only..."
        cd ../../tests/
        ./test_component.sh
        cd - > /dev/null
    else
        print_warning "No test scripts found, running basic inline tests..."
        test_component
    fi
}

# Main setup function
main() {
    print_header "NebulaGraph Dapr Pluggable Component Setup"
    echo -e "This script sets up and manages the Dapr pluggable component for NebulaGraph.\n"
    
    # 1. Validate NebulaGraph
    print_header "1. NebulaGraph Validation"
    validate_nebula
    
    # 2. Start Dapr component
    print_header "2. Dapr Component Setup"
    start_component
    
    # 3. Test component
    print_header "3. Component Testing"
    test_component
    
    # 4. Final summary
    print_header "Dapr Pluggable Component Ready"
    
    print_success "🎉 Dapr pluggable component setup completed successfully!"
    echo -e "\n${GREEN}Your Dapr component is ready!${NC}"
    echo -e "\n${BLUE}Available APIs:${NC}"
    echo -e "  • Dapr HTTP API: http://localhost:3501"
    echo -e "  • Dapr gRPC API: localhost:50001"
    echo -e "  • State Store: nebulagraph-state"
    
    echo -e "\n${BLUE}Next steps:${NC}"
    echo -e "  • Test state operations: curl http://localhost:3501/v1.0/state/nebulagraph-state/your-key"
    echo -e "  • View logs: ./run_docker_pluggable.sh logs"
    echo -e "  • Stop component: ./run_docker_pluggable.sh stop"
    echo -e "  • Check status: ./run_docker_pluggable.sh status"
    echo -e "  • Run comprehensive tests: ../../tests/test_all.sh (HTTP + gRPC)"
    echo -e "  • Run HTTP tests only: ../../tests/test_component.sh"
    echo -e "  • Run gRPC tests only: ../../tests/test_component_grpc.sh"
    
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
    "test")
        test_component
        ;;
    "test-full")
        run_comprehensive_test
        ;;
    "validate")
        validate_nebula
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [COMMAND] [OPTIONS]"
        echo ""
        echo "NebulaGraph Dapr Pluggable Component Management"
        echo ""
        echo "Commands:"
        echo "  start, setup  Set up and start the Dapr pluggable component (default)"
        echo "  stop, down    Stop the Dapr pluggable component"
        echo "  status        Show component status"
        echo "  logs [SERVICE] Show component logs (optionally for specific service)"
        echo "  test          Test component functionality"
        echo "  test-full     Run comprehensive tests (HTTP + gRPC via test_all.sh if available)"
        echo "  validate      Validate NebulaGraph infrastructure only"
        echo "  clean         Clean up component (volumes and networks)"
        echo "  help          Show this help message"
        echo ""
        echo "Services for logs command:"
        echo "  • nebulagraph-component  - The NebulaGraph Dapr component"
        echo "  • daprd                  - The Dapr runtime"
        echo ""
        echo "Setup will:"
        echo "  1. Validate NebulaGraph infrastructure is running"
        echo "  2. Start Dapr pluggable component containers"
        echo "  3. Test component functionality"
        echo ""
        echo "Prerequisites:"
        echo "  • NebulaGraph must be running (use ../../../dependencies/environment_setup.sh)"
        echo "  • Docker and Docker Compose"
        echo ""
        echo "API Endpoints:"
        echo "  • Dapr HTTP API: http://localhost:3501"
        echo "  • Dapr gRPC API: localhost:50001"
        echo "  • Health Check: http://localhost:3501/v1.0/healthz"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
