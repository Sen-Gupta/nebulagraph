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

echo "NebulaGraph cluster initialization completed!"
