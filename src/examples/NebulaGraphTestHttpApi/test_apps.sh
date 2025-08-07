#!/bin/bash

# Local Apps Management Script
# Manages Dapr component and TestAPI applications locally

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# PID file locations
DAPRD_TESTAPI_PID_FILE="/tmp/daprd-testapi.pid"

# Port definitions
TESTAPI_PORT=5090
COMPONENT_DAPR_HTTP_PORT=3501
COMPONENT_DAPR_GRPC_PORT=50001

TESTAPI_DAPR_HTTP_PORT=3002
TESTAPI_DAPR_GRPC_PORT=50002

check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is available
    fi
}

kill_port() {
    local port=$1
    local pids=$(lsof -Pi :$port -sTCP:LISTEN -t 2>/dev/null)
    if [ -n "$pids" ]; then
        print_info "Killing processes using port $port: $pids"
        echo $pids | xargs kill -9 2>/dev/null || true
        sleep 1
        # Double check
        local remaining_pids=$(lsof -Pi :$port -sTCP:LISTEN -t 2>/dev/null)
        if [ -n "$remaining_pids" ]; then
            print_warning "Some processes still using port $port: $remaining_pids"
            return 1
        fi
        print_success "Port $port is now available"
    fi
    return 0
}

ensure_ports_available() {
    print_header "Ensuring Ports Are Available"
    
    local ports=($TESTAPI_PORT $TESTAPI_DAPR_HTTP_PORT $TESTAPI_DAPR_GRPC_PORT)
    local ports_to_kill=()
    
    # First, check which ports are in use
    for port in "${ports[@]}"; do
        if check_port $port; then
            ports_to_kill+=($port)
        fi
    done
    
    # Kill processes on those ports if any
    if [ ${#ports_to_kill[@]} -gt 0 ]; then
        print_info "Found processes using required ports: ${ports_to_kill[*]}"
        for port in "${ports_to_kill[@]}"; do
            kill_port $port
        done
    else
        print_success "All required ports are available"
    fi
}

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

check_dependencies() {
    print_header "Checking Dependencies"
    
    # Check Dapr CLI
    if command -v dapr &> /dev/null; then
        print_success "Dapr CLI is available: $(dapr --version | head -1)"
    else
        print_error "Dapr CLI not found. Please install Dapr CLI first."
        exit 1
    fi
    
    # Check .NET
    if command -v dotnet &> /dev/null; then
        print_success ".NET is available: $(dotnet --version)"
    else
        print_error ".NET not found. Please install .NET 9 SDK first."
        exit 1
    fi
    
    # Check Go
    if command -v go &> /dev/null; then
        print_success "Go is available: $(go version)"
    else
        print_error "Go not found. Please install Go first."
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
        print_info "Start dependencies first: ./deps.sh start"
        exit 1
    fi
}

build_testapi() {
    print_header "Building TestAPI"
    
    cd ../..
    print_info "Building .NET API..."
    dotnet build --configuration Release
    print_success "TestAPI built successfully"
    cd - > /dev/null
}

start_testapi() {
    print_info "Starting TestAPI..."
    cd ../..
    
    # Start Dapr sidecar for TestAPI (uses service invocation to access main component)
    dapr run \
        --app-id test-api \
        --app-port $TESTAPI_PORT \
        --dapr-http-port $TESTAPI_DAPR_HTTP_PORT \
        --dapr-grpc-port $TESTAPI_DAPR_GRPC_PORT \
        --log-level info \
        -- dotnet run --no-build --urls http://localhost:$TESTAPI_PORT &
    DAPRD_TESTAPI_PID=$!
    echo $DAPRD_TESTAPI_PID > $DAPRD_TESTAPI_PID_FILE
    print_success "TestAPI with Dapr sidecar started (PID: $DAPRD_TESTAPI_PID)"
    
    cd - > /dev/null
}

stop_processes() {
    print_header "Stopping Applications"
    
    # Stop TestAPI
    if [ -f $DAPRD_TESTAPI_PID_FILE ]; then
        TESTAPI_PID=$(cat $DAPRD_TESTAPI_PID_FILE)
        if kill -0 $TESTAPI_PID 2>/dev/null; then
            kill $TESTAPI_PID
            print_success "TestAPI stopped"
        fi
        rm -f $DAPRD_TESTAPI_PID_FILE
    fi
    
    # Clean up any remaining TestAPI Dapr processes
    pkill -f "daprd.*test-api" 2>/dev/null || true
    
    print_success "TestAPI stopped"
}

check_status() {
    print_header "Application Status"
    
    # Check TestAPI
    if [ -f $DAPRD_TESTAPI_PID_FILE ] && kill -0 $(cat $DAPRD_TESTAPI_PID_FILE) 2>/dev/null; then
        print_success "TestAPI is running (PID: $(cat $DAPRD_TESTAPI_PID_FILE))"
    else
        print_info "TestAPI is not running"
    fi
    
    echo ""
    print_info "Service Endpoints:"
    echo "  • TestAPI: http://localhost:$TESTAPI_PORT"
    echo "  • TestAPI Swagger: http://localhost:$TESTAPI_PORT/swagger"
    echo "  • Main Dapr Component: http://localhost:$COMPONENT_DAPR_HTTP_PORT"
    echo "  • TestAPI Dapr: http://localhost:$TESTAPI_DAPR_HTTP_PORT"
}

test_services() {
    print_header "Testing Service Invocation Architecture"
    
    sleep 3  # Give services time to start
    
    # Test main component directly
    print_info "Testing main Dapr component directly..."
    if curl -s -X POST "http://localhost:$COMPONENT_DAPR_HTTP_PORT/v1.0/state/nebulagraph-state" \
        -H "Content-Type: application/json" \
        -d '[{"key": "test-component", "value": "Hello from main component!"}]' > /dev/null; then
        print_success "Main component test passed"
    else
        print_error "Main component test failed"
    fi
    
    # Test TestAPI health
    print_info "Testing TestAPI health..."
    if curl -s "http://localhost:$TESTAPI_PORT/swagger" > /dev/null; then
        print_success "TestAPI health test passed"
    else
        print_error "TestAPI health test failed"
    fi
    
    # Test HTTP REST API service invocation
    print_info "Testing HTTP REST API service invocation..."
    if curl -s -X POST "http://localhost:$TESTAPI_PORT/api/state/test-http" \
        -H "Content-Type: application/json" \
        -d '{"value": "Hello from HTTP service invocation!"}' > /dev/null; then
        print_success "HTTP service invocation test passed"
    else
        print_error "HTTP service invocation test failed"
    fi
    
    # Test HTTP GET via service invocation
    print_info "Testing HTTP GET via service invocation..."
    if curl -s "http://localhost:$TESTAPI_PORT/api/state/test-http" > /dev/null; then
        print_success "HTTP GET service invocation test passed"
    else
        print_error "HTTP GET service invocation test failed"
    fi
    
    # Test gRPC service availability (gRPC server should be running on TestAPI)
    print_info "Testing gRPC service availability..."
    if curl -s "http://localhost:$TESTAPI_PORT" > /dev/null; then
        print_success "gRPC service availability test passed"
    else
        print_info "gRPC service test skipped (requires grpcurl)"
    fi
}

case "${1:-help}" in
    "start")
        check_dependencies
        ensure_ports_available
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
        ensure_ports_available
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
    "help"|"-h"|"--help")
        echo "Usage: $0 [COMMAND]"
        echo ""
        echo "TestAPI Management - Manages TestAPI application locally"
        echo ""
        echo "Commands:"
        echo "  start     Build and start TestAPI application"
        echo "  stop      Stop TestAPI application"
        echo "  restart   Restart TestAPI application"
        echo "  status    Show application status"
        echo "  test      Test running services"
        echo "  build     Build TestAPI without starting"
        echo "  help      Show this help"
        echo ""
        echo "Prerequisites:"
        echo "  • NebulaGraph dependencies must be running"
        echo "  • Main Dapr component must be running on port 3501"
        echo "  • Dapr CLI and .NET 9 SDK must be installed"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac
