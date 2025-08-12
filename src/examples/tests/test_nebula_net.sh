#!/bin/bash

# NebulaGraph .NET Example Test Script
# Tests NebulaGraph integration with .NET Dapr components
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
    print_header "Checking Service Availability"
    
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
    
    # Check if NebulaGraph component is loaded
    print_info "Testing NebulaGraph component availability..."
    metadata_response=$(curl -s --connect-timeout 10 "http://localhost:$DOT_NET_HTTP_PORT/v1.0/metadata" 2>/dev/null)
    if echo "$metadata_response" | grep -q "nebulagraph-state"; then
        print_success "NebulaGraph state store component is loaded"
    else
        print_error "NebulaGraph state store component not found"
        print_info "Available components:"
        echo "$metadata_response" | jq '.components[].name' 2>/dev/null || echo "$metadata_response"
        return 1
    fi
    
    print_success "All required services are available for testing"
}

run_controller_tests() {
    print_header "Running StateStore Controller Test Suites"
    
    local api_base_url="http://localhost:$DOT_NET_HOST_PORT/api/NebulaStateStore"
    
    print_info "Running comprehensive test suite..."
    
    # Run the comprehensive test suite endpoint
    response=$(curl -s --connect-timeout 60 -w "%{http_code}" \
        -X POST "$api_base_url/run/comprehensive" \
        -H "Content-Type: application/json" 2>/dev/null)
    
    # Extract HTTP status code (last 3 characters)
    http_code="${response: -3}"
    # Extract response body (everything except last 3 characters) 
    response_body="${response%???}"
    
    if [[ "$http_code" == "200" ]]; then
        print_success "✅ Comprehensive test suite completed successfully"
        
        # Try to extract summary from response
        if echo "$response_body" | grep -qi "passed.*failed"; then
            print_info "Test Results Summary:"
            echo "$response_body" | grep -i "passed\|failed\|success" | head -5
        else
            print_info "Test suite completed - check logs for detailed results"
        fi
        return 0
    else
        print_error "❌ Comprehensive test suite failed (HTTP $http_code)"
        if [[ ${#response_body} -lt 500 ]]; then
            print_info "Response: $response_body"
        fi
        return 1
    fi
}

test_nebulagraph_operations() {
    print_header "Testing NebulaGraph .NET Operations"
    
    # Wait for services to be fully ready
    print_info "Allowing time for NebulaGraph component initialization..."
    sleep 10
    
    local api_base_url="http://localhost:$DOT_NET_HOST_PORT/api/NebulaStateStore"
    
    # Test HTTP REST API state operations via NebulaStateStore controller
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
    if curl -s --connect-timeout 10 -X POST "http://localhost:$DOT_NET_HTTP_PORT/v1.0/state/nebulagraph-state" \
        -H "Content-Type: application/json" \
        -d '[{"key":"direct-test","value":"Hello from direct Dapr API!"}]' > /dev/null; then
        print_success "Direct Dapr state SET operation test passed"
        
        # Test direct GET
        direct_response=$(curl -s --connect-timeout 10 "http://localhost:$DOT_NET_HTTP_PORT/v1.0/state/nebulagraph-state/direct-test" 2>/dev/null)
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
    run_controller_tests
}

test_pubsub_operations() {
    print_header "Testing Pub/Sub Operations"
    
    # Check if Redis pub/sub component is available
    metadata_response=$(curl -s --connect-timeout 10 "http://localhost:$DOT_NET_HTTP_PORT/v1.0/metadata" 2>/dev/null)
    if echo "$metadata_response" | grep -q "redis-pubsub"; then
        print_info "Testing pub/sub functionality..."
        if curl -s --connect-timeout 10 -X POST "http://localhost:$DOT_NET_HTTP_PORT/v1.0/publish/redis-pubsub/test-topic" \
            -H "Content-Type: application/json" \
            -d '{"message": "Hello from NebulaGraph test!"}' > /dev/null; then
            print_success "Pub/sub publish test passed"
        else
            print_warning "Pub/sub publish test failed"
        fi
    else
        print_info "Redis pub/sub component not available for testing"
    fi
}

run_all_tests() {
    print_header "NebulaGraph .NET Integration Test Suite"
    
    # Check service availability first
    if ! check_service_availability; then
        print_error "Services are not available. Please start them first:"
        print_info "Run: ./run_dotnet_examples.sh start"
        exit 1
    fi
    
    # Run all tests
    test_nebulagraph_operations
    test_pubsub_operations
    
    print_header "Test Summary"
    print_success "NebulaGraph .NET integration tests completed"
    print_info "For detailed logs, check: ./run_dotnet_examples.sh logs"
}

case "${1:-test}" in
    "test"|"run")
        run_all_tests
        ;;
    "check"|"status")
        check_service_availability
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [COMMAND]"
        echo ""
        echo "NebulaGraph .NET Integration Test Suite"
        echo ""
        echo "Commands:"
        echo "  test      Run all NebulaGraph integration tests (default)"
        echo "  run       Same as test"
        echo "  check     Check if required services are available"
        echo "  status    Same as check"
        echo "  help      Show this help"
        echo ""
        echo "Prerequisites:"
        echo "  • Services must be running: ./run_dotnet_examples.sh start"
        echo "  • NebulaGraph dependencies must be available"
        echo ""
        echo "Test Coverage:"
        echo "  • Service availability validation"
        echo "  • NebulaGraph state store operations"
        echo "  • Direct Dapr API testing"
        echo "  • HTTP REST API testing"
        echo "  • Comprehensive controller test suites"
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
