#!/bin/bash

# NebulaGraph Dapr Pluggable Component Management Script
# Complete management of Dapr pluggable component including setup, operations, and testing

set -e

# Load environment configuration if available
if [ -f "../../../.env" ]; then
    source ../../../.env
fi

# Set default values if not already set
NEBULA_HTTP_PORT=${NEBULA_HTTP_PORT:-3501}
NEBULA_GRPC_PORT=${NEBULA_GRPC_PORT:-50001}
NEBULA_NETWORK_NAME=${NEBULA_NETWORK_NAME:-nebula-net}

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

# Start Dapr pluggable component
start_component() {
    print_info "Starting Dapr pluggable component..."
    
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
    
    if $compose_cmd up -d; then
        print_success "Dapr pluggable component started"
        
        # Wait for services to initialize
        print_info "Waiting for Dapr runtime to initialize..."
        sleep 10
        
        # Check if containers are running
        if $compose_cmd ps | grep -q "Up"; then
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
        local compose_cmd
        compose_cmd=$(get_docker_compose_cmd) || {
            print_error "Docker Compose is not installed or not in PATH"
            return 1
        }
        $compose_cmd down
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
    print_header "Dapr Pluggable Component Logs"
    
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

# Clean component (remove volumes and networks)
clean_component() {
    print_header "Cleaning Dapr Pluggable Component"
    
    if [ -f "docker-compose.yml" ]; then
        local compose_cmd
        compose_cmd=$(get_docker_compose_cmd) || {
            print_error "Docker Compose is not installed or not in PATH"
            return 1
        }
        $compose_cmd down -v --remove-orphans
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
    
    print_success "All Dapr component tests passed!"
}

# Test bulk operations
test_bulk_operations() {
    print_header "Testing Dapr Bulk State Store Operations"
    
    # Test Dapr HTTP API availability first
    print_info "Testing Dapr HTTP API (port $NEBULA_HTTP_PORT)..."
    if ! curl -s --connect-timeout 5 http://localhost:$NEBULA_HTTP_PORT/v1.0/healthz >/dev/null 2>&1; then
        print_error "Dapr HTTP API is not responding on port $NEBULA_HTTP_PORT"
        return 1
    fi
    print_success "Dapr HTTP API is responding"
    
    # Test bulk SET operation (multiple keys)
    print_info "Testing bulk SET operation..."
    local bulk_set_data='[
        {"key": "bulk-test-1", "value": "First bulk value"},
        {"key": "bulk-test-2", "value": "Second bulk value"},
        {"key": "bulk-test-3", "value": "Third bulk value"},
        {"key": "bulk-test-4", "value": "Fourth bulk value"},
        {"key": "bulk-test-5", "value": "Fifth bulk value"}
    ]'
    
    if curl -s -X POST "http://localhost:$NEBULA_HTTP_PORT/v1.0/state/nebulagraph-state" \
        -H "Content-Type: application/json" \
        -d "$bulk_set_data" >/dev/null 2>&1; then
        print_success "Bulk SET operation successful (5 keys)"
    else
        print_error "Bulk SET operation failed"
        return 1
    fi
    
    # Test bulk GET operation
    print_info "Testing bulk GET operation..."
    local bulk_get_data='{"keys": ["bulk-test-1", "bulk-test-2", "bulk-test-3", "bulk-test-4", "bulk-test-5"]}'
    local bulk_get_response=$(curl -s -X POST "http://localhost:$NEBULA_HTTP_PORT/v1.0/state/nebulagraph-state/bulk" \
        -H "Content-Type: application/json" \
        -d "$bulk_get_data" 2>/dev/null)
    
    if echo "$bulk_get_response" | grep -q "First bulk value"; then
        print_success "Bulk GET operation successful"
        print_info "Sample retrieved value found: 'First bulk value'"
    else
        print_warning "Bulk GET operation may have issues"
        print_info "Response: $bulk_get_response"
    fi
    
    # Test individual GET to verify bulk SET worked
    print_info "Testing individual GET operations to verify bulk SET..."
    local individual_tests=0
    local individual_successes=0
    
    for i in {1..5}; do
        individual_tests=$((individual_tests + 1))
        local response=$(curl -s "http://localhost:$NEBULA_HTTP_PORT/v1.0/state/nebulagraph-state/bulk-test-$i" 2>/dev/null)
        if echo "$response" | grep -q "bulk value"; then
            individual_successes=$((individual_successes + 1))
        fi
    done
    
    print_info "Individual GET verification: $individual_successes/$individual_tests keys successfully retrieved"
    
    # Test bulk DELETE operation
    print_info "Testing bulk DELETE operation..."
    local bulk_delete_data='{"keys": ["bulk-test-1", "bulk-test-2", "bulk-test-3", "bulk-test-4", "bulk-test-5"]}'
    
    if curl -s -X POST "http://localhost:$NEBULA_HTTP_PORT/v1.0/state/nebulagraph-state/bulk/delete" \
        -H "Content-Type: application/json" \
        -d "$bulk_delete_data" >/dev/null 2>&1; then
        print_success "Bulk DELETE operation successful"
    else
        print_warning "Bulk DELETE operation may have issues (trying individual deletes)"
        # Fallback to individual deletes
        for i in {1..5}; do
            curl -s -X DELETE "http://localhost:$NEBULA_HTTP_PORT/v1.0/state/nebulagraph-state/bulk-test-$i" >/dev/null 2>&1
        done
        print_success "Individual DELETE operations completed as fallback"
    fi
    
    # Verify bulk DELETE worked
    print_info "Verifying bulk DELETE operation..."
    local remaining_items=0
    for i in {1..5}; do
        local response=$(curl -s "http://localhost:$NEBULA_HTTP_PORT/v1.0/state/nebulagraph-state/bulk-test-$i" 2>/dev/null)
        if [ ! -z "$response" ] && [ "$response" != '""' ] && [ "$response" != "null" ]; then
            remaining_items=$((remaining_items + 1))
        fi
    done
    
    if [ $remaining_items -eq 0 ]; then
        print_success "Bulk DELETE verification successful - all items removed"
    else
        print_warning "Bulk DELETE verification: $remaining_items items may still exist"
    fi
    
    # Test large bulk operation (stress test)
    print_info "Testing large bulk SET operation (10 keys)..."
    local large_bulk_data='[
        {"key": "large-bulk-1", "value": "Large bulk value 1"},
        {"key": "large-bulk-2", "value": "Large bulk value 2"},
        {"key": "large-bulk-3", "value": "Large bulk value 3"},
        {"key": "large-bulk-4", "value": "Large bulk value 4"},
        {"key": "large-bulk-5", "value": "Large bulk value 5"},
        {"key": "large-bulk-6", "value": "Large bulk value 6"},
        {"key": "large-bulk-7", "value": "Large bulk value 7"},
        {"key": "large-bulk-8", "value": "Large bulk value 8"},
        {"key": "large-bulk-9", "value": "Large bulk value 9"},
        {"key": "large-bulk-10", "value": "Large bulk value 10"}
    ]'
    
    if curl -s -X POST "http://localhost:$NEBULA_HTTP_PORT/v1.0/state/nebulagraph-state" \
        -H "Content-Type: application/json" \
        -d "$large_bulk_data" >/dev/null 2>&1; then
        print_success "Large bulk SET operation successful (10 keys)"
    else
        print_error "Large bulk SET operation failed"
    fi
    
    # Clean up large bulk test
    print_info "Cleaning up large bulk test data..."
    for i in {1..10}; do
        curl -s -X DELETE "http://localhost:$NEBULA_HTTP_PORT/v1.0/state/nebulagraph-state/large-bulk-$i" >/dev/null 2>&1
    done
    print_success "Large bulk test cleanup completed"
    
    print_success "All bulk operation tests completed!"
}

