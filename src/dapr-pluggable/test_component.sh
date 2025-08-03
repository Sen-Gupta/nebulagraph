#!/bin/bash

echo "Testing NebulaGraph Dapr State Store Component"
echo "=============================================="

# Base URL for Dapr HTTP API
DAPR_URL="http://localhost:3500/v1.0/state/nebulagraph-state"

# Function to verify the prerequisites are met
check_prerequisites() {
    echo "Checking prerequisites..."
    
    # Check if Dapr is running
    if ! curl -s http://localhost:3500/v1.0/healthz > /dev/null 2>&1; then
        echo "❌ Dapr is not running on localhost:3500"
        echo "Please start the Dapr component with: docker-compose up -d"
        return 1
    fi
    
    # Verify the space and schema exist
    verify_result=$(docker run --rm --network nebula-net vesoft/nebula-console:v3-nightly \
        --addr nebula-graphd --port 9669 --user root --password nebula \
        --eval "USE dapr_state; SHOW TAGS;" 2>&1)
    
    if echo "$verify_result" | grep -q "state"; then
        echo "✅ NebulaGraph dapr_state space and schema are ready"
        echo "✅ Dapr runtime is accessible"
        return 0
    else
        echo "❌ NebulaGraph dapr_state space or schema not found"
        echo "Please run the initialization script: cd ../dependencies && ./init_nebula.sh"
        echo "Verification output: $verify_result"
        return 1
    fi
}

echo ""
echo "0. Checking Prerequisites..."
check_prerequisites
if [ $? -ne 0 ]; then
    echo "❌ Prerequisites not met. Please check the setup."
    exit 1
fi

echo ""
echo "1. Testing SET operation..."
curl -X POST "$DAPR_URL" \
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
  ]'

echo ""
echo ""
echo "2. Testing GET operation for test-key-1..."
curl -X GET "$DAPR_URL/test-key-1"

echo ""
echo ""
echo "3. Testing GET operation for test-key-2..."
curl -X GET "$DAPR_URL/test-key-2"

echo ""
echo ""
echo "4. Testing BULK GET operation..."
curl -X POST "$DAPR_URL/bulk" \
  -H "Content-Type: application/json" \
  -d '{
    "keys": ["test-key-1", "test-key-2"]
  }'

echo ""
echo ""
echo "5. Testing DELETE operation..."
curl -X DELETE "$DAPR_URL/test-key-1"

echo ""
echo ""
echo "6. Verifying deletion - should return empty/error..."
curl -X GET "$DAPR_URL/test-key-1"

echo ""
echo ""
echo "Test completed!"
