#!/bin/bash

# ScyllaDB .NET Example Test Script
# This script tests the ScyllaDB Dapr pluggable state store integration

set -e

echo "=========================================="
echo "ScyllaDB .NET Example Test Suite"
echo "=========================================="

# Configuration
APP_URL="http://localhost:5001"
HEALTH_ENDPOINT="$APP_URL/api/StateStore/health"
COMPREHENSIVE_TEST_ENDPOINT="$APP_URL/api/StateStore/run/comprehensive"
PERFORMANCE_TEST_ENDPOINT="$APP_URL/api/StateStore/performance/test"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
    esac
}

# Function to wait for service
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=30
    local attempt=1
    
    print_status "INFO" "Waiting for $service_name to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            print_status "SUCCESS" "$service_name is ready!"
            return 0
        fi
        
        print_status "INFO" "Attempt $attempt/$max_attempts - $service_name not ready, waiting..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    print_status "ERROR" "$service_name failed to start after $max_attempts attempts"
    return 1
}

# Function to run health check
run_health_check() {
    print_status "INFO" "Running health check..."
    
    response=$(curl -s -w "\n%{http_code}" "$HEALTH_ENDPOINT")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" -eq 200 ]; then
        print_status "SUCCESS" "Health check passed"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
        return 0
    else
        print_status "ERROR" "Health check failed (HTTP $http_code)"
        echo "$body"
        return 1
    fi
}

# Function to run comprehensive test suite
run_comprehensive_tests() {
    print_status "INFO" "Running comprehensive test suite..."
    
    response=$(curl -s -w "\n%{http_code}" -X POST "$COMPREHENSIVE_TEST_ENDPOINT")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" -eq 200 ]; then
        print_status "SUCCESS" "Comprehensive test suite completed"
        
        # Parse and display results
        if command -v jq >/dev/null 2>&1; then
            echo "$body" | jq '{
                TestSuite: .TestSuite,
                TotalTests: .TotalTests,
                PassedTests: .PassedTests,
                FailedTests: .FailedTests,
                TotalDuration: .TotalDuration,
                AverageDuration: .AverageDuration
            }'
            
            # Show failed tests if any
            failed_tests=$(echo "$body" | jq -r '.Results[] | select(.Success == false) | .TestName')
            if [ -n "$failed_tests" ]; then
                print_status "WARNING" "Failed tests:"
                echo "$failed_tests"
            fi
        else
            echo "$body"
        fi
        
        return 0
    else
        print_status "ERROR" "Comprehensive test suite failed (HTTP $http_code)"
        echo "$body"
        return 1
    fi
}

# Function to run performance tests
run_performance_tests() {
    local operations=${1:-100}
    print_status "INFO" "Running performance test with $operations operations..."
    
    response=$(curl -s -w "\n%{http_code}" -X POST "$PERFORMANCE_TEST_ENDPOINT?operations=$operations")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" -eq 200 ]; then
        print_status "SUCCESS" "Performance test completed"
        
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
        print_status "ERROR" "Performance test failed (HTTP $http_code)"
        echo "$body"
        return 1
    fi
}

# Function to test basic CRUD operations
test_basic_crud() {
    print_status "INFO" "Testing basic CRUD operations..."
    
    # Test save operation
    print_status "INFO" "Testing save operation..."
    response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d '"Hello ScyllaDB from test script!"' \
        "$APP_URL/api/StateStore/save/test-script-key")
    
    http_code=$(echo "$response" | tail -n1)
    if [ "$http_code" -eq 200 ]; then
        print_status "SUCCESS" "Save operation successful"
    else
        print_status "ERROR" "Save operation failed (HTTP $http_code)"
        return 1
    fi
    
    # Test get operation
    print_status "INFO" "Testing get operation..."
    response=$(curl -s -w "\n%{http_code}" -X GET "$APP_URL/api/StateStore/get/test-script-key")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" -eq 200 ]; then
        print_status "SUCCESS" "Get operation successful"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
    else
        print_status "ERROR" "Get operation failed (HTTP $http_code)"
        return 1
    fi
    
    # Test delete operation
    print_status "INFO" "Testing delete operation..."
    response=$(curl -s -w "\n%{http_code}" -X DELETE "$APP_URL/api/StateStore/delete/test-script-key")
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" -eq 200 ]; then
        print_status "SUCCESS" "Delete operation successful"
    else
        print_status "ERROR" "Delete operation failed (HTTP $http_code)"
        return 1
    fi
    
    # Verify deletion
    print_status "INFO" "Verifying deletion..."
    response=$(curl -s -w "\n%{http_code}" -X GET "$APP_URL/api/StateStore/get/test-script-key")
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" -eq 404 ]; then
        print_status "SUCCESS" "Deletion verified - key not found as expected"
    else
        print_status "WARNING" "Deletion verification: key still exists or unexpected response (HTTP $http_code)"
    fi
    
    return 0
}

