#!/bin/bash

# ScyllaDB configuration - hardcoded values, no environment file needed
DAPR_PLUGABBLE_NETWORK_NAME=${DAPR_PLUGABBLE_NETWORK_NAME:-dapr-pluggable-net}
SCYLLA_CQL_PORT="9042"
SCYLLA_CLUSTER_NAME="dapr_cluster"
SCYLLA_KEYSPACE="dapr_state"
SCYLLA_DC="datacenter1"
SCYLLA_RACK="rack1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Initialize ScyllaDB cluster for Dapr state store
echo "Initializing ScyllaDB cluster for Dapr..."
echo "Configuration:"
echo "  • Network: $DAPR_PLUGABBLE_NETWORK_NAME"
echo "  • CQL Port: $SCYLLA_CQL_PORT"
echo "  • Cluster: $SCYLLA_CLUSTER_NAME"
echo "  • Keyspace: $SCYLLA_KEYSPACE"
echo "  • Datacenter: $SCYLLA_DC"
echo "  • Rack: $SCYLLA_RACK"
echo ""

# Wait for ScyllaDB to be fully ready
print_info "Waiting for ScyllaDB to initialize and be ready..."
sleep 30

# Check if ScyllaDB is responding
print_info "Testing ScyllaDB connectivity..."
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if docker exec scylladb-node1 cqlsh -e "SELECT now() FROM system.local;" >/dev/null 2>&1; then
        print_success "ScyllaDB is ready and responsive"
        break
    else
        attempt=$((attempt + 1))
        print_info "Waiting for ScyllaDB to be ready... (attempt $attempt/$max_attempts)"
        sleep 10
    fi
done

if [ $attempt -eq $max_attempts ]; then
    print_error "ScyllaDB failed to start within expected time"
    exit 1
fi

# Show cluster status
print_info "Checking cluster status..."
docker exec scylladb-node1 cqlsh -e "SELECT cluster_name, release_version FROM system.local;"

# Create keyspace for Dapr state store
print_info "Creating keyspace '$SCYLLA_KEYSPACE' for Dapr state store..."
docker exec scylladb-node1 cqlsh -e "
CREATE KEYSPACE IF NOT EXISTS $SCYLLA_KEYSPACE 
WITH REPLICATION = {
    'class': 'NetworkTopologyStrategy',
    '$SCYLLA_DC': 1
};"

print_info "Waiting for keyspace to be ready..."
sleep 5

# Create table for Dapr state store
print_info "Creating table for Dapr state store..."
docker exec scylladb-node1 cqlsh -e "
USE $SCYLLA_KEYSPACE;
CREATE TABLE IF NOT EXISTS state (
    key TEXT PRIMARY KEY,
    value TEXT,
    etag TEXT,
    last_modified TIMESTAMP
) WITH comment = 'Dapr state store table';"

# Create index on etag for optimistic concurrency
print_info "Creating index on etag for optimistic concurrency..."
docker exec scylladb-node1 cqlsh -e "
USE $SCYLLA_KEYSPACE;
CREATE INDEX IF NOT EXISTS state_etag_idx ON state (etag);"

print_info "Waiting for schema to be applied..."
sleep 5

# Verify keyspace and table creation
print_info "Verifying keyspace creation..."
docker exec scylladb-node1 cqlsh -e "DESCRIBE KEYSPACES;" | grep -q "$SCYLLA_KEYSPACE"
if [ $? -eq 0 ]; then
    print_success "Keyspace '$SCYLLA_KEYSPACE' created successfully"
else
    print_error "Failed to create keyspace '$SCYLLA_KEYSPACE'"
    exit 1
fi

print_info "Verifying table creation..."
docker exec scylladb-node1 cqlsh -e "USE $SCYLLA_KEYSPACE; DESCRIBE TABLES;"

# Show table schema
print_info "Table schema:"
docker exec scylladb-node1 cqlsh -e "USE $SCYLLA_KEYSPACE; DESCRIBE TABLE state;"

# Insert a test record to verify functionality
print_info "Testing insert functionality..."
docker exec scylladb-node1 cqlsh -e "
USE $SCYLLA_KEYSPACE;
INSERT INTO state (key, value, etag, last_modified) 
VALUES ('test_key', 'test_value', 'test_etag', toTimestamp(now()));"

# Test query functionality
print_info "Testing query functionality..."
docker exec scylladb-node1 cqlsh -e "
USE $SCYLLA_KEYSPACE;
SELECT * FROM state WHERE key = 'test_key';"

# Clean up test record
print_info "Cleaning up test record..."
docker exec scylladb-node1 cqlsh -e "
USE $SCYLLA_KEYSPACE;
DELETE FROM state WHERE key = 'test_key';"

# Show final cluster and keyspace status
print_info "Final cluster status:"
docker exec scylladb-node1 cqlsh -e "
SELECT cluster_name, data_center, rack, release_version, cql_version 
FROM system.local;"

print_info "Keyspace replication settings:"
docker exec scylladb-node1 cqlsh -e "
SELECT keyspace_name, replication 
FROM system_schema.keyspaces 
WHERE keyspace_name = '$SCYLLA_KEYSPACE';"

print_success "ScyllaDB cluster initialization completed successfully!"
print_info "ScyllaDB is ready for Dapr state store operations"
print_info "Connection details:"
print_info "  • Host: scylladb-node1 (or localhost from host)"
print_info "  • Port: $SCYLLA_CQL_PORT"
print_info "  • Keyspace: $SCYLLA_KEYSPACE"
print_info "  • Table: state"
print_info "  • Manager UI: http://localhost:5080 (if scylla-manager is running)"
