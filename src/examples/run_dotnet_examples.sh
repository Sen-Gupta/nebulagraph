#!/bin/bash

# Dapr Pluggable Components Manager
# Manages the .NET Dapr pluggable components using Docker Compose

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Port definitions (from .env or defaults)
DOT_NET_HOST_PORT=${DOT_NET_HOST_PORT:-5090}
DOT_NET_APP_PORT=${DOT_NET_APP_PORT:-80}
DOT_NET_HTTP_PORT=${DOT_NET_HTTP_PORT:-3502}
DOT_NET_GRPC_PORT=${DOT_NET_GRPC_PORT:-50002}

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

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Get docker compose command (docker-compose or docker compose)
get_docker_compose_cmd() {
    if command -v docker-compose >/dev/null 2>&1; then
        echo "docker-compose"
    elif docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    else
        return 1
    fi
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Save current directory
    local original_dir="$(pwd)"
    
    # Change to DotNet directory where docker-compose.yml is located
    if [[ ! -d "DotNet" ]]; then
        print_error "DotNet directory not found. Please run this script from the examples directory."
        exit 1
    fi
    cd DotNet
    
    # Check Docker
    if command -v docker &> /dev/null; then
        print_success "Docker is available: $(docker --version)"
    else
        print_error "Docker not found. Please install Docker first."
        exit 1
    fi
    
    # Check Docker Compose
    local compose_cmd
    if compose_cmd=$(get_docker_compose_cmd); then
        if [[ "$compose_cmd" == "docker-compose" ]]; then
            print_success "Docker Compose v1 is available: $(docker-compose --version)"
        else
            print_success "Docker Compose v2 is available: $(docker compose version)"
        fi
    else
        print_error "Docker Compose not found. Please install Docker Compose."
        exit 1
    fi
    
    # Check if dapr-pluggable-net network exists
    if docker network ls | grep -q "dapr-pluggable-net"; then
        print_success "Docker network 'dapr-pluggable-net' is available"
    else
        print_error "Docker network 'dapr-pluggable-net' not found"
        print_info "Please run: cd ../dependencies && ./environment_setup.sh start"
        exit 1
    fi
    
    # Check if docker-compose.yml exists
    if [[ -f "docker-compose.yml" ]]; then
        print_success "Docker Compose configuration found"
    else
        print_error "docker-compose.yml not found in current directory"
        exit 1
    fi
    
    # Return to original directory
    cd "$original_dir"
}

build_services() {
    print_header "Building Dapr Pluggable Components"
    
    # Save current directory
    local original_dir="$(pwd)"
    
    # Ensure we're in the DotNet directory where docker-compose.yml is located
    if [[ ! -d "DotNet" ]]; then
        print_error "DotNet directory not found. Please run this script from the examples directory."
        return 1
    fi
    cd DotNet
    
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd) || {
        print_error "Docker Compose is not available"
        return 1
    }
    
    print_info "Building all Docker services with latest code changes..."
    if $compose_cmd build; then
        print_success "All Dapr pluggable component services built successfully"
    else
        print_error "Failed to build Dapr pluggable component services"
        return 1
    fi
    
    # Return to original directory
    cd "$original_dir"
}

start_services() {
    print_header "Starting Dapr Pluggable Components"
    
    # Save current directory
    local original_dir="$(pwd)"
    
    # Ensure we're in the DotNet directory where docker-compose.yml is located
    if [[ ! -d "DotNet" ]]; then
        print_error "DotNet directory not found. Please run this script from the examples directory."
        return 1
    fi
    cd DotNet
    
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd) || {
        print_error "Docker Compose is not available"
        return 1
    }
    
    print_info "Starting Dapr pluggable component services..."
    if $compose_cmd up -d; then
        print_success "Dapr pluggable component services started successfully"
        
        # Wait for services to be ready
        print_info "Waiting for services to initialize..."
        sleep 10
        
        # Check if containers are running
        local component_running=$($compose_cmd ps -q dot-net-dapr-pluggables-components 2>/dev/null)
        local api_running=$($compose_cmd ps -q dotnet-dapr-client 2>/dev/null)
        local sidecar_running=$($compose_cmd ps -q dotnet-dapr-client-sidecar 2>/dev/null)
        
        if [ -n "$component_running" ] && [ -n "$api_running" ] && [ -n "$sidecar_running" ]; then
            print_success "All Dapr pluggable component containers are running"
        else
            print_warning "Some containers may not be running properly"
            $compose_cmd ps
        fi
    else
        print_error "Failed to start Dapr pluggable component services"
        return 1
    fi
    
    # Return to original directory
    cd "$original_dir"
}

stop_services() {
    print_header "Stopping Dapr Pluggable Components"
    
    # Save current directory
    local original_dir="$(pwd)"
    
    # Ensure we're in the DotNet directory where docker-compose.yml is located
    if [[ ! -d "DotNet" ]]; then
        print_error "DotNet directory not found. Please run this script from the examples directory."
        return 1
    fi
    cd DotNet
    
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd) || {
        print_error "Docker Compose is not available"
        return 1
    }
    
    print_info "Stopping Dapr pluggable component services..."
    $compose_cmd down
    print_success "Dapr pluggable component services stopped"
    
    # Return to original directory
    cd "$original_dir"
}

