#!/bin/bash

echo "Testing NebulaGraph Dapr State Store Component"
echo "=============================================="

# Base URL for Dapr HTTP API
DAPR_URL="http://localhost:3500/v1.0/state/nebulagraph-state"

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
