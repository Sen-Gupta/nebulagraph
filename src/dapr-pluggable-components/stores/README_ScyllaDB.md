# ScyllaDB State Store Implementation

This directory contains a production-ready ScyllaDB state store implementation for Dapr using the ScyllaDB-optimized GoCQL driver.

## Features

✅ **Full Dapr State Store Interface**
- Get, Set, Delete operations
- Bulk operations (BulkGet, BulkSet, BulkDelete)
- Query interface for arbitrary CQL execution
- ETag support for optimistic concurrency control

✅ **ScyllaDB Optimizations**
- Uses ScyllaDB's shard-aware GoCQL driver
- Automatic keyspace and table creation
- Configurable consistency levels
- Connection pooling and retry logic

✅ **Production Features**
- Comprehensive error handling
- Configurable timeouts and connection parameters
- Logging and debugging support
- Thread-safe operations

## Configuration

### Component Configuration

Create a component file (e.g., `scylladb-state.yaml`):

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

```bash
# Unit tests (requires running ScyllaDB)
go test ./stores -v

# Short tests (skip integration tests)
go test ./stores -v -short
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
