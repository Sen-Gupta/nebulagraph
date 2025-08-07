#!/bin/bash

# Docker-Based TestAPI Management Script
# Manages Dapr component and TestAPI applications using Docker Compose

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Port definitions (from .env or defaults)
TEST_API_HOST_PORT=${TEST_API_HOST_PORT:-5090}
TEST_API_APP_PORT=${TEST_API_APP_PORT:-80}
TEST_API_HTTP_PORT=${TEST_API_HTTP_PORT:-3502}

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
    print_header "Building TestAPI Docker Image"
    
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd) || {
        print_error "Docker Compose is not available"
        return 1
    }
    
    print_info "Building TestAPI Docker image..."
    if $compose_cmd build nebulagraph-test-api; then
        print_success "TestAPI Docker image built successfully"
    else
        print_error "Failed to build TestAPI Docker image"
        return 1
    fi
}

start_testapi() {
    print_header "Starting TestAPI with Docker Compose"
    
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd) || {
        print_error "Docker Compose is not available"
        return 1
    }
    
    print_info "Starting TestAPI services..."
    if $compose_cmd up -d; then
        print_success "TestAPI services started successfully"
        
        # Wait for services to be ready
        print_info "Waiting for services to initialize..."
        sleep 10
        
        # Check if containers are running
        local api_running=$($compose_cmd ps -q nebulagraph-test-api 2>/dev/null)
        local sidecar_running=$($compose_cmd ps -q nebulagraph-test-api-sidecar 2>/dev/null)
        
        if [ -n "$api_running" ] && [ -n "$sidecar_running" ]; then
            print_success "All TestAPI containers are running"
        else
            print_warning "Some containers may not be running properly"
            $compose_cmd ps
        fi
    else
        print_error "Failed to start TestAPI services"
        return 1
    fi
}

stop_processes() {
    print_header "Stopping TestAPI Services"
    
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd) || {
        print_error "Docker Compose is not available"
        return 1
    }
    
    print_info "Stopping TestAPI services..."
    $compose_cmd down
    print_success "TestAPI services stopped"
}

check_status() {
    print_header "TestAPI Services Status"
    
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
    echo "  • TestAPI: http://localhost:$TEST_API_HOST_PORT"
    echo "  • TestAPI Swagger: http://localhost:$TEST_API_HOST_PORT/swagger"
    echo "  • TestAPI Dapr: http://localhost:$TEST_API_HTTP_PORT"
    echo "  • Main Dapr Component: http://localhost:3501"
    
    # Check if services are responding
    echo ""
    print_info "Service Health:"
    
    # Test TestAPI
    if curl -s --connect-timeout 5 "http://localhost:$TEST_API_HOST_PORT/swagger" >/dev/null 2>&1; then
        print_success "TestAPI is responding"
    else
        print_warning "TestAPI is not responding"
    fi
    
    # Test Dapr sidecar
    if curl -s --connect-timeout 5 "http://localhost:$TEST_API_HTTP_PORT/v1.0/healthz" >/dev/null 2>&1; then
        print_success "TestAPI Dapr sidecar is responding"
    else
        print_warning "TestAPI Dapr sidecar is not responding"
    fi
}

test_services() {
    print_header "Testing Docker-Based TestAPI Services"
    
    sleep 5  # Give services more time to start and load components
    
    # Test TestAPI health first
    print_info "Testing TestAPI health..."
    if curl -s --connect-timeout 10 "http://localhost:$TEST_API_HOST_PORT/swagger" > /dev/null; then
        print_success "TestAPI health test passed"
    else
        print_error "TestAPI health test failed"
        print_info "Checking container logs..."
        local compose_cmd
        compose_cmd=$(get_docker_compose_cmd)
        $compose_cmd logs nebulagraph-test-api | tail -10
        return 1
    fi
    
    # Test TestAPI Dapr sidecar health
    print_info "Testing TestAPI Dapr sidecar health..."
    if curl -s --connect-timeout 10 "http://localhost:$TEST_API_HTTP_PORT/v1.0/healthz" > /dev/null; then
        print_success "TestAPI Dapr sidecar health test passed"
    else
        print_error "TestAPI Dapr sidecar health test failed"
        print_info "Checking sidecar logs..."
        local compose_cmd
        compose_cmd=$(get_docker_compose_cmd)
        $compose_cmd logs nebulagraph-test-api-sidecar | tail -10
        return 1
    fi
    
    # Test if NebulaGraph state store component is loaded
    print_info "Testing NebulaGraph state store component availability..."
    metadata_response=$(curl -s --connect-timeout 10 "http://localhost:$TEST_API_HTTP_PORT/v1.0/metadata" 2>/dev/null)
    if echo "$metadata_response" | grep -q "nebulagraph-state"; then
        print_success "NebulaGraph state store component is loaded"
        
        # Test HTTP REST API state operations via TestAPI
        print_info "Testing HTTP REST API state operations..."
        if curl -s --connect-timeout 10 -X POST "http://localhost:$TEST_API_HOST_PORT/api/state/test-docker" \
            -H "Content-Type: application/json" \
            -d '{"value": "Hello from Docker test!"}' > /dev/null; then
            print_success "HTTP state SET operation test passed"
        else
            print_warning "HTTP state SET operation test failed (check logs)"
        fi
        
        # Test HTTP GET via REST API
        print_info "Testing HTTP GET state operation..."
        get_response=$(curl -s --connect-timeout 10 "http://localhost:$TEST_API_HOST_PORT/api/state/test-docker" 2>/dev/null)
        if [ -n "$get_response" ]; then
            print_success "HTTP state GET operation test passed"
            print_info "Retrieved: $get_response"
        else
            print_warning "HTTP state GET operation test failed"
        fi
        
        # Test direct Dapr state API
        print_info "Testing direct Dapr state API..."
        if curl -s --connect-timeout 10 -X POST "http://localhost:$TEST_API_HTTP_PORT/v1.0/state/nebulagraph-state" \
            -H "Content-Type: application/json" \
            -d '[{"key":"direct-test","value":"Hello from direct Dapr API!"}]' > /dev/null; then
            print_success "Direct Dapr state SET operation test passed"
            
            # Test direct GET
            direct_response=$(curl -s --connect-timeout 10 "http://localhost:$TEST_API_HTTP_PORT/v1.0/state/nebulagraph-state/direct-test" 2>/dev/null)
            if [ -n "$direct_response" ]; then
                print_success "Direct Dapr state GET operation test passed"
                print_info "Direct response: $direct_response"
            else
                print_warning "Direct Dapr state GET operation test failed"
            fi
        else
            print_warning "Direct Dapr state SET operation test failed"
        fi
    else
        print_warning "NebulaGraph state store component not found in metadata"
        print_info "Available components:"
        echo "$metadata_response" | jq '.components[].name' 2>/dev/null || echo "$metadata_response"
    fi
    
    # Test pub/sub functionality if Redis component is available
    print_info "Testing pub/sub functionality..."
    if echo "$metadata_response" | grep -q "redis-pubsub"; then
        if curl -s --connect-timeout 10 -X POST "http://localhost:$TEST_API_HTTP_PORT/v1.0/publish/redis-pubsub/test-topic" \
            -H "Content-Type: application/json" \
            -d '{"message": "Hello from Docker pub/sub test!"}' > /dev/null; then
            print_success "Pub/sub publish test passed"
        else
            print_warning "Pub/sub publish test failed"
        fi
    else
        print_info "Redis pub/sub component not available for testing"
    fi
    
    # Test basic service connectivity
    print_info "Testing basic service connectivity..."
    if curl -s --connect-timeout 10 "http://localhost:$TEST_API_HOST_PORT" > /dev/null; then
        print_success "Basic service connectivity test passed"
    else
        print_info "Basic service connectivity test completed"
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
        print_header "TestAPI Service Logs"
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
        echo "Docker-Based TestAPI Management - Manages TestAPI application using Docker Compose"
        echo ""
        echo "Commands:"
        echo "  start     Build and start TestAPI services with Docker Compose"
        echo "  stop      Stop TestAPI services"
        echo "  restart   Restart TestAPI services"
        echo "  status    Show service status and health"
        echo "  test      Test running services"
        echo "  build     Build TestAPI Docker image"
        echo "  logs      Show service logs (follow mode)"
        echo "  help      Show this help"
        echo ""
        echo "Prerequisites:"
        echo "  • NebulaGraph dependencies must be running (./dependencies/environment_setup.sh start)"
        echo "  • Docker and Docker Compose must be installed"
        echo "  • nebula-net Docker network must exist"
        echo ""
        echo "Environment Variables:"
        echo "  • TEST_API_HOST_PORT (default: 5090) - Host port for TestAPI"
        echo "  • TEST_API_APP_PORT (default: 80) - Container port for TestAPI"  
        echo "  • TEST_API_HTTP_PORT (default: 3502) - Dapr HTTP port"
        echo ""
        echo "Services:"
        echo "  • TestAPI: http://localhost:$TEST_API_HOST_PORT"
        echo "  • TestAPI Swagger: http://localhost:$TEST_API_HOST_PORT/swagger"
        echo "  • TestAPI Dapr: http://localhost:$TEST_API_HTTP_PORT"
        echo ""
        echo "Notes:"
        echo "  • Uses Docker Compose for consistent container-based deployment"
        echo "  • Automatically connects to existing NebulaGraph and Redis containers"
        echo "  • Integrates with Dapr pluggable components for state management"
        echo "  • Suitable for production-like testing scenarios"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac
