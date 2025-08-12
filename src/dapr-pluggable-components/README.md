# NebulaGraph Dapr Component

Dapr pluggable state store component using NebulaGraph as the backend.

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Dapr CLI 
- Go 1.24.5+

### Run the Component
```bash
# Start NebulaGraph infrastructure first
cd ../dependencies
./environment_setup.sh

# Run the dual components
cd ../dapr-pluggable-components
./run_dapr_pluggables.sh start

# Test all operations
./tests/test_all.sh
```

## Component Configuration

### STORE_TYPE Environment Variable

The same Docker image and Go binary can serve different component types by setting the `STORE_TYPE` environment variable:

- **STORE_TYPE=nebulagraph** - NebulaGraph state store component
- **STORE_TYPE=scylladb** - ScyllaDB state store component

### Docker Compose Configuration

The `docker-compose.yml` demonstrates dual component deployment:

```yaml
services:
  # NebulaGraph Component
  nebulagraph-component:
    build: .
    environment:
      - DAPR_COMPONENT_SOCKETS_FOLDER=/var/run
      - STORE_TYPE=nebulagraph
    volumes:
      - socket:/var/run

  # ScyllaDB Component  
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
./test_component.sh     # HTTP API tests
./test_component_grpc.sh # gRPC tests
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
