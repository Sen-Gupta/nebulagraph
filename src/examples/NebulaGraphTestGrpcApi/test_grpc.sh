#!/bin/bash

# Docker-Based gRPC TestAPI Management Script
# Manages Dapr component and gRPC TestAPI applications using Docker Compose

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables if .env exists
if [ -f "../../.env" ]; then
    echo "Loading environment variables from .env..."
    export $(grep -v '^#' ../../.env | xargs)
fi

# Port definitions (from .env or defaults)
TEST_GRPC_API_HOST_PORT=${TEST_GRPC_API_HOST_PORT:-5093}
TEST_GRPC_API_APP_PORT=${TEST_GRPC_API_APP_PORT:-80}
TEST_GRPC_API_HTTP_PORT=${TEST_GRPC_API_HTTP_PORT:-3503}
TEST_GRPC_API_GRPC_PORT=${TEST_GRPC_API_GRPC_PORT:-50003}

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

check_dependencies() {
    print_header "Checking Dependencies"
    
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
    
    # Check grpcurl
    if command -v grpcurl &> /dev/null; then
        print_success "grpcurl is available: $(grpcurl --version 2>&1 | head -1)"
    else
        print_info "grpcurl not found. Installing..."
        if command -v go &> /dev/null; then
            go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
            export PATH=$PATH:$(go env GOPATH)/bin
            if command -v grpcurl &> /dev/null; then
                print_success "grpcurl installed successfully"
            else
                print_error "Failed to install grpcurl. Please install manually."
                exit 1
            fi
        else
            print_error "Go is not installed. Please install grpcurl manually."
            print_info "Install with: go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest"
            exit 1
        fi
    fi
    
    # Check if nebula-net network exists
    if docker network ls | grep -q "nebula-net"; then
        print_success "Docker network 'nebula-net' is available"
    else
        print_error "Docker network 'nebula-net' not found"
        print_info "Please run: cd ../../dependencies && ./environment_setup.sh start"
        exit 1
    fi
    
    # Check NebulaGraph and verify dapr_state space exists
    verify_result=$(docker run --rm --network nebula-net vesoft/nebula-console:v3-nightly \
        --addr nebula-graphd --port 9669 --user root --password nebula \
        --eval "USE dapr_state; SHOW TAGS;" 2>&1)
    
    if echo "$verify_result" | grep -q "state"; then
        print_success "NebulaGraph dapr_state space and schema are ready"
    else
        print_warning "NebulaGraph dapr_state space or schema not found"
        print_info "Please run: cd ../../dependencies && ./environment_setup.sh start"
        exit 1
    fi
    
    # Check if main Dapr pluggable component is running
    if docker ps --format "table {{.Names}}" | grep -q "nebulagraph-component-sidecar"; then
        print_success "Main Dapr pluggable component is running"
    else
        print_warning "Main Dapr pluggable component not found"
        print_info "Starting main component: cd ../../dapr-pluggable-components && ./run_docker_pluggable.sh start"
        
        # Try to start it automatically
        if (cd ../../dapr-pluggable-components && ./run_docker_pluggable.sh start); then
            print_success "Main Dapr pluggable component started successfully"
        else
            print_error "Failed to start main Dapr pluggable component"
            exit 1
        fi
    fi
}

build_testapi() {
    print_header "Building gRPC TestAPI Docker Image"
    
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd) || {
        print_error "Docker Compose is not available"
        return 1
    }
    
    print_info "Building gRPC TestAPI Docker image..."
    if $compose_cmd build nebulagraph-test-grpc-api; then
        print_success "gRPC TestAPI Docker image built successfully"
    else
        print_error "Failed to build gRPC TestAPI Docker image"
        return 1
    fi
}

start_testapi() {
    print_header "Starting gRPC TestAPI with Docker Compose"
    
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd) || {
        print_error "Docker Compose is not available"
        return 1
    }
    
    print_info "Starting gRPC TestAPI services..."
    if $compose_cmd up -d; then
        print_success "gRPC TestAPI services started successfully"
        
        # Wait for services to be ready
        print_info "Waiting for services to initialize..."
        sleep 10
        
        # Check if containers are running
        local api_running=$($compose_cmd ps -q nebulagraph-test-grpc-api 2>/dev/null)
        local sidecar_running=$($compose_cmd ps -q nebulagraph-test-grpc-api-sidecar 2>/dev/null)
        
        if [ -n "$api_running" ] && [ -n "$sidecar_running" ]; then
            print_success "All gRPC TestAPI containers are running"
        else
            print_warning "Some containers may not be running properly"
            $compose_cmd ps
        fi
    else
        print_error "Failed to start gRPC TestAPI services"
        return 1
    fi
}

