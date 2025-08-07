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

# Run the component
cd ../dapr-pluggable-components
./run_docker_pluggable.sh start

# Test all operations
./tests/test_all.sh
```

## Features

- **State Operations**: Get, Set, Delete, List with prefix filtering
- **gRPC Interface**: Full Dapr state store protocol support
- **Automatic Schema**: Creates required NebulaGraph spaces and schemas
- **Docker Integration**: Complete containerized deployment

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

## Management Scripts

- `./run_docker_pluggable.sh start` - Deploy component
- `./run_docker_pluggable.sh status` - Check status
- `./run_docker_pluggable.sh stop` - Stop component
- `./run_docker_pluggable.sh clean` - Clean reset