check_status() {
    print_header "Dapr Pluggable Components Status"
    
    # Save current directory
    local original_dir="$(pwd)"
    
    # Ensure we're in the DotNet directory where docker-compose.yml is located
    if [[ ! -d "DotNet" ]]; then
        print_error "DotNet directory not found. Please run this script from the examples directory."
        return 1
    fi
    cd DotNet
    
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd) || {
        print_error "Docker Compose is not available"
        return 1
    }
    
    # Show container status
    print_info "Container Status:"
    $compose_cmd ps
    
    echo ""
    print_info "Service Endpoints:"
    echo "  • .NET Dapr Client API: http://localhost:$DOT_NET_HOST_PORT"
    echo "  • .NET Dapr Client Swagger: http://localhost:$DOT_NET_HOST_PORT/swagger"
    echo "  • Dapr HTTP API: http://localhost:$DOT_NET_HTTP_PORT"
    echo "  • Dapr gRPC API: localhost:$DOT_NET_GRPC_PORT"
    
    # Check if services are responding
    echo ""
    print_info "Service Health:"
    
    # Test .NET Dapr Client API
    if curl -s --connect-timeout 5 "http://localhost:$DOT_NET_HOST_PORT/swagger" >/dev/null 2>&1; then
        print_success ".NET Dapr Client API is responding"
    else
        print_warning ".NET Dapr Client API is not responding"
    fi
    
    # Test Dapr sidecar
    if curl -s --connect-timeout 5 "http://localhost:$DOT_NET_HTTP_PORT/v1.0/healthz" >/dev/null 2>&1; then
        print_success "Dapr sidecar is responding"
    else
        print_warning "Dapr sidecar is not responding"
    fi
    
    # Check Dapr metadata for loaded components
    echo ""
    print_info "Dapr Component Status:"
    metadata_response=$(curl -s --connect-timeout 5 "http://localhost:$DOT_NET_HTTP_PORT/v1.0/metadata" 2>/dev/null)
    if [ -n "$metadata_response" ]; then
        if echo "$metadata_response" | grep -q "nebulagraph-state"; then
            print_success "NebulaGraph state store component is loaded"
        else
            print_warning "NebulaGraph state store component not found"
        fi
        
        if echo "$metadata_response" | grep -q "scylladb-state"; then
            print_success "ScyllaDB state store component is loaded"
        else
            print_warning "ScyllaDB state store component not found"
        fi
        
        if echo "$metadata_response" | grep -q "redis-pubsub"; then
            print_success "Redis pub/sub component is loaded"
        else
            print_info "Redis pub/sub component not loaded (optional)"
        fi
    else
        print_warning "Could not retrieve Dapr metadata"
    fi
    
    # Return to original directory
    cd "$original_dir"
}

show_logs() {
    print_header "Dapr Pluggable Components Logs"
    
    # Save current directory
    local original_dir="$(pwd)"
    
    # Ensure we're in the DotNet directory where docker-compose.yml is located
    if [[ ! -d "DotNet" ]]; then
        print_error "DotNet directory not found. Please run this script from the examples directory."
        exit 1
    fi
    cd DotNet
    
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd) || {
        print_error "Docker Compose is not available"
        exit 1
    }
    
    local service="${2:-}"
    
    if [ -n "$service" ]; then
        case "$service" in
            "component"|"pluggable")
                print_info "Showing logs for dot-net-dapr-pluggables-components..."
                $compose_cmd logs -f dot-net-dapr-pluggables-components
                ;;
            "api"|"client")
                print_info "Showing logs for dotnet-dapr-client..."
                $compose_cmd logs -f dotnet-dapr-client
                ;;
            "sidecar"|"dapr")
                print_info "Showing logs for dotnet-dapr-client-sidecar..."
                $compose_cmd logs -f dotnet-dapr-client-sidecar
                ;;
            *)
                print_error "Unknown service: $service"
                print_info "Available services: component, api, sidecar"
                exit 1
                ;;
        esac
    else
        print_info "Showing logs for all services..."
        $compose_cmd logs -f
    fi
    
    # Return to original directory
    cd "$original_dir"
}