stop_processes() {
    print_header "Stopping gRPC TestAPI Services"
    
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd) || {
        print_error "Docker Compose is not available"
        return 1
    }
    
    print_info "Stopping gRPC TestAPI services..."
    $compose_cmd down
    print_success "gRPC TestAPI services stopped"
}

check_status() {
    print_header "gRPC TestAPI Services Status"
    
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
    echo "  • gRPC TestAPI: localhost:$TEST_GRPC_API_HOST_PORT"
    echo "  • gRPC TestAPI Dapr HTTP: http://localhost:$TEST_GRPC_API_HTTP_PORT"
    echo "  • gRPC TestAPI Dapr gRPC: localhost:$TEST_GRPC_API_GRPC_PORT"
    echo "  • Main Dapr Component: http://localhost:3501"
    
    # Check if services are responding
    echo ""
    print_info "Service Health:"
    
    # Test gRPC service reflection
    if grpcurl -plaintext -connect-timeout 5 localhost:$TEST_GRPC_API_HOST_PORT list >/dev/null 2>&1; then
        print_success "gRPC TestAPI is responding"
    else
        print_warning "gRPC TestAPI is not responding"
    fi
    
    # Test Dapr sidecar
    if curl -s --connect-timeout 5 "http://localhost:$TEST_GRPC_API_HTTP_PORT/v1.0/healthz" >/dev/null 2>&1; then
        print_success "gRPC TestAPI Dapr sidecar is responding"
    else
        print_warning "gRPC TestAPI Dapr sidecar is not responding"
    fi
}

test_services() {
    print_header "Testing Docker-Based gRPC TestAPI Services"
    
    sleep 5  # Give services more time to start and load components
    
    # Use environment variable or default ports
    # For local development: 5000
    # For Docker environment: TEST_GRPC_API_HOST_PORT (5093)
    if [ -n "$TEST_GRPC_API_HOST_PORT" ]; then
        GRPC_URL="localhost:${TEST_GRPC_API_HOST_PORT}"
    else
        GRPC_URL="localhost:5000"
    fi
    
    print_info "Testing gRPC API at: ${GRPC_URL}"
    
    # Test gRPC service reflection
    print_info "Testing gRPC service reflection..."
    if grpcurl -plaintext -connect-timeout 10 ${GRPC_URL} list >/dev/null 2>&1; then
        print_success "gRPC service reflection test passed"
    else
        print_error "gRPC service reflection test failed"
        print_info "Checking container logs..."
        local compose_cmd
        compose_cmd=$(get_docker_compose_cmd)
        $compose_cmd logs nebulagraph-test-grpc-api | tail -10
        return 1
    fi
    
    # Test gRPC Dapr sidecar health
    print_info "Testing gRPC TestAPI Dapr sidecar health..."
    if curl -s --connect-timeout 10 "http://localhost:$TEST_GRPC_API_HTTP_PORT/v1.0/healthz" > /dev/null; then
        print_success "gRPC TestAPI Dapr sidecar health test passed"
    else
        print_error "gRPC TestAPI Dapr sidecar health test failed"
        print_info "Checking sidecar logs..."
        local compose_cmd
        compose_cmd=$(get_docker_compose_cmd)
        $compose_cmd logs nebulagraph-test-grpc-api-sidecar | tail -10
        return 1
    fi
    
    # Test if NebulaGraph state store component is loaded
    print_info "Testing NebulaGraph state store component availability..."
    metadata_response=$(curl -s --connect-timeout 10 "http://localhost:$TEST_GRPC_API_HTTP_PORT/v1.0/metadata" 2>/dev/null)
    if echo "$metadata_response" | grep -q "nebulagraph-state"; then
        print_success "NebulaGraph state store component is loaded"
        
        # Test gRPC state operations
        print_info "Testing gRPC state SET operation..."
        if grpcurl -plaintext -connect-timeout 10 \
            -d '{"key": "grpc-test", "value": "grpc-value-123"}' \
            ${GRPC_URL} nebulagraph.NebulaGraphService/SetValue >/dev/null 2>&1; then
            print_success "gRPC state SET operation test passed"
        else
            print_warning "gRPC state SET operation test failed"
        fi
        
        # Test gRPC GET operation
        print_info "Testing gRPC state GET operation..."
        get_response=$(grpcurl -plaintext -connect-timeout 10 \
            -d '{"key": "grpc-test"}' \
            ${GRPC_URL} nebulagraph.NebulaGraphService/GetValue 2>/dev/null)
        if [ -n "$get_response" ] && echo "$get_response" | grep -q "grpc-value-123"; then
            print_success "gRPC state GET operation test passed"
            print_info "Retrieved: $get_response"
        else
            print_warning "gRPC state GET operation test failed"
        fi
        
        # Test gRPC DELETE operation
        print_info "Testing gRPC state DELETE operation..."
        if grpcurl -plaintext -connect-timeout 10 \
            -d '{"key": "grpc-test"}' \
            ${GRPC_URL} nebulagraph.NebulaGraphService/DeleteValue >/dev/null 2>&1; then
            print_success "gRPC state DELETE operation test passed"
        else
            print_warning "gRPC state DELETE operation test failed"
        fi
        
        # Test GET after delete
        print_info "Testing gRPC GET after delete..."
        delete_response=$(grpcurl -plaintext -connect-timeout 10 \
            -d '{"key": "grpc-test"}' \
            ${GRPC_URL} nebulagraph.NebulaGraphService/GetValue 2>/dev/null)
        if echo "$delete_response" | grep -q '"found": false'; then
            print_success "gRPC GET after delete test passed (key not found as expected)"
        else
            print_warning "gRPC GET after delete test failed"
        fi
        
        # Test ListKeys (expected to fail gracefully)
        print_info "Testing gRPC ListKeys operation (expected limitation)..."
        list_response=$(grpcurl -plaintext -connect-timeout 10 \
            -d '{"prefix": "grpc", "limit": 5}' \
            ${GRPC_URL} nebulagraph.NebulaGraphService/ListKeys 2>/dev/null)
        if echo "$list_response" | grep -q "not available"; then
            print_success "gRPC ListKeys limitation test passed (expected error)"
        else
            print_info "gRPC ListKeys operation completed (may not be implemented)"
        fi
    else
        print_warning "NebulaGraph state store component not found in metadata"
        print_info "Available components:"
        echo "$metadata_response" | jq '.components[].name' 2>/dev/null || echo "$metadata_response"
    fi
}

