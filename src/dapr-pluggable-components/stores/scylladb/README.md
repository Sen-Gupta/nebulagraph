# ScyllaDB State Store

Production-ready ScyllaDB implementation for Dapr state store using shard-aware GoCQL driver.

## Features

- **Full Dapr Interface**: Complete state store operations (CRUD, bulk, query)
- **ScyllaDB Optimized**: Shard-aware driver, automatic schema management
- **Production Ready**: Connection pooling, retry logic, configurable consistency

## Implementation Details

### Database Schema
```sql
CREATE KEYSPACE dapr_state 
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

CREATE TABLE state (
    key text PRIMARY KEY,
    value text,
    etag text,
    last_modified timestamp
);
```

### Configuration
Set via environment variable: `STORE_TYPE=scylladb`

Component metadata (from `scylladb-state.yaml`):
- `hosts` - ScyllaDB cluster nodes
- `port` - CQL port (default: 9042)  
- `username` - Database username
- `password` - Database password
- `keyspace` - Keyspace name
- `consistency` - Consistency level

### Performance Optimizations
- **Shard-aware routing** for optimal performance
- **Connection pooling** with configurable limits
- **Prepared statements** for repeated queries
- **Batch operations** for bulk updates
- **Configurable timeouts** for operations

## Testing

```bash
# Component-specific tests
./tests/test_http.sh
./tests/test_grpc.sh
./tests/test_scylladb.sh
```

```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: scylladb-state
spec:
  type: state.scylladb-state
  version: v1
  metadata:
  # Required
  - name: hosts
    value: "localhost"                    # Comma-separated list of ScyllaDB hosts
  - name: keyspace
    value: "dapr_state"                   # Keyspace name
  
  # Optional
  - name: port
    value: "9042"                         # Default: 9042
  - name: username
    value: ""                             # Username for authentication
  - name: password
    value: ""                             # Password for authentication
  - name: table
    value: "state"                        # Table name (default: state)
  - name: consistency
    value: "LOCAL_QUORUM"                 # Consistency level
  - name: connectionTimeout
    value: "10s"                          # Connection timeout
  - name: socketKeepalive
    value: "30s"                          # Socket keepalive
  - name: maxReconnectInterval
    value: "60s"                          # Max reconnect interval
  - name: numConns
    value: "2"                            # Connections per host
  - name: disableInitialHostLookup
    value: "false"                        # Disable host discovery
  - name: replicationStrategy
    value: "SimpleStrategy"               # For keyspace creation
  - name: replicationFactor
    value: "3"                            # Replication factor
```

### Environment Configuration

Set the store type to use ScyllaDB:

```bash
export STORE_TYPE=scylladb
```

## Usage

### 1. Using with Dapr HTTP API

```bash
# Set a value
curl -X POST http://localhost:3500/v1.0/state/scylladb-state \
  -H "Content-Type: application/json" \
  -d '[{"key": "mykey", "value": "myvalue"}]'

# Get a value
curl http://localhost:3500/v1.0/state/scylladb-state/mykey

# Delete a value
curl -X DELETE http://localhost:3500/v1.0/state/scylladb-state/mykey
```

### 2. Using Query Interface for DDL/DML

The ScyllaDB state store supports the Dapr query interface for executing arbitrary CQL statements:

```bash
# Create a new table
curl -X POST http://localhost:3500/v1.0/state/scylladb-state/query \
  -H "Content-Type: application/json" \
  -d '{
    "query": "CREATE TABLE IF NOT EXISTS user_profiles (user_id text PRIMARY KEY, profile_data text)"
  }'

# Create a new keyspace
curl -X POST http://localhost:3500/v1.0/state/scylladb-state/query \
  -H "Content-Type: application/json" \
  -d '{
    "query": "CREATE KEYSPACE IF NOT EXISTS analytics WITH replication = {\"class\": \"SimpleStrategy\", \"replication_factor\": 3}"
  }'

# Query data
curl -X POST http://localhost:3500/v1.0/state/scylladb-state/query \
  -H "Content-Type: application/json" \
  -d '{
    "query": "SELECT key, value FROM state WHERE key IN (\"key1\", \"key2\")"
  }'
```

### 3. Using with Dapr SDK

```go
// .NET example
await daprClient.SaveStateAsync("scylladb-state", "mykey", myValue);
var value = await daprClient.GetStateAsync<MyType>("scylladb-state", "mykey");
await daprClient.DeleteStateAsync("scylladb-state", "mykey");

// Execute CQL query
var queryResponse = await daprClient.QueryStateAsync("scylladb-state", 
    "SELECT key, value FROM state LIMIT 10");
```

## Schema

The state store automatically creates the following schema:

### Keyspace
```sql
CREATE KEYSPACE IF NOT EXISTS dapr_state 
WITH replication = {
  'class': 'SimpleStrategy', 
  'replication_factor': 3
};
```

### Table
```sql
CREATE TABLE IF NOT EXISTS state (
  key text PRIMARY KEY,
  value text,
  etag text,
  last_modified timestamp
);
```

## Consistency Levels

Supported consistency levels:
- `ANY`
- `ONE`
- `TWO` 
- `THREE`
- `QUORUM`
- `ALL`
- `LOCAL_QUORUM` (default)
- `EACH_QUORUM`
- `LOCAL_ONE`

## Performance Considerations

1. **Connection Pooling**: Configure `numConns` based on your workload
2. **Consistency**: Use `LOCAL_QUORUM` for good balance of consistency and performance
3. **Batch Operations**: Use bulk operations for better throughput
4. **Keyspace Strategy**: Use `NetworkTopologyStrategy` for multi-datacenter deployments

## Testing

The ScyllaDB state store is tested through integration tests that validate the complete Dapr pluggable component stack:

```bash
# Run comprehensive integration tests (HTTP + gRPC)
cd ../tests
./test_all.sh

# Test ScyllaDB component specifically with STORE_TYPE
cd ..
STORE_TYPE=scylladb ./run_dapr_pluggables.sh test

# Run .NET application integration tests
cd ../examples/NebulaGraphNetExample
./test_nebula_net.sh
```

## Troubleshooting

### Common Issues

1. **Connection Failed**: Check if ScyllaDB is running and accessible
   ```bash
   docker-compose -f ../dependencies/scylladb/docker-compose.yml up -d
   ```

2. **Keyspace Creation Failed**: Ensure proper replication settings for your cluster
3. **Authentication Failed**: Verify username/password configuration
4. **Timeout Issues**: Increase `connectionTimeout` for slow networks

### Debug Logging

Enable debug logging by setting the log level:
```bash
export DAPR_LOG_LEVEL=debug
```

## Dependencies

- **ScyllaDB GoCQL Driver**: Uses `github.com/scylladb/gocql` (latest shard-aware version)
- **Dapr Components SDK**: Compatible with Dapr v1.11+
- **Go Version**: Requires Go 1.21+

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Dapr Runtime  │    │   ScyllaDB       │    │   ScyllaDB      │
│                 │────│   State Store    │────│   Cluster       │
│   HTTP/gRPC     │    │   Component      │    │   (CQL)         │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

The ScyllaDB state store implements the Dapr state store interface and translates Dapr operations into CQL queries optimized for ScyllaDB's architecture.
