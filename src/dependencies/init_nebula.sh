#!/bin/bash

# Load environment configuration if available
if [ -f "../.env" ]; then
    source ../.env
fi

# Set default values if not already set
NEBULA_NETWORK_NAME=${NEBULA_NETWORK_NAME:-nebula-net}
NEBULA_PORT=${NEBULA_PORT:-9669}
NEBULA_STORAGE_PORT=${NEBULA_STORAGE_PORT:-9779}
NEBULA_USERNAME=${NEBULA_USERNAME:-root}
NEBULA_PASSWORD=${NEBULA_PASSWORD:-nebula}
NEBULA_SPACE=${NEBULA_SPACE:-dapr_state}

# Initialize NebulaGraph cluster for single-node setup
echo "Initializing NebulaGraph cluster..."
echo "Configuration:"
echo "  • Network: $NEBULA_NETWORK_NAME"
echo "  • Graph Port: $NEBULA_PORT"
echo "  • Storage Port: $NEBULA_STORAGE_PORT"
echo "  • Space: $NEBULA_SPACE"
echo ""

# Wait for services to be fully ready
echo "Waiting for NebulaGraph services to initialize..."
sleep 15

# Add storage hosts to the cluster
echo "Registering storage hosts..."
docker run --rm --network $NEBULA_NETWORK_NAME vesoft/nebula-console:v3-nightly \
  --addr nebula-graphd --port $NEBULA_PORT --user $NEBULA_USERNAME --password $NEBULA_PASSWORD \
  --eval "ADD HOSTS \"nebula-storaged\":$NEBULA_STORAGE_PORT;"

echo "Waiting for hosts to be registered..."
sleep 5

# Check hosts status
echo "Checking hosts status..."
docker run --rm --network $NEBULA_NETWORK_NAME vesoft/nebula-console:v3-nightly \
  --addr nebula-graphd --port $NEBULA_PORT --user $NEBULA_USERNAME --password $NEBULA_PASSWORD \
  --eval "SHOW HOSTS;"

echo "Creating $NEBULA_SPACE space for Dapr components..."
docker run --rm --network $NEBULA_NETWORK_NAME vesoft/nebula-console:v3-nightly \
  --addr nebula-graphd --port $NEBULA_PORT --user $NEBULA_USERNAME --password $NEBULA_PASSWORD \
  --eval "CREATE SPACE IF NOT EXISTS $NEBULA_SPACE(partition_num=1, replica_factor=1, vid_type=FIXED_STRING(256));"

echo "Waiting for space to be ready..."
sleep 5

echo "Creating schema for Dapr state store..."
docker run --rm --network $NEBULA_NETWORK_NAME vesoft/nebula-console:v3-nightly \
  --addr nebula-graphd --port $NEBULA_PORT --user $NEBULA_USERNAME --password $NEBULA_PASSWORD \
  --eval "USE $NEBULA_SPACE; CREATE TAG IF NOT EXISTS state(data string);"

echo "Waiting for schema to be applied..."
sleep 5

echo "Verifying $NEBULA_SPACE space and schema creation..."
docker run --rm --network $NEBULA_NETWORK_NAME vesoft/nebula-console:v3-nightly \
  --addr nebula-graphd --port $NEBULA_PORT --user $NEBULA_USERNAME --password $NEBULA_PASSWORD \
  --eval "SHOW SPACES;"

echo "Verifying schema..."
docker run --rm --network $NEBULA_NETWORK_NAME vesoft/nebula-console:v3-nightly \
  --addr nebula-graphd --port $NEBULA_PORT --user $NEBULA_USERNAME --password $NEBULA_PASSWORD \
  --eval "USE $NEBULA_SPACE; SHOW TAGS;"

echo "NebulaGraph cluster initialization completed!"
