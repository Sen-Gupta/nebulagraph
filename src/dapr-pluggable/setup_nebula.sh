#!/bin/bash

# Setup script for NebulaGraph schema required by Dapr state store

echo "Setting up NebulaGraph schema for Dapr state store..."

# Use a temporary container to run NebulaGraph console commands
docker run --rm --network nebula-net vesoft/nebula-console:v3-nightly \
  --addr nebula-graphd --port 9669 --user root --password nebula \
  --eval "CREATE SPACE IF NOT EXISTS dapr_state (vid_type=FIXED_STRING(256)); USE dapr_state; CREATE TAG IF NOT EXISTS state_data(value string, etag string, last_modified timestamp); CREATE EDGE IF NOT EXISTS state_key();"

echo "NebulaGraph schema setup completed!"
echo "The 'dapr_state' space is now ready for the Dapr component."