test_components() {
    print_header "Testing Dapr Pluggable Components"
    
    sleep 5  # Give services time to start
    
    # Test Dapr sidecar health first
    print_info "Testing Dapr sidecar health..."
    if curl -s --connect-timeout 10 "http://localhost:$DOT_NET_HTTP_PORT/v1.0/healthz" > /dev/null; then
        print_success "Dapr sidecar health test passed"
    else
        print_error "Dapr sidecar health test failed"
        return 1
    fi
    
    # Test component metadata
    print_info "Testing component metadata..."
    metadata_response=$(curl -s --connect-timeout 10 "http://localhost:$DOT_NET_HTTP_PORT/v1.0/metadata" 2>/dev/null)
    if [ -n "$metadata_response" ]; then
        print_success "Component metadata retrieved successfully"
        
        # Test state store operations
        print_info "Testing state store operations..."
        
        # Test NebulaGraph state store
        if echo "$metadata_response" | grep -q "nebulagraph-state"; then
            print_info "Testing NebulaGraph state store..."
            if curl -s --connect-timeout 10 -X POST "http://localhost:$DOT_NET_HTTP_PORT/v1.0/state/nebulagraph-state" \
                -H "Content-Type: application/json" \
                -d '[{"key":"test-key","value":"test-value"}]' > /dev/null; then
                print_success "NebulaGraph state store test passed"
            else
                print_warning "NebulaGraph state store test failed"
            fi
        fi
        
        # Test ScyllaDB state store
        if echo "$metadata_response" | grep -q "scylladb-state"; then
            print_info "Testing ScyllaDB state store..."
            if curl -s --connect-timeout 10 -X POST "http://localhost:$DOT_NET_HTTP_PORT/v1.0/state/scylladb-state" \
                -H "Content-Type: application/json" \
                -d '[{"key":"test-key","value":"test-value"}]' > /dev/null; then
                print_success "ScyllaDB state store test passed"
            else
                print_warning "ScyllaDB state store test failed"
            fi
        fi
    else
        print_error "Failed to retrieve component metadata"
        return 1
    fi
}

case "${1:-help}" in
    "start")
        check_prerequisites
        build_services
        start_services
        check_status
        ;;
    "stop")
        stop_services
        ;;
    "restart")
        stop_services
        sleep 2
        check_prerequisites
        build_services
        start_services
        check_status
        ;;
    "build")
        check_prerequisites
        build_services
        ;;
    "status")
        check_status
        ;;
    "test")
        test_components
        ;;
    "test-nebula")
        print_header "Running NebulaGraph Specific Tests"
        if [[ -f "tests/test_nebula_net.sh" ]]; then
            print_info "Executing NebulaGraph .NET test suite..."
            ./tests/test_nebula_net.sh test
        else
            print_error "NebulaGraph test file not found: tests/test_nebula_net.sh"
            exit 1
        fi
        ;;
    "test-all")
        print_header "Running All Test Suites"
        if [[ -f "tests/test_all_net.sh" ]]; then
            print_info "Executing comprehensive test suite..."
            ./tests/test_all_net.sh
        else
            print_error "Test orchestrator not found: tests/test_all_net.sh"
            exit 1
        fi
        ;;
    "logs")
        show_logs "$@"
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [COMMAND] [OPTIONS]"
        echo ""
        echo "Dapr Pluggable Components Manager - Manages .NET Dapr pluggable components using Docker Compose"
        echo ""
        echo "Commands:"
        echo "  start     Build and start all Dapr pluggable component services"
        echo "  stop      Stop all Dapr pluggable component services"
        echo "  restart   Restart all Dapr pluggable component services"
        echo "  build     Build Dapr pluggable component Docker images"
        echo "  status    Show service status and health"
        echo "  test      Test Dapr pluggable components functionality"
        echo "  test-nebula   Run NebulaGraph specific tests (requires services running)"
        echo "  test-all      Run all test suites (requires services running)"
        echo "  logs      Show service logs (optionally for specific service)"
        echo "  help      Show this help"
        echo ""
        echo "Log Commands:"
        echo "  logs              Show all service logs"
        echo "  logs component    Show pluggable component logs"
        echo "  logs api          Show .NET API logs"
        echo "  logs sidecar      Show Dapr sidecar logs"
        echo ""
        echo "Test Commands:"
        echo "  test              Basic component functionality tests"
        echo "  test-nebula       NebulaGraph specific integration tests"
        echo "  test-all          Comprehensive test suite (all components)"
        echo ""
        echo "Prerequisites:"
        echo "  • Dependencies must be running (../dependencies/environment_setup.sh start)"
        echo "  • Docker and Docker Compose must be installed"
        echo "  • dapr-pluggable-net Docker network must exist"
        echo ""
        echo "Environment Variables:"
        echo "  • DOT_NET_HOST_PORT (default: 5090) - Host port for .NET API"
        echo "  • DOT_NET_APP_PORT (default: 80) - Container port for .NET API"  
        echo "  • DOT_NET_HTTP_PORT (default: 3502) - Dapr HTTP port"
        echo "  • DOT_NET_GRPC_PORT (default: 50002) - Dapr gRPC port"
        echo ""
        echo "Services:"
        echo "  • dot-net-dapr-pluggables-components - Multi-store pluggable component"
        echo "  • dotnet-dapr-client - .NET Dapr client API"
        echo "  • dotnet-dapr-client-sidecar - Dapr sidecar"
        echo ""
        echo "Features:"
        echo "  • Unified pluggable component supporting NebulaGraph and ScyllaDB"
        echo "  • Self-contained Docker Compose setup"
        echo "  • Automatic component health checking"
        echo ""
        echo "Workflow:"
        echo "  1. Start services: $0 start"
        echo "  2. Run tests: $0 test-all or $0 test-nebula"
        echo "  3. View logs: $0 logs"
        echo "  4. Stop services: $0 stop"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac
