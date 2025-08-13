# ScyllaDB Component Tests

Comprehensive test suite for ScyllaDB state store component.

## Test Scripts

- `test_http.sh` - HTTP API testing (CRUD, bulk operations, ETags)
- `test_grpc.sh` - gRPC API testing (all operations, performance)  
- `test_scylladb.sh` - Comprehensive test runner

## Features Tested

### Core Operations
- **CRUD**: Get, Set, Delete operations
- **Bulk Operations**: Multi-key get/set/delete
- **ETags**: Optimistic concurrency control
- **Query API**: Advanced querying capabilities

### ScyllaDB-Specific
- **Consistency Levels**: LOCAL_QUORUM, ONE, ALL
- **Performance**: Latency and throughput testing
- **Data Patterns**: Time-series and wide-row patterns
- **Error Handling**: Timeout and connection errors

## Running Tests

```bash
# Individual tests
./test_http.sh
./test_grpc.sh

# Comprehensive suite
./test_scylladb.sh

# From parent directory
cd ../../ && ./tests/test_all.sh
```

### HTTP Interface (`test_http.sh`)
✅ **Core Functionality**:
- Basic CRUD operations with ScyllaDB-specific data patterns
- ETag support for optimistic concurrency control
- JSON and string data persistence

✅ **Bulk Operations**:
- Optimized bulk SET operations (6 items test)
- Bulk GET with multiple keys
- Bulk DELETE with verification

✅ **Performance Testing**:
- Sequential write performance (10 operations)
- Sequential read performance (10 operations)
- Performance benchmarking with timing

✅ **gRPC Interface (`test_grpc.sh`)**:
- Basic CRUD operations with ScyllaDB-specific key prefixes
- ETag and optimistic concurrency control
- Base64 encoding/decoding for gRPC protocol
- JSON and string data persistence
- Cross-protocol compatibility (gRPC SET → HTTP GET)

✅ **Bulk Operations (gRPC)**:
- Optimized bulk SET operations (3 items test)
- Bulk GET with multiple keys via gRPC
- Bulk DELETE with verification
- ScyllaDB consistency level testing

✅ **Performance Testing (gRPC)**:
- Query API performance benchmarking
- Cross-protocol operation timing
- gRPC-specific performance validation

✅ **ScyllaDB-Specific Features (gRPC)**:
- LOCAL_QUORUM consistency in test data
- ScyllaDB-specific JSON metadata
- Component connectivity validation
- Token-aware connectivity testing (implicit)

## Running Tests

### From the main component directory:
```bash
# Run ScyllaDB HTTP tests only
cd /home/sen/repos/nebulagraph/src/dapr-pluggable-components/stores/scylladb/tests
./test_http.sh

# Run all tests (once implemented)
cd /home/sen/repos/nebulagraph/src/dapr-pluggable-components/tests
./test_all.sh    # Will include both NebulaGraph and ScyllaDB tests
```

## Prerequisites

1. **ScyllaDB Cluster**: ScyllaDB must be running and accessible
   ```bash
   # Check ScyllaDB status
   docker ps | grep scylladb
   docker logs scylladb-node1  # Check if running properly
   ```

2. **Component Configuration**: Dapr component must be configured for ScyllaDB
   ```bash
   # Verify component registration
   cd /home/sen/repos/nebulagraph/src/dapr-pluggable-components
   # Check secrets in ../secrets/secrets.json
   # Check component config in ../components/scylladb-state.yaml
   ```

3. **Dapr Sidecar**: Dapr must be running with ScyllaDB component
   ```bash
   # Start component with ScyllaDB support
   STORE_TYPE=scylladb ./run_nebula.sh start
   ```

## ScyllaDB Configuration

The tests use the following ScyllaDB configuration:
- **Host**: `scylladb-node1` (via Docker network)
- **Port**: `9042` (default Cassandra/ScyllaDB port)
- **Keyspace**: `dapr_state` (auto-created)
- **Table**: `state` (auto-created)
- **Consistency**: `LOCAL_QUORUM` (optimal for single-datacenter)
- **Replication**: `SimpleStrategy` with factor 3

## Expected Results

When HTTP tests pass:
- ✅ All CRUD operations work correctly with ScyllaDB
- ✅ ETag support functions for optimistic concurrency
- ✅ Bulk operations handle multiple keys efficiently
- ✅ Performance metrics meet acceptable thresholds:
  - Write performance: <2s for 10 operations
  - Read performance: <1s for 10 operations
- ✅ Data persistence is reliable across operations
- ✅ ScyllaDB-specific optimizations are working

## Troubleshooting

If tests fail, check:

1. **ScyllaDB Status**:
   ```bash
   docker ps | grep scylladb
   docker logs scylladb-node1
   ```

2. **Network Connectivity**:
   ```bash
   docker network ls | grep scylladb
   docker exec -it scylladb-node1 nodetool status
   ```

3. **Component Configuration**:
   ```bash
   # Check component config
   cat ../../../components/scylladb-state.yaml
   
   # Check secrets
   cat ../../../secrets/secrets.json | grep -A 15 scylladb
   ```

4. **Dapr Sidecar**:
   ```bash
   # Check if Dapr is running with correct component
   curl -s http://localhost:3501/v1.0/healthz
   
   # Check component logs
   ./run_nebula.sh logs
   ```

5. **Database Initialization**:
   ```bash
   # Connect to ScyllaDB and verify keyspace
   docker exec -it scylladb-node1 cqlsh -e "DESCRIBE KEYSPACES;"
   docker exec -it scylladb-node1 cqlsh -e "USE dapr_state; DESCRIBE TABLES;"
   ```

## Performance Characteristics

ScyllaDB tests include specific performance validations:
- **Write Latency**: Individual writes should complete in <200ms
- **Read Latency**: Individual reads should complete in <100ms
- **Bulk Operations**: Should efficiently handle 6+ items per operation
- **Sequential Operations**: 10 operations should complete in <2s total

These thresholds are based on ScyllaDB's high-performance characteristics and may be adjusted based on hardware and network conditions.