case "${1:-help}" in
    "start")
        check_dependencies
        build_testapi
        start_testapi
        check_status
        test_services
        ;;
    "stop")
        stop_processes
        ;;
    "restart")
        stop_processes
        sleep 2
        check_dependencies
        build_testapi
        start_testapi
        check_status
        ;;
    "status")
        check_status
        ;;
    "test")
        test_services
        ;;
    "build")
        build_testapi
        ;;
    "logs")
        print_header "gRPC TestAPI Service Logs"
        local compose_cmd
        compose_cmd=$(get_docker_compose_cmd) || {
            print_error "Docker Compose is not available"
            exit 1
        }
        $compose_cmd logs -f
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [COMMAND]"
        echo ""
        echo "Docker-Based gRPC TestAPI Management - Manages gRPC TestAPI application using Docker Compose"
        echo ""
        echo "Commands:"
        echo "  start     Build and start gRPC TestAPI services with Docker Compose"
        echo "  stop      Stop gRPC TestAPI services"
        echo "  restart   Restart gRPC TestAPI services"
        echo "  status    Show service status and health"
        echo "  test      Test running services"
        echo "  build     Build gRPC TestAPI Docker image"
        echo "  logs      Show service logs (follow mode)"
        echo "  help      Show this help"
        echo ""
        echo "Prerequisites:"
        echo "  • NebulaGraph dependencies must be running (./dependencies/environment_setup.sh start)"
        echo "  • Docker and Docker Compose must be installed"
        echo "  • grpcurl must be installed or Go available for auto-installation"
        echo "  • nebula-net Docker network must exist"
        echo ""
        echo "Environment Variables:"
        echo "  • TEST_GRPC_API_HOST_PORT (default: 5093) - Host port for gRPC TestAPI"
        echo "  • TEST_GRPC_API_APP_PORT (default: 80) - Container port for gRPC TestAPI"  
        echo "  • TEST_GRPC_API_HTTP_PORT (default: 3503) - Dapr HTTP port"
        echo "  • TEST_GRPC_API_GRPC_PORT (default: 50003) - Dapr gRPC port"
        echo ""
        echo "Services:"
        echo "  • gRPC TestAPI: localhost:$TEST_GRPC_API_HOST_PORT"
        echo "  • gRPC TestAPI Dapr HTTP: http://localhost:$TEST_GRPC_API_HTTP_PORT"
        echo "  • gRPC TestAPI Dapr gRPC: localhost:$TEST_GRPC_API_GRPC_PORT"
        echo ""
        echo "Testing:"
        echo "  • grpcurl -plaintext localhost:$TEST_GRPC_API_HOST_PORT list"
        echo "  • grpcurl -plaintext -d '{\"key\":\"test\",\"value\":\"hello\"}' localhost:$TEST_GRPC_API_HOST_PORT nebulagraph.NebulaGraphService/SetValue"
        echo ""
        echo "Notes:"
        echo "  • Uses Docker Compose for consistent container-based deployment"
        echo "  • Automatically connects to existing NebulaGraph and Redis containers"
        echo "  • Integrates with Dapr pluggable components for state management"
        echo "  • Suitable for production-like testing scenarios"
        echo "  • gRPC protocol for high-performance communication"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac
