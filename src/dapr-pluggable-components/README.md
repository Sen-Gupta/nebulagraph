# Dapr Pluggable Components

Multi-backend state store components implemented in Go supporting NebulaGraph and ScyllaDB.

## Features

- **Multi-Store Support**: Single binary serves both NebulaGraph and ScyllaDB backends
- **Environment-Driven**: `STORE_TYPE` variable selects backend (nebulagraph|scylladb)
- **Full Dapr Compatibility**: Implements complete state store interface
- **Docker Ready**: Containerized deployment with Docker Compose
- **Production Ready**: Health checks, metrics, and error handling

## Quick Start

```bash
# Start infrastructure
cd ../dependencies && ./environment_setup.sh start

# Run both components
./run_dapr_pluggables.sh start

# Test functionality  
./tests/test_all.sh
```

## Implementation

### Component Types

| Environment Variable | Backend | Port | Database |
|---------------------|---------|------|----------|
| `STORE_TYPE=nebulagraph` | NebulaGraph | 9669 | Graph database |
| `STORE_TYPE=scylladb` | ScyllaDB | 9042 | Wide-column store |

### State Store Operations

- **Get/Set/Delete**: Standard CRUD operations
- **Bulk Operations**: Multi-key get/set for performance
- **Transactions**: Multi-operation consistency (where supported)
- **ETags**: Optimistic concurrency control

## Management Commands

```bash
./run_dapr_pluggables.sh start     # Start both components
./run_dapr_pluggables.sh stop      # Stop all services
./run_dapr_pluggables.sh status    # Check component status
./run_dapr_pluggables.sh logs      # View component logs
./run_dapr_pluggables.sh test-basic # Run basic functionality tests
```

## Testing

```bash
# Comprehensive test suite
./tests/test_all.sh

# Individual component tests
./stores/nebulagraph/tests/test_nebulagraph.sh
./stores/scylladb/tests/test_scylladb.sh
```  
  scylladb-component:
    build: .
    environment:
      - DAPR_COMPONENT_SOCKETS_FOLDER=/var/run
      - STORE_TYPE=scylladb
    volumes:
      - socket:/var/run
```

### Component Registration

Each component type registers with Dapr using different component YAML files:

- **NebulaGraph**: Uses `nebulagraph-state.yaml` component configuration
- **ScyllaDB**: Uses `scylladb-state.yaml` component configuration

Both components can run simultaneously in the same Dapr sidecar, providing dual state store capabilities.

### Environment Variables

| Variable | Required | Values | Description |
|----------|----------|---------|-------------|
| `STORE_TYPE` | Yes | `nebulagraph`, `scylladb` | Determines which component type to initialize |
| `DAPR_COMPONENT_SOCKETS_FOLDER` | Yes | `/var/run` | Socket directory for Dapr communication |

### Component Behavior by STORE_TYPE

- **nebulagraph**: Initializes NebulaGraph client and state store implementation
- **scylladb**: Initializes ScyllaDB client and state store implementation

The same Go binary contains both implementations and selects the appropriate one based on the `STORE_TYPE` environment variable at startup.

## Testing
```

## Features

- **Dual Component Support**: Single binary serves both NebulaGraph and ScyllaDB components
- **State Operations**: Get, Set, Delete, List with prefix filtering
- **gRPC Interface**: Full Dapr state store protocol support
- **Automatic Schema**: Creates required NebulaGraph spaces and schemas
- **Docker Integration**: Complete containerized deployment
- **Environment-Based Configuration**: Component type selection via STORE_TYPE variable

## Testing

```bash
cd tests
./test_all.sh           # Complete test suite
./test_http.sh     # HTTP API tests
./test_grpc.sh # gRPC tests
```

## Development

Build locally:
```bash
go build -o nebulagraph ./main.go
```

The component implements the Dapr pluggable state store interface and connects to NebulaGraph via the native Go client.

## Integration Examples

### .NET Example with Dual Components

The `../examples/NebulaGraphNetExample` demonstrates using both state store components simultaneously:

```bash
cd ../examples/NebulaGraphNetExample
./test_nebula_net.sh start
```

The .NET example `docker-compose.yml` shows dual component configuration:

```yaml
nebulagraph-net-component:
  environment:
    - STORE_TYPE=nebulagraph

scylladb-net-component:
  environment:
    - STORE_TYPE=scylladb
```

This enables the .NET application to use both NebulaGraph and ScyllaDB state stores through different Dapr component names while using the same underlying Docker image.

## Management Scripts

- `./run_dapr_pluggables.sh start` - Deploy dual components
- `./run_dapr_pluggables.sh status` - Check status
- `./run_dapr_pluggables.sh stop` - Stop components
- `./run_dapr_pluggables.sh clean` - Clean reset
