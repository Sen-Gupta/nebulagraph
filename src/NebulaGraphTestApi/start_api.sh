#!/bin/bash

# Start NebulaGraph Test API with Dapr
echo "Starting NebulaGraph Test API with Dapr..."

# Check if Dapr runtime is running
if ! pgrep -f "dapr" > /dev/null; then
    echo "Dapr runtime is not running. Please start it with: dapr init"
    exit 1
fi

# Build the application
echo "Building the application..."
~/.dotnet/dotnet build

if [ $? -ne 0 ]; then
    echo "Build failed. Please fix the errors and try again."
    exit 1
fi

# Start the application with Dapr
echo "Starting the application with Dapr..."
dapr run \
    --app-id nebulagraph-test-api \
    --app-port 5000 \
    --dapr-http-port 3500 \
    --dapr-grpc-port 50001 \
    --components-path ./dapr \
    --app-protocol http \
    -- ~/.dotnet/dotnet run --urls="http://localhost:5000"
