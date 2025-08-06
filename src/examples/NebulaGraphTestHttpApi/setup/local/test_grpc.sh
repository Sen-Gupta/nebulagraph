#!/bin/bash

# gRPC Test script for NebulaGraph Dapr component
GRPC_URL="localhost:5000"

echo "=== Testing gRPC API ==="
echo "Note: This requires grpcurl to be installed"
echo "Install with: go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest"
echo

# Check if grpcurl is available
if ! command -v grpcurl &> /dev/null; then
    echo "grpcurl is not installed. Installing..."
    if command -v go &> /dev/null; then
        go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
        export PATH=$PATH:$(go env GOPATH)/bin
    else
        echo "Go is not installed. Please install grpcurl manually."
        exit 1
    fi
fi

# Test gRPC reflection (optional)
echo "1. Testing gRPC service reflection..."
grpcurl -plaintext ${GRPC_URL} list

echo
echo "2. Testing SetValue via gRPC..."
grpcurl -plaintext \
    -d '{"key": "grpc-test", "value": "grpc-value-123"}' \
    ${GRPC_URL} nebulagraph.NebulaGraphService/SetValue

echo
echo "3. Testing GetValue via gRPC..."
grpcurl -plaintext \
    -d '{"key": "grpc-test"}' \
    ${GRPC_URL} nebulagraph.NebulaGraphService/GetValue

echo
echo "4. Testing ListKeys via gRPC..."
grpcurl -plaintext \
    -d '{"prefix": "grpc", "limit": 5}' \
    ${GRPC_URL} nebulagraph.NebulaGraphService/ListKeys

echo
echo "5. Testing DeleteValue via gRPC..."
grpcurl -plaintext \
    -d '{"key": "grpc-test"}' \
    ${GRPC_URL} nebulagraph.NebulaGraphService/DeleteValue

echo
echo "6. Testing GetValue after delete via gRPC..."
grpcurl -plaintext \
    -d '{"key": "grpc-test"}' \
    ${GRPC_URL} nebulagraph.NebulaGraphService/GetValue

echo
echo "=== gRPC Testing Complete ==="
