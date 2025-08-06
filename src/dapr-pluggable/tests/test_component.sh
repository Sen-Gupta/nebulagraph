#!/bin/bash

# Load environment configuration if available
if [ -f "../../.env" ]; then
    source ../../.env
fi

echo "Testing NebulaGraph Dapr State Store Component"
echo "=============================================="

# Base configuration
DAPR_HTTP_PORT=${NEBULA_HTTP_PORT:-3501}
NEBULA_NETWORK_NAME=${NEBULA_NETWORK_NAME:-nebula-net}
DAPR_URL="http://localhost:$DAPR_HTTP_PORT/v1.0/state/nebulagraph-state"

echo "Configuration:"
echo "  • HTTP Port: $DAPR_HTTP_PORT"
echo "  • Network: $NEBULA_NETWORK_NAME"
echo "  • Base URL: $DAPR_URL"
echo ""

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_test_header() {
    echo -e "\n${BLUE}$1${NC}"
    echo "----------------------------------------"
}

print_pass() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
    ((PASSED_TESTS++))
    ((TOTAL_TESTS++))
}

print_fail() {
    echo -e "${RED}❌ FAIL${NC}: $1"
    ((FAILED_TESTS++))
    ((TOTAL_TESTS++))
}

print_info() {
    echo -e "${BLUE}ℹ️  INFO${NC}: $1"
}

print_summary() {
    echo ""
    echo "=============================================="
    echo -e "${BLUE}TEST SUMMARY${NC}"
    echo "=============================================="
    echo -e "Total Tests: ${TOTAL_TESTS}"
    echo -e "${GREEN}Passed: ${PASSED_TESTS}${NC}"
    echo -e "${RED}Failed: ${FAILED_TESTS}${NC}"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "\n${GREEN}🎉 ALL TESTS PASSED!${NC}"
        echo "✅ NebulaGraph Dapr State Store is working correctly"
        return 0
    else
        echo -e "\n${RED}❌ SOME TESTS FAILED!${NC}"
        echo "Please check the component configuration and NebulaGraph connectivity"
        return 1
    fi
}

# Function to verify the prerequisites are met
check_prerequisites() {
    print_test_header "0. Checking Prerequisites"
    
    # Check if Dapr is running
    if ! curl -s http://localhost:3501/v1.0/healthz > /dev/null 2>&1; then
        print_fail "Dapr is not running on localhost:3501"
        print_info "Please ensure the Dapr sidecar is running on port 3501"
        return 1
    else
        print_pass "Dapr runtime is accessible on localhost:3501"
    fi
    
    # Verify the space and schema exist
    verify_result=$(docker run --rm --network $NEBULA_NETWORK_NAME vesoft/nebula-console:v3-nightly \
        --addr nebula-graphd --port 9669 --user root --password nebula \
        --eval "USE dapr_state; SHOW TAGS;" 2>&1)
    
    if echo "$verify_result" | grep -q "state"; then
        print_pass "NebulaGraph dapr_state space and schema are ready"
        return 0
    else
        print_fail "NebulaGraph dapr_state space or schema not found"
        print_info "Please run the initialization script: cd ../dependencies && ./environment_setup.sh"
        return 1
    fi
}

# Run prerequisite checks
check_prerequisites
if [ $? -ne 0 ]; then
    print_summary
    exit 1
fi

# Test 1: SET operation
print_test_header "1. Testing SET Operation"
set_response=$(curl -s -w "%{http_code}" -X POST "$DAPR_URL" \
  -H "Content-Type: application/json" \
  -d '[
    {
      "key": "test-key-1",
      "value": "Hello NebulaGraph!"
    },
    {
      "key": "test-key-2", 
      "value": {"message": "This is a JSON value", "timestamp": "2025-07-30"}
    }
  ]')

http_code="${set_response: -3}"
if [ "$http_code" = "204" ] || [ "$http_code" = "200" ]; then
    print_pass "SET operation successful (HTTP $http_code)"
else
    print_fail "SET operation failed (HTTP $http_code)"
    print_info "Response: $set_response"
fi

# Test 2: GET operation for test-key-1
print_test_header "2. Testing GET Operation (Simple String)"
get_response_1=$(curl -s -w "|%{http_code}" "$DAPR_URL/test-key-1")
http_code=$(echo "$get_response_1" | grep -o '[0-9]*$')
response_body=$(echo "$get_response_1" | sed 's/|[0-9]*$//')

if [ "$http_code" = "200" ] && [ "$response_body" = '"Hello NebulaGraph!"' ]; then
    print_pass "GET operation successful for test-key-1"
    print_info "Retrieved: $response_body"
else
    print_fail "GET operation failed for test-key-1"
    print_info "Expected: \"Hello NebulaGraph!\", Got: $response_body (HTTP $http_code)"
fi

# Test 3: GET operation for test-key-2
print_test_header "3. Testing GET Operation (JSON Object)"
get_response_2=$(curl -s -w "|%{http_code}" "$DAPR_URL/test-key-2")
http_code=$(echo "$get_response_2" | grep -o '[0-9]*$')
response_body=$(echo "$get_response_2" | sed 's/|[0-9]*$//')

if [ "$http_code" = "200" ] && echo "$response_body" | grep -q "This is a JSON value"; then
    print_pass "GET operation successful for test-key-2"
    print_info "Retrieved: $response_body"
else
    print_fail "GET operation failed for test-key-2"
    print_info "Got: $response_body (HTTP $http_code)"
fi

# Test 4: BULK GET operation
print_test_header "4. Testing BULK GET Operation"
bulk_response=$(curl -s -w "|%{http_code}" -X POST "$DAPR_URL/bulk" \
  -H "Content-Type: application/json" \
  -d '{
    "keys": ["test-key-1", "test-key-2"]
  }')

http_code=$(echo "$bulk_response" | grep -o '[0-9]*$')
response_body=$(echo "$bulk_response" | sed 's/|[0-9]*$//')

if [ "$http_code" = "200" ] && echo "$response_body" | grep -q "test-key-1" && echo "$response_body" | grep -q "test-key-2"; then
    print_pass "BULK GET operation successful"
    print_info "Retrieved both keys successfully"
else
    print_fail "BULK GET operation failed"
    print_info "Got: $response_body (HTTP $http_code)"
fi

# Test 5: DELETE operation
print_test_header "5. Testing DELETE Operation"
delete_response=$(curl -s -w "%{http_code}" -X DELETE "$DAPR_URL/test-key-1")
http_code="${delete_response: -3}"

if [ "$http_code" = "200" ] || [ "$http_code" = "204" ]; then
    print_pass "DELETE operation successful (HTTP $http_code)"
else
    print_fail "DELETE operation failed (HTTP $http_code)"
fi

# Test 6: Verify deletion
print_test_header "6. Verifying Deletion"
verify_response=$(curl -s -w "|%{http_code}" "$DAPR_URL/test-key-1")
http_code=$(echo "$verify_response" | grep -o '[0-9]*$')
response_body=$(echo "$verify_response" | sed 's/|[0-9]*$//')

if [ "$http_code" = "204" ] || [ -z "$response_body" ] || [ "$response_body" = '""' ]; then
    print_pass "Deletion verified - key no longer exists"
else
    print_fail "Deletion verification failed - key still exists"
    print_info "Got: $response_body (HTTP $http_code)"
fi

# Final cleanup - delete remaining test key
print_test_header "7. Cleanup"
cleanup_response=$(curl -s -w "%{http_code}" -X DELETE "$DAPR_URL/test-key-2")
http_code="${cleanup_response: -3}"

if [ "$http_code" = "200" ] || [ "$http_code" = "204" ]; then
    print_pass "Cleanup successful - removed test-key-2"
else
    print_fail "Cleanup failed for test-key-2"
fi

# Print final summary
print_summary
exit $?