# Function to test bulk operations
test_bulk_operations() {
    print_status "INFO" "Testing bulk operations..."
    
    # Test bulk save
    print_status "INFO" "Testing bulk save operation..."
    bulk_data='{
        "bulk-test-1": {"name": "Alice", "department": "Engineering"},
        "bulk-test-2": {"name": "Bob", "department": "Marketing"},
        "bulk-test-3": {"name": "Charlie", "department": "Sales"}
    }'
    
    response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "$bulk_data" \
        "$APP_URL/api/StateStore/bulk/save")
    
    http_code=$(echo "$response" | tail -n1)
    if [ "$http_code" -eq 200 ]; then
        print_status "SUCCESS" "Bulk save operation successful"
    else
        print_status "ERROR" "Bulk save operation failed (HTTP $http_code)"
        return 1
    fi
    
    # Test bulk get
    print_status "INFO" "Testing bulk get operation..."
    response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d '["bulk-test-1", "bulk-test-2", "bulk-test-3"]' \
        "$APP_URL/api/StateStore/bulk/get")
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" -eq 200 ]; then
        print_status "SUCCESS" "Bulk get operation successful"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
    else
        print_status "ERROR" "Bulk get operation failed (HTTP $http_code)"
        return 1
    fi
    
    # Cleanup bulk test data
    print_status "INFO" "Cleaning up bulk test data..."
    for key in "bulk-test-1" "bulk-test-2" "bulk-test-3"; do
        curl -s "$APP_URL/api/StateStore/delete/$key" > /dev/null
    done
    
    return 0
}

# Main execution
main() {
    print_status "INFO" "Starting ScyllaDB .NET example test suite..."
    
    # Check if curl is available
    if ! command -v curl >/dev/null 2>&1; then
        print_status "ERROR" "curl is required but not installed"
        exit 1
    fi
    
    # Check if jq is available (optional)
    if ! command -v jq >/dev/null 2>&1; then
        print_status "WARNING" "jq not found - JSON output will not be formatted"
    fi
    
    # Wait for the application to be ready
    if ! wait_for_service "$HEALTH_ENDPOINT" "ScyllaDB .NET Example"; then
        print_status "ERROR" "Application is not ready, exiting"
        exit 1
    fi
    
    echo ""
    print_status "INFO" "Running test sequence..."
    echo ""
    
    # Run tests in sequence
    test_passed=0
    test_total=5
    
    # Test 1: Health Check
    if run_health_check; then
        test_passed=$((test_passed + 1))
    fi
    echo ""
    
    # Test 2: Basic CRUD Operations
    if test_basic_crud; then
        test_passed=$((test_passed + 1))
    fi
    echo ""
    
    # Test 3: Bulk Operations
    if test_bulk_operations; then
        test_passed=$((test_passed + 1))
    fi
    echo ""
    
    # Test 4: Comprehensive Test Suite
    if run_comprehensive_tests; then
        test_passed=$((test_passed + 1))
    fi
    echo ""
    
    # Test 5: Performance Tests
    if run_performance_tests 50; then
        test_passed=$((test_passed + 1))
    fi
    echo ""
    
    # Final results
    echo "=========================================="
    if [ $test_passed -eq $test_total ]; then
        print_status "SUCCESS" "All tests passed! ($test_passed/$test_total)"
        echo "=========================================="
        exit 0
    else
        print_status "ERROR" "Some tests failed ($test_passed/$test_total)"
        echo "=========================================="
        exit 1
    fi
}

# Parse command line arguments
case "${1:-}" in
    "health")
        wait_for_service "$HEALTH_ENDPOINT" "ScyllaDB .NET Example"
        run_health_check
        ;;
    "crud")
        wait_for_service "$HEALTH_ENDPOINT" "ScyllaDB .NET Example"
        test_basic_crud
        ;;
    "bulk")
        wait_for_service "$HEALTH_ENDPOINT" "ScyllaDB .NET Example"
        test_bulk_operations
        ;;
    "comprehensive")
        wait_for_service "$HEALTH_ENDPOINT" "ScyllaDB .NET Example"
        run_comprehensive_tests
        ;;
    "performance")
        wait_for_service "$HEALTH_ENDPOINT" "ScyllaDB .NET Example"
        run_performance_tests "${2:-100}"
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  health        - Run health check only"
        echo "  crud          - Test basic CRUD operations"
        echo "  bulk          - Test bulk operations"
        echo "  comprehensive - Run comprehensive test suite"
        echo "  performance   - Run performance tests [operations=100]"
        echo "  help          - Show this help message"
        echo ""
        echo "Default: Run all tests"
        ;;
    *)
        main
        ;;
esac
