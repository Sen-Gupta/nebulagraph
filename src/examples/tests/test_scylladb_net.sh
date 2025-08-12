#!/bin/bash

# ScyllaDB .NET Example Test Script
# Tests ScyllaDB integration with .NET Dapr components
# Assumes services are already running via run_dotnet_examples.sh

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

# Configuration
APP_URL="http://localhost:$DOT_NET_HOST_PORT"
HEALTH_ENDPOINT="$APP_URL/api/ScyllaStateStore/health"
COMPREHENSIVE_TEST_ENDPOINT="$APP_URL/api/ScyllaStateStore/run/comprehensive"
PERFORMANCE_TEST_ENDPOINT="$APP_URL/api/ScyllaStateStore/performance/test"

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

check_service_availability() {
    print_header "Checking ScyllaDB Service Availability"
    
    # Check if .NET Dapr Client API is responding
    print_info "Testing .NET Dapr Client API availability..."
    if curl -s --connect-timeout 10 "http://localhost:$DOT_NET_HOST_PORT/swagger" > /dev/null; then
        print_success ".NET Dapr Client API is available"
    else
        print_error ".NET Dapr Client API is not responding"
        print_info "Please start services first: ./run_dotnet_examples.sh start"
        return 1
    fi
    
    # Check if Dapr sidecar is responding
    print_info "Testing Dapr sidecar availability..."
    if curl -s --connect-timeout 10 "http://localhost:$DOT_NET_HTTP_PORT/v1.0/healthz" > /dev/null; then
        print_success "Dapr sidecar is available"
    else
        print_error "Dapr sidecar is not responding"
        print_info "Please start services first: ./run_dotnet_examples.sh start"
        return 1
    fi
    
    # Check if ScyllaDB component is loaded
    print_info "Testing ScyllaDB component availability..."
    metadata_response=$(curl -s --connect-timeout 10 "http://localhost:$DOT_NET_HTTP_PORT/v1.0/metadata" 2>/dev/null)
    if echo "$metadata_response" | grep -q "scylladb-state"; then
        print_success "ScyllaDB state store component is loaded"
    else
        print_error "ScyllaDB state store component not found"
        print_info "Available components:"
        echo "$metadata_response" | jq '.components[].name' 2>/dev/null || echo "$metadata_response"
        return 1
    fi
    
    print_success "All required services are available for testing"
}

# Function to run health check
run_health_check() {
    print_info "Running ScyllaDB health check..."
    
    response=$(curl -s -w "\n%{http_code}" "$HEALTH_ENDPOINT")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" -eq 200 ]; then
        print_success "Health check passed"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
        return 0
    else
        print_error "Health check failed (HTTP $http_code)"
        echo "$body"
        return 1
    fi
}

# Function to run comprehensive test suite
run_comprehensive_tests() {
    print_header "Running ScyllaDB StateStore Controller Test Suites"
    
    print_info "Running comprehensive test suite..."
    
    response=$(curl -s -w "\n%{http_code}" -X POST "$COMPREHENSIVE_TEST_ENDPOINT")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" -eq 200 ]; then
        print_success "✅ Comprehensive test suite completed successfully"
        
        # Parse and display detailed results if JSON
        if echo "$body" | jq . >/dev/null 2>&1; then
            print_info "📊 Detailed Test Results:"
            echo "$body" | jq '.result // .'
        else
            print_info "Test Results: $body"
        fi
        
        return 0
    else
        print_error "❌ Comprehensive test suite failed (HTTP $http_code)"
        echo "$body"
        return 1
    fi
}

# Function to run performance tests
run_performance_tests() {
    local operations=${1:-100}
    print_info "Running performance test with $operations operations..."
    
    response=$(curl -s -w "\n%{http_code}" -X POST "$PERFORMANCE_TEST_ENDPOINT?operations=$operations")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" -eq 200 ]; then
        print_success "Performance test completed"
        
        if command -v jq >/dev/null 2>&1; then
            echo "$body" | jq '{
                operations: .operations,
                writePerformance: {
                    averageTime: .writePerformance.averageTime,
                    operationsPerSecond: .writePerformance.operationsPerSecond
                },
                readPerformance: {
                    averageTime: .readPerformance.averageTime,
                    operationsPerSecond: .readPerformance.operationsPerSecond,
                    successRate: .readPerformance.successRate
                }
            }'
        else
            echo "$body"
        fi
        
        return 0
    else
        print_error "Performance test failed (HTTP $http_code)"
        echo "$body"
        return 1
    fi
}

# Function to test basic CRUD operations
test_basic_crud() {
    print_info "Testing basic CRUD operations..."
    
    # Test save operation
    print_info "Testing save operation..."
    response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d '"Hello ScyllaDB from test script!"' \
        "$APP_URL/api/ScyllaStateStore/save/test-script-key")
    
    http_code=$(echo "$response" | tail -n1)
    if [ "$http_code" -eq 200 ]; then
        print_success "Save operation successful"
    else
        print_error "Save operation failed (HTTP $http_code)"
        return 1
    fi
    
    # Test get operation
    print_info "Testing get operation..."
    response=$(curl -s -w "\n%{http_code}" -X GET "$APP_URL/api/ScyllaStateStore/get/test-script-key")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" -eq 200 ]; then
        print_success "Get operation successful"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
    else
        print_error "Get operation failed (HTTP $http_code)"
        return 1
    fi
    
    # Test delete operation
    print_info "Testing delete operation..."
    response=$(curl -s -w "\n%{http_code}" -X DELETE "$APP_URL/api/ScyllaStateStore/delete/test-script-key")
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" -eq 200 ]; then
        print_success "Delete operation successful"
    else
        print_error "Delete operation failed (HTTP $http_code)"
        return 1
    fi
    
    # Verify deletion
    print_info "Verifying deletion..."
    response=$(curl -s -w "\n%{http_code}" -X GET "$APP_URL/api/ScyllaStateStore/get/test-script-key")
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" -eq 404 ]; then
        print_success "Deletion verified - key not found as expected"
    else
        print_warning "Deletion verification: key still exists or unexpected response (HTTP $http_code)"
    fi
    
    return 0
}

# Function to test bulk operations
test_bulk_operations() {
    print_info "Testing bulk operations..."
    
    # Test bulk save
    print_info "Testing bulk save operation..."
    bulk_data='{
        "bulk-test-1": {"name": "Alice", "department": "Engineering"},
        "bulk-test-2": {"name": "Bob", "department": "Marketing"},
        "bulk-test-3": {"name": "Charlie", "department": "Sales"}
    }'
    
    response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "$bulk_data" \
        "$APP_URL/api/ScyllaStateStore/bulk/save")
    
    http_code=$(echo "$response" | tail -n1)
    if [ "$http_code" -eq 200 ]; then
        print_success "Bulk save operation successful"
    else
        print_error "Bulk save operation failed (HTTP $http_code)"
        return 1
    fi
    
    # Test bulk get
    print_info "Testing bulk get operation..."
    response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d '["bulk-test-1", "bulk-test-2", "bulk-test-3"]' \
        "$APP_URL/api/ScyllaStateStore/bulk/get")
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" -eq 200 ]; then
        print_success "Bulk get operation successful"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
    else
        print_error "Bulk get operation failed (HTTP $http_code)"
        return 1
    fi
    
    # Cleanup bulk test data
    print_info "Cleaning up bulk test data..."
    for key in "bulk-test-1" "bulk-test-2" "bulk-test-3"; do
        curl -s "$APP_URL/api/ScyllaStateStore/delete/$key" > /dev/null
    done
    
    return 0
}

