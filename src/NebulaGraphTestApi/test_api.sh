#!/bin/bash

# Test script for NebulaGraph Dapr component via .NET API
BASE_URL="http://localhost:5000"
DAPR_URL="http://localhost:3500"

echo "=== Testing NebulaGraph Dapr Component via .NET API ==="
echo

# Function to test HTTP API
test_http_api() {
    echo "=== Testing HTTP API ==="
    
    # Test SET operation
    echo "1. Testing SET operation..."
    curl -X POST "${BASE_URL}/api/state/test-key" \
         -H "Content-Type: application/json" \
         -d '{"value":"test-value-123"}' \
         -w "\nStatus: %{http_code}\n\n"
    
    sleep 1
    
    # Test GET operation
    echo "2. Testing GET operation..."
    curl -X GET "${BASE_URL}/api/state/test-key" \
         -w "\nStatus: %{http_code}\n\n"
    
    sleep 1
    
    # Test SET another key
    echo "3. Testing SET another key..."
    curl -X POST "${BASE_URL}/api/state/user:123" \
         -H "Content-Type: application/json" \
         -d '{"value":"user-data-456"}' \
         -w "\nStatus: %{http_code}\n\n"
    
    sleep 1
    
    # Test LIST operation
    echo "4. Testing LIST operation..."
    curl -X GET "${BASE_URL}/api/state/list?prefix=test&limit=5" \
         -w "\nStatus: %{http_code}\n\n"
    
    sleep 1
    
    # Test BULK operations
    echo "5. Testing BULK operations..."
    curl -X POST "${BASE_URL}/api/state/bulk" \
         -H "Content-Type: application/json" \
         -d '{
             "operations": [
                 {"key": "bulk1", "value": "value1", "operation": "set"},
                 {"key": "bulk2", "value": "value2", "operation": "set"},
                 {"key": "bulk3", "value": "value3", "operation": "set"}
             ]
         }' \
         -w "\nStatus: %{http_code}\n\n"
    
    sleep 1
    
    # Test DELETE operation
    echo "6. Testing DELETE operation..."
    curl -X DELETE "${BASE_URL}/api/state/test-key" \
         -w "\nStatus: %{http_code}\n\n"
    
    sleep 1
    
    # Test GET deleted key
    echo "7. Testing GET deleted key..."
    curl -X GET "${BASE_URL}/api/state/test-key" \
         -w "\nStatus: %{http_code}\n\n"
}

# Function to test Dapr API directly
test_dapr_api() {
    echo "=== Testing Dapr API Directly ==="
    
    # Test SET via Dapr
    echo "1. Testing SET via Dapr..."
    curl -X POST "${DAPR_URL}/v1.0/state/nebulagraph-store" \
         -H "Content-Type: application/json" \
         -d '[{"key":"dapr-test", "value":"dapr-value-789"}]' \
         -w "\nStatus: %{http_code}\n\n"
    
    sleep 1
    
    # Test GET via Dapr
    echo "2. Testing GET via Dapr..."
    curl -X GET "${DAPR_URL}/v1.0/state/nebulagraph-store/dapr-test" \
         -w "\nStatus: %{http_code}\n\n"
    
    sleep 1
    
    # Test DELETE via Dapr
    echo "3. Testing DELETE via Dapr..."
    curl -X DELETE "${DAPR_URL}/v1.0/state/nebulagraph-store/dapr-test" \
         -w "\nStatus: %{http_code}\n\n"
}

# Check if API is running
echo "Checking if API is running..."
if ! curl -s "${BASE_URL}/swagger" > /dev/null; then
    echo "API is not running. Please start it with: ./start_api.sh"
    exit 1
fi

# Run tests
test_http_api
echo
test_dapr_api

echo
echo "=== Testing Complete ==="
echo "Visit ${BASE_URL}/swagger for interactive API documentation"
