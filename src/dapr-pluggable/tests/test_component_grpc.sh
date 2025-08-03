#!/bin/bash

echo "Testing NebulaGraph Dapr State Store Component - gRPC Interface"
echo "=============================================================="

# Base configuration for Dapr gRPC API
DAPR_GRPC_PORT="50001"
COMPONENT_NAME="nebulagraph-state"

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
    echo "=============================================================="
    echo -e "${BLUE}gRPC TEST SUMMARY${NC}"
    echo "=============================================================="
    echo -e "Total Tests: ${TOTAL_TESTS}"
    echo -e "${GREEN}Passed: ${PASSED_TESTS}${NC}"
    echo -e "${RED}Failed: ${FAILED_TESTS}${NC}"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "\n${GREEN}🎉 ALL gRPC TESTS PASSED!${NC}"
        echo "✅ NebulaGraph Dapr State Store gRPC interface is working correctly"
        return 0
    else
        echo -e "\n${RED}❌ SOME gRPC TESTS FAILED!${NC}"
        echo "Please check the Dapr gRPC configuration and component connectivity"
        return 1
    fi
}

# Function to check if grpcurl is available
check_grpcurl() {
    if ! command -v grpcurl &> /dev/null; then
        print_fail "grpcurl is not installed"
        print_info "Please install grpcurl: https://github.com/fullstorydev/grpcurl"
        print_info "On Ubuntu/Debian: apt-get install grpcurl"
        print_info "On macOS: brew install grpcurl"
        return 1
    else
        print_pass "grpcurl is available"
        return 0
    fi
}

# Function to verify the prerequisites are met
check_prerequisites() {
    print_test_header "0. Checking Prerequisites"
    
    # Check grpcurl availability
    check_grpcurl
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Check if Dapr gRPC is running
    if ! nc -z localhost $DAPR_GRPC_PORT 2>/dev/null; then
        print_fail "Dapr gRPC is not running on localhost:$DAPR_GRPC_PORT"
        print_info "Please start the Dapr component with: ./run_docker_pluggable.sh start"
        return 1
    else
        print_pass "Dapr gRPC runtime is accessible on localhost:$DAPR_GRPC_PORT"
    fi
    
    # Verify the space and schema exist
    verify_result=$(docker run --rm --network nebula-net vesoft/nebula-console:v3-nightly \
        --addr nebula-graphd --port 9669 --user root --password nebula \
        --eval "USE dapr_state; SHOW TAGS;" 2>&1)
    
    if echo "$verify_result" | grep -q "state"; then
        print_pass "NebulaGraph dapr_state space and schema are ready"
        return 0
    else
        print_fail "NebulaGraph dapr_state space or schema not found"
        print_info "Please run the initialization script: cd ../dependencies && ./environment_setup.sh init"
        return 1
    fi
}

# Function to test gRPC service reflection
test_grpc_reflection() {
    print_test_header "1. Testing gRPC Service Reflection"
    
    services=$(grpcurl -plaintext -H "dapr-app-id: nebulagraph-test" localhost:$DAPR_GRPC_PORT list 2>/dev/null)
    
    if echo "$services" | grep -q "dapr.proto.runtime"; then
        print_pass "Dapr gRPC services are available"
        print_info "Available services: $(echo "$services" | tr '\n' ' ')"
    else
        print_fail "Dapr gRPC services not found"
        print_info "Response: $services"
    fi
}

# Test 2: gRPC SET operation
test_grpc_set() {
    print_test_header "2. Testing gRPC SET Operation"
    
    # Create JSON for gRPC SaveState request (correct method name)
    set_request='{
        "storeName": "'$COMPONENT_NAME'",
        "states": [
            {
                "key": "grpc-test-key-1",
                "value": "SGVsbG8gZ1JQQyBOZWJ1bGFHcmFwaCE=",
                "metadata": {}
            },
            {
                "key": "grpc-test-key-2", 
                "value": "eyJtZXNzYWdlIjogIlRoaXMgaXMgYSBnUlBDIEpTT04gdmFsdWUiLCAidGltZXN0YW1wIjogIjIwMjUtMDgtMDMifQ==",
                "metadata": {}
            }
        ]
    }'
    
    set_response=$(grpcurl -plaintext \
        -H "dapr-app-id: nebulagraph-test" \
        -d "$set_request" \
        localhost:$DAPR_GRPC_PORT \
        dapr.proto.runtime.v1.Dapr/SaveState 2>&1)
    set_exit_code=$?
    
    if [ $set_exit_code -eq 0 ]; then
        print_pass "gRPC SET operation successful"
    else
        print_fail "gRPC SET operation failed"
        print_info "Response: $set_response"
        print_info "Exit code: $set_exit_code"
    fi
}

# Test 3: gRPC GET operation
test_grpc_get() {
    print_test_header "3. Testing gRPC GET Operation"
    
    get_request='{
        "storeName": "'$COMPONENT_NAME'",
        "key": "grpc-test-key-1"
    }'
    
    get_response=$(grpcurl -plaintext \
        -H "dapr-app-id: nebulagraph-test" \
        -d "$get_request" \
        localhost:$DAPR_GRPC_PORT \
        dapr.proto.runtime.v1.Dapr/GetState 2>&1)
    
    if [ $? -eq 0 ] && echo "$get_response" | grep -q "data"; then
        print_pass "gRPC GET operation successful"
        # Decode base64 value to verify content
        encoded_value=$(echo "$get_response" | jq -r '.data' 2>/dev/null || echo "")
        if [ -n "$encoded_value" ]; then
            decoded_value=$(echo "$encoded_value" | base64 -d 2>/dev/null || echo "")
            print_info "Retrieved: $decoded_value"
        fi
    else
        print_fail "gRPC GET operation failed"
        print_info "Response: $get_response"
    fi
}

# Test 4: gRPC BULK GET operation
test_grpc_bulk_get() {
    print_test_header "4. Testing gRPC BULK GET Operation"
    
    bulk_request='{
        "storeName": "'$COMPONENT_NAME'",
        "keys": ["grpc-test-key-1", "grpc-test-key-2"]
    }'
    
    bulk_response=$(grpcurl -plaintext \
        -H "dapr-app-id: nebulagraph-test" \
        -d "$bulk_request" \
        localhost:$DAPR_GRPC_PORT \
        dapr.proto.runtime.v1.Dapr/GetBulkState 2>&1)
    
    if [ $? -eq 0 ] && echo "$bulk_response" | grep -q "items"; then
        print_pass "gRPC BULK GET operation successful"
        item_count=$(echo "$bulk_response" | jq '.items | length' 2>/dev/null || echo "0")
        print_info "Retrieved $item_count items"
    else
        print_fail "gRPC BULK GET operation failed"
        print_info "Response: $bulk_response"
    fi
}

# Test 5: gRPC DELETE operation
test_grpc_delete() {
    print_test_header "5. Testing gRPC DELETE Operation"
    
    delete_request='{
        "storeName": "'$COMPONENT_NAME'",
        "key": "grpc-test-key-1"
    }'
    
    delete_response=$(grpcurl -plaintext \
        -H "dapr-app-id: nebulagraph-test" \
        -d "$delete_request" \
        localhost:$DAPR_GRPC_PORT \
        dapr.proto.runtime.v1.Dapr/DeleteState 2>&1)
    delete_exit_code=$?
    
    if [ $delete_exit_code -eq 0 ]; then
        print_pass "gRPC DELETE operation successful"
    else
        print_fail "gRPC DELETE operation failed"
        print_info "Response: $delete_response"
        print_info "Exit code: $delete_exit_code"
    fi
}

# Test 6: Verify deletion via gRPC
test_grpc_verify_deletion() {
    print_test_header "6. Verifying Deletion via gRPC"
    
    verify_request='{
        "storeName": "'$COMPONENT_NAME'",
        "key": "grpc-test-key-1"
    }'
    
    verify_response=$(grpcurl -plaintext \
        -H "dapr-app-id: nebulagraph-test" \
        -d "$verify_request" \
        localhost:$DAPR_GRPC_PORT \
        dapr.proto.runtime.v1.Dapr/GetState 2>&1)
    
    if [ $? -eq 0 ] && (echo "$verify_response" | grep -q '"data": ""' || echo "$verify_response" | grep -q '"data": null' || ! echo "$verify_response" | grep -q "data"); then
        print_pass "Deletion verified via gRPC - key no longer exists"
    else
        print_fail "Deletion verification failed via gRPC - key still exists"
        print_info "Response: $verify_response"
    fi
}

# Test 7: Cleanup remaining test data
test_grpc_cleanup() {
    print_test_header "7. Cleanup via gRPC"
    
    cleanup_request='{
        "storeName": "'$COMPONENT_NAME'",
        "key": "grpc-test-key-2"
    }'
    
    cleanup_response=$(grpcurl -plaintext \
        -H "dapr-app-id: nebulagraph-test" \
        -d "$cleanup_request" \
        localhost:$DAPR_GRPC_PORT \
        dapr.proto.runtime.v1.Dapr/DeleteState 2>&1)
    cleanup_exit_code=$?
    
    if [ $cleanup_exit_code -eq 0 ]; then
        print_pass "Cleanup successful via gRPC - removed grpc-test-key-2"
    else
        print_fail "Cleanup failed for grpc-test-key-2 via gRPC"
        print_info "Response: $cleanup_response"
        print_info "Exit code: $cleanup_exit_code"
    fi
}

# Test 8: Cross-protocol compatibility test
test_cross_protocol() {
    print_test_header "8. Testing Cross-Protocol Compatibility"
    
    # Set data via gRPC
    cross_set_request='{
        "storeName": "'$COMPONENT_NAME'",
        "states": [
            {
                "key": "cross-protocol-test",
                "value": "Q3Jvc3MtcHJvdG9jb2wgdGVzdCBkYXRh",
                "metadata": {}
            }
        ]
    }'
    
    grpcurl -plaintext \
        -H "dapr-app-id: nebulagraph-test" \
        -d "$cross_set_request" \
        localhost:$DAPR_GRPC_PORT \
        dapr.proto.runtime.v1.Dapr/SaveState >/dev/null 2>&1
    
    # Retrieve via HTTP
    http_response=$(curl -s "http://localhost:3501/v1.0/state/$COMPONENT_NAME/cross-protocol-test")
    
    if echo "$http_response" | grep -q "Cross-protocol test data"; then
        print_pass "Cross-protocol compatibility verified (gRPC SET → HTTP GET)"
    else
        print_fail "Cross-protocol compatibility failed"
        print_info "HTTP response: $http_response"
    fi
    
    # Clean up cross-protocol test data
    curl -s -X DELETE "http://localhost:3501/v1.0/state/$COMPONENT_NAME/cross-protocol-test" >/dev/null 2>&1
}

# Check prerequisites first
check_prerequisites
if [ $? -ne 0 ]; then
    print_summary
    exit 1
fi

# Run all gRPC tests
test_grpc_reflection
test_grpc_set
test_grpc_get
test_grpc_bulk_get
test_grpc_delete
test_grpc_verify_deletion
test_grpc_cleanup
test_cross_protocol

# Print final summary
print_summary
exit $?
