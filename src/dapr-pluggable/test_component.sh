#!/bin/bash

echo "Testing NebulaGraph Dapr State Store Component"
echo "=============================================="

# Base URL for Dapr HTTP API
DAPR_URL="http://localhost:3500/v1.0/state/nebulagraph-state"

# Function to check if dapr_state space exists and create it if needed
check_and_create_space() {
    echo "Checking if dapr_state space exists..."
    
    # Create the space and schema (this will be safe with IF NOT EXISTS)
    echo "Ensuring dapr_state space and schema exist..."
    docker run --rm --network nebula-net vesoft/nebula-console:v3-nightly \
        --addr nebula-graphd --port 9669 --user root --password nebula \
        --eval "CREATE SPACE IF NOT EXISTS dapr_state (vid_type=FIXED_STRING(256), partition_num=1, replica_factor=1); USE dapr_state; CREATE TAG IF NOT EXISTS state(data string);"
    
    # Wait a moment for schema to be applied
    echo "Waiting for schema to be applied..."
    sleep 20
    
    # Verify the space was created by trying to use it
    verify_result=$(docker run --rm --network nebula-net vesoft/nebula-console:v3-nightly \
        --addr nebula-graphd --port 9669 --user root --password nebula \
        --eval "USE dapr_state; SHOW TAGS;" 2>&1)
    
    if echo "$verify_result" | grep -q "state"; then
        echo "✅ dapr_state space and schema are ready"
        return 0
    else
        echo "❌ Failed to verify dapr_state space"
        echo "Verification output: $verify_result"
        return 1
    fi
}

echo ""
echo "0. Testing NebulaGraph Schema Setup..."
check_and_create_space
if [ $? -ne 0 ]; then
    echo "❌ Schema setup failed. Exiting tests."
    exit 1
fi

echo ""
echo "Restarting Dapr component to pick up schema changes..."
docker-compose restart > /dev/null 2>&1
sleep 10
echo "✅ Component restarted"

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