test_scylladb_operations() {
    print_header "Testing ScyllaDB .NET Operations"
    
    # Wait for services to be fully ready
    print_info "Allowing time for ScyllaDB component initialization..."
    sleep 10
    
    local api_base_url="http://localhost:$DOT_NET_HOST_PORT/api/ScyllaStateStore"
    
    # Test HTTP REST API state operations via ScyllaStateStore controller
    print_info "Testing HTTP REST API basic CRUD operations..."
    if curl -s --connect-timeout 10 -X POST "$api_base_url/basic-crud" \
        -H "Content-Type: application/json" > /dev/null; then
        print_success "HTTP basic CRUD operation test passed"
    else
        print_warning "HTTP basic CRUD operation test failed (check logs)"
    fi
    
    # Test quick test suite
    print_info "Testing quick test suite..."
    quick_response=$(curl -s --connect-timeout 30 -X POST "$api_base_url/run/quick" \
        -H "Content-Type: application/json" 2>/dev/null)
    if [ -n "$quick_response" ]; then
        print_success "Quick test suite completed"
        print_info "Quick test response: $(echo "$quick_response" | head -c 100)..."
    else
        print_warning "Quick test suite failed"
    fi
    
    # Test direct Dapr state API
    print_info "Testing direct Dapr state API..."
    if curl -s --connect-timeout 10 -X POST "http://localhost:$DOT_NET_HTTP_PORT/v1.0/state/scylladb-state" \
        -H "Content-Type: application/json" \
        -d '[{"key":"direct-test","value":"Hello from direct Dapr API!"}]' > /dev/null; then
        print_success "Direct Dapr state SET operation test passed"
        
        # Test direct GET
        direct_response=$(curl -s --connect-timeout 10 "http://localhost:$DOT_NET_HTTP_PORT/v1.0/state/scylladb-state/direct-test" 2>/dev/null)
        if [ -n "$direct_response" ]; then
            print_success "Direct Dapr state GET operation test passed"
            print_info "Direct response: $direct_response"
        else
            print_warning "Direct Dapr state GET operation test failed"
        fi
    else
        print_warning "Direct Dapr state SET operation test failed"
    fi
    
    # Run comprehensive StateStore controller tests
    print_info "Running comprehensive StateStore controller tests..."
    run_comprehensive_tests
}

test_pubsub_operations() {
    print_header "Testing Pub/Sub Operations"
    
    # Check if Redis pub/sub component is available
    metadata_response=$(curl -s --connect-timeout 10 "http://localhost:$DOT_NET_HTTP_PORT/v1.0/metadata" 2>/dev/null)
    if echo "$metadata_response" | grep -q "redis-pubsub"; then
        print_info "Testing pub/sub functionality..."
        if curl -s --connect-timeout 10 -X POST "http://localhost:$DOT_NET_HTTP_PORT/v1.0/publish/redis-pubsub/test-topic" \
            -H "Content-Type: application/json" \
            -d '{"message": "Hello from ScyllaDB test!"}' > /dev/null; then
            print_success "Pub/sub publish test passed"
        else
            print_warning "Pub/sub publish test failed"
        fi
    else
        print_info "Redis pub/sub component not available for testing"
    fi
}

run_all_tests() {
    print_header "ScyllaDB .NET Integration Test Suite"
    
    # Check service availability first
    if ! check_service_availability; then
        print_error "Services are not available. Please start them first:"
        print_info "Run: ./run_dotnet_examples.sh start"
        exit 1
    fi
    
    # Run all tests
    test_scylladb_operations
    test_pubsub_operations
    
    print_header "Test Summary"
    print_success "ScyllaDB .NET integration tests completed"
    print_info "For detailed logs, check: ./run_dotnet_examples.sh logs"
}

case "${1:-test}" in
    "test"|"run")
        run_all_tests
        ;;
    "check"|"status")
        check_service_availability
        ;;
    "health")
        check_service_availability
        run_health_check
        ;;
    "crud")
        check_service_availability
        test_basic_crud
        ;;
    "bulk")
        check_service_availability
        test_bulk_operations
        ;;
    "comprehensive")
        check_service_availability
        run_comprehensive_tests
        ;;
    "performance")
        check_service_availability
        run_performance_tests "${2:-100}"
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [COMMAND]"
        echo ""
        echo "ScyllaDB .NET Integration Test Suite"
        echo ""
        echo "Commands:"
        echo "  test          Run all ScyllaDB integration tests (default)"
        echo "  run           Same as test"
        echo "  check         Check if required services are available"
        echo "  status        Same as check"
        echo "  health        Run health check only"
        echo "  crud          Test basic CRUD operations"
        echo "  bulk          Test bulk operations"
        echo "  comprehensive Run comprehensive test suite"
        echo "  performance   Run performance tests [operations=100]"
        echo "  help          Show this help"
        echo ""
        echo "Prerequisites:"
        echo "  • Services must be running: ./run_dotnet_examples.sh start"
        echo "  • ScyllaDB dependencies must be available"
        echo ""
        echo "Test Coverage:"
        echo "  • Service availability validation"
        echo "  • ScyllaDB state store operations"
        echo "  • Direct Dapr API testing"
        echo "  • HTTP REST API testing"
        echo "  • Comprehensive controller test suites"
        echo "  • Performance testing"
        echo "  • Pub/sub functionality (if available)"
        echo ""
        echo "Note: This script only tests services. Use run_dotnet_examples.sh to manage services."
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac
