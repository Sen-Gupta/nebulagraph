#!/bin/bash

# Initialize NebulaGraph cluster for single-node setup
echo "Initializing NebulaGraph cluster..."

# Wait for services to be fully ready
echo "Waiting for NebulaGraph services to initialize..."
sleep 15

# Add storage hosts to the cluster
echo "Registering storage hosts..."
docker run --rm --network nebula-net vesoft/nebula-console:v3-nightly \
  --addr nebula-graphd --port 9669 --user root --password nebula \
  --eval "ADD HOSTS \"nebula-storaged\":9779;"

echo "Waiting for hosts to be registered..."
sleep 5

# Check hosts status
echo "Checking hosts status..."
docker run --rm --network nebula-net vesoft/nebula-console:v3-nightly \
  --addr nebula-graphd --port 9669 --user root --password nebula \
  --eval "SHOW HOSTS;"

echo "Creating dapr_state space for Dapr components..."
docker run --rm --network nebula-net vesoft/nebula-console:v3-nightly \
  --addr nebula-graphd --port 9669 --user root --password nebula \
  --eval "CREATE SPACE IF NOT EXISTS dapr_state(partition_num=1, replica_factor=1, vid_type=FIXED_STRING(256));"

echo "Waiting for space to be ready..."
sleep 5

echo "Creating schema for Dapr state store..."
docker run --rm --network nebula-net vesoft/nebula-console:v3-nightly \
  --addr nebula-graphd --port 9669 --user root --password nebula \
  --eval "USE dapr_state; CREATE TAG IF NOT EXISTS state(data string);"

echo "Waiting for schema to be applied..."
sleep 5

echo "Verifying dapr_state space and schema creation..."
docker run --rm --network nebula-net vesoft/nebula-console:v3-nightly \
  --addr nebula-graphd --port 9669 --user root --password nebula \
  --eval "SHOW SPACES;"

echo "Verifying schema..."
docker run --rm --network nebula-net vesoft/nebula-console:v3-nightly \
  --addr nebula-graphd --port 9669 --user root --password nebula \
  --eval "USE dapr_state; SHOW TAGS;"

echo "NebulaGraph cluster initialization completed!"