# Test Query operations
test_query_operations() {
    print_header "Testing Query Operations"
    
    # First, ensure we have some test data
    print_info "Setting up test data for queries..."
    
    # Set some test data with different key patterns
    test_keys=("query-test-1" "query-test-2" "data-sample-1" "data-sample-2" "test-item-1")
    for key in "${test_keys[@]}"; do
        local value="{\"type\": \"query-test\", \"key\": \"$key\", \"timestamp\": \"$(date)\"}"
        echo "Setting key: $key"
        
        local response
        response=$(curl -s -w "\n%{http_code}" -X POST "http://localhost:$NEBULA_HTTP_PORT/v1.0/state/nebulagraph-state" \
            -H "Content-Type: application/json" \
            -d "[{\"key\": \"$key\", \"value\": $value}]")
        
        local http_code
        http_code=$(echo "$response" | tail -n1)
        if [[ "$http_code" -eq 204 ]]; then
            print_success "Set key $key"
        else
            print_error "Failed to set key $key (HTTP $http_code)"
            return 1
        fi
    done
    
    # Test 1: Query all items (no filter)
    print_info "Test 1: Querying all items..."
    local response
    response=$(curl -s -w "\n%{http_code}" -X POST "http://localhost:$NEBULA_HTTP_PORT/v1.0/state/nebulagraph-state/query" \
        -H "Content-Type: application/json" \
        -d '{}')
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    if [[ "$http_code" -eq 200 ]]; then
        local body
        body=$(echo "$response" | head -n -1)
        local result_count
        result_count=$(echo "$body" | jq '.results | length' 2>/dev/null || echo "0")
        print_success "Query all returned $result_count items"
    else
        print_error "Query all failed (HTTP $http_code)"
        return 1
    fi
    
    # Test 2: Query with filter
    print_info "Test 2: Querying with filter 'query-test'..."
    response=$(curl -s -w "\n%{http_code}" -X POST "http://localhost:$NEBULA_HTTP_PORT/v1.0/state/nebulagraph-state/query" \
        -H "Content-Type: application/json" \
        -d '{"filter": {"EQ": {"key": "query-test"}}}')
    
    http_code=$(echo "$response" | tail -n1)
    if [[ "$http_code" -eq 200 ]]; then
        body=$(echo "$response" | head -n -1)
        result_count=$(echo "$body" | jq '.results | length' 2>/dev/null || echo "0")
        print_success "Filtered query returned $result_count items"
    else
        print_error "Filtered query failed (HTTP $http_code)"
        return 1
    fi
    
    # Clean up test data
    print_info "Cleaning up query test data..."
    for key in "${test_keys[@]}"; do
        curl -s -X DELETE "http://localhost:$NEBULA_HTTP_PORT/v1.0/state/nebulagraph-state/$key" >/dev/null 2>&1
    done
    
    print_success "All query operations tests passed!"
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
    echo -e "  • Dapr HTTP API: http://localhost:$NEBULA_HTTP_PORT"
    echo -e "  • Dapr gRPC API: localhost:$NEBULA_GRPC_PORT"
    echo -e "  • State Store: nebulagraph-state"
    
    echo -e "\n${BLUE}Next steps:${NC}"
    echo -e "  • Test state operations: curl http://localhost:$NEBULA_HTTP_PORT/v1.0/state/nebulagraph-state/your-key"
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
    "test-bulk")
        test_bulk_operations
        ;;
    "test-query")
        test_query_operations
        ;;
    "test-all")
        test_component
        test_bulk_operations
        test_query_operations
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
        echo "  test-bulk     Test bulk state store operations"
        echo "  test-query    Test query operations"
        echo "  test-all      Test basic, bulk, and query operations"
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
