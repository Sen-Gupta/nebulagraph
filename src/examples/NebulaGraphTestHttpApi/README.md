# NebulaGraph Dapr Component Test HTTP API

This is a .NET 9 HTTP REST API for validating the NebulaGraph Dapr state store component. It provides HTTP REST endpoints to test all CRUD operations and pub/sub functionality through Dapr.

## Project Structure

```
src/
├── NebulaGraphTestHttpApi/            # .NET 9 Web API project
│   ├── Controllers/
│   │   ├── StateController.cs         # HTTP REST API controller for state operations
│   │   └── PubSubController.cs        # HTTP REST API controller for pub/sub operations
│   ├── setup/local/
│   │   └── apps.sh                    # TestAPI management with Dapr sidecar
│   ├── Program.cs                     # Application startup configuration
│   └── README.md                      # This file
├── NebulaGraphTestGrpcApi/            # Separate gRPC API project
├── dapr-pluggable/                    # NebulaGraph Dapr component
├── dependencies/                      # NebulaGraph infrastructure
└── components/                        # Dapr component configurations
```

## Architecture

The TestAPI uses Dapr's service invocation pattern with pluggable components:

```
┌─────────────────────────────────────────────────────────────┐
│                    Dapr Microservices Architecture          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐    ┌──────────────────┐               │
│  │   TestAPI       │◄──►│ TestAPI Dapr     │               │
│  │ (.NET 9 App)    │    │ Sidecar          │               │
│  │ Port: 5090      │    │ HTTP: 3002       │               │
│  │                 │    │ gRPC: 50002      │               │
│  └─────────────────┘    └──────────────────┘               │
│                                │                           │
│                                ▼ Service Discovery         │
│  ┌─────────────────┐    ┌──────────────────┐               │
│  │ NebulaGraph     │◄──►│ Main Dapr        │               │
│  │ Pluggable       │    │ Component        │               │
│  │ Component       │    │ Sidecar          │               │
│  │ (Unix Socket)   │    │ HTTP: 3501       │               │
│  └─────────────────┘    │ gRPC: 50001      │               │
│                         └──────────────────┘               │
│                                │                           │
│                                ▼ Database Connection       │
│                    ┌──────────────────┐                    │
│                    │ NebulaGraph      │                    │
│                    │ Database Cluster │                    │
│                    │ Ports: 9669,     │                    │
│                    │        9559,     │                    │
│                    │        9779      │                    │
│                    └──────────────────┘                    │
└─────────────────────────────────────────────────────────────┘
```

### Communication Flow

1. **Client** → **TestAPI** (HTTP REST or gRPC calls on port 5090)
2. **TestAPI** → **TestAPI Dapr Sidecar** (local HTTP calls to port 3002)
3. **TestAPI Sidecar** → **Main Component Sidecar** (service invocation to port 3501)
4. **Main Component Sidecar** → **NebulaGraph Component** (Unix Domain Socket)
5. **NebulaGraph Component** → **NebulaGraph Database** (native graph protocol on port 9669)

### Key Benefits

- **Service Invocation Pattern**: TestAPI uses service discovery to access the main component
- **Pluggable Component Isolation**: Only the main sidecar loads the NebulaGraph component
- **Unix Socket Efficiency**: High-performance communication between component and main sidecar
- **Multiple Applications Support**: Additional services can access state through service invocation
- **Architecture Compliance**: Follows official Dapr pluggable component patterns

## Prerequisites

1. **NebulaGraph cluster** running (see main project README)
2. **Dapr runtime** installed and initialized
3. **NebulaGraph Dapr component** built and running
4. **.NET 9 SDK** installed
5. **grpcurl** for gRPC testing (optional, auto-installed by test script)

## Quick Start

### 1. Start NebulaGraph Infrastructure

```bash
cd /home/sen/repos/nebulagraph/src/dependencies
./environment_setup.sh start
```

### 2. Start Main Dapr Component

```bash
cd /home/sen/repos/nebulagraph/src/dapr-pluggable
./run_docker_pluggable.sh start
```

### 3. Start TestAPI with Dapr Sidecar

```bash
cd /home/sen/repos/nebulagraph/src/NebulaGraphTestApi/setup/local
./apps.sh start
```

This will:
- Validate all dependencies (Dapr CLI, .NET 9, Go, NebulaGraph)
- Ensure required ports are available (5090, 3002, 50002)
- Build the .NET application
- Start TestAPI with its own Dapr sidecar
- Run comprehensive tests to verify functionality

### 4. Access the APIs

- **HTTP REST API**: `http://localhost:5090/api/state`
- **Swagger UI**: `http://localhost:5090/swagger`
- **TestAPI Dapr Sidecar**: `http://localhost:3002/v1.0/`
- **Main Component Sidecar**: `http://localhost:3501/v1.0/`

## Management Commands

### TestAPI Management (`apps.sh`)

```bash
cd /home/sen/repos/nebulagraph/src/NebulaGraphTestApi/setup/local

# Start TestAPI with Dapr sidecar
./apps.sh start

# Stop TestAPI
./apps.sh stop

# Restart TestAPI
./apps.sh restart

# Check status
./apps.sh status

# Run tests only
./apps.sh test

# Build without starting
./apps.sh build
```

### Infrastructure Management

```bash
# NebulaGraph cluster management
cd /home/sen/repos/nebulagraph/src/dependencies
./environment_setup.sh start|stop|status|test|clean

# Main Dapr component management  
cd /home/sen/repos/nebulagraph/src/dapr-pluggable
./run_docker_pluggable.sh start|stop|status|test|clean
```

## API Endpoints

### HTTP REST API (`/api/state`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/state/{key}` | Get value by key |
| POST | `/api/state/{key}` | Set value for key |
| DELETE | `/api/state/{key}` | Delete key |
| GET | `/api/state/list?prefix={prefix}&limit={limit}` | List keys with prefix |
| POST | `/api/state/bulk` | Bulk operations |

### gRPC API (`nebulagraph.NebulaGraphService`)

| Method | Description |
|--------|-------------|
| `GetValue` | Get value by key |
| `SetValue` | Set value for key |
| `DeleteValue` | Delete key |
| `ListKeys` | List keys with prefix |

## Testing Examples

### HTTP API Examples

```bash
# Set a value
curl -X POST "http://localhost:5090/api/state/mykey" \
     -H "Content-Type: application/json" \
     -d '{"value":"myvalue"}'

# Get a value
curl -X GET "http://localhost:5090/api/state/mykey"

# Delete a value
curl -X DELETE "http://localhost:5090/api/state/mykey"

# Bulk operations
curl -X POST "http://localhost:5090/api/state/bulk" \
     -H "Content-Type: application/json" \
     -d '{
         "operations": [
             {"key": "key1", "value": "value1", "operation": "set"},
             {"key": "key2", "value": "value2", "operation": "set"}
         ]
     }'
```

### gRPC API Examples

```bash
# Set a value
grpcurl -plaintext \
    -d '{"key": "mykey", "value": "myvalue"}' \
    localhost:5000 nebulagraph.NebulaGraphService/SetValue

# Get a value
grpcurl -plaintext \
    -d '{"key": "mykey"}' \
    localhost:5000 nebulagraph.NebulaGraphService/GetValue
```

### Service Invocation Testing

You can test the service invocation pattern through TestAPI:

```bash
# Test via TestAPI (uses service invocation to main component)
curl -X POST "http://localhost:5090/api/state/testkey" \
     -H "Content-Type: application/json" \
     -d '{"value":"testvalue"}'

# Get via TestAPI
curl -X GET "http://localhost:5090/api/state/testkey"
```

### Direct Component Testing

You can also test the main component directly:

```bash
# Set via main component
curl -X POST "http://localhost:3501/v1.0/state/nebulagraph-state" \
     -H "Content-Type: application/json" \
     -d '[{"key":"testkey", "value":"testvalue"}]'

# Get via main component
curl -X GET "http://localhost:3501/v1.0/state/nebulagraph-state/testkey"
```

## Configuration

The main Dapr component configuration uses the pluggable component pattern. The TestAPI accesses the state store through service invocation rather than direct component loading.

Component discovery happens automatically via Unix Domain Sockets in `/tmp/dapr-components-sockets/`.

## Troubleshooting

### Main Component Not Accessible
If you get connection errors to the main component:
1. Ensure the main Dapr component is running: `./run_docker_pluggable.sh status`
2. Check that port 3501 is accessible: `curl http://localhost:3501/v1.0/healthz`
3. Verify the component logs for any startup errors

### TestAPI Service Invocation Errors
If TestAPI cannot access the state store:
1. Verify both sidecars are running: `./apps.sh status`
2. Check service discovery is working between sidecars
3. Ensure the main component is registered and healthy

### Build Errors
```bash
cd /home/sen/repos/nebulagraph/src/NebulaGraphTestApi
~/.dotnet/dotnet clean
~/.dotnet/dotnet restore
~/.dotnet/dotnet build
```

### NebulaGraph Connectivity Issues
1. Verify NebulaGraph cluster is running:
   ```bash
   cd /home/sen/repos/nebulagraph/src/dependencies
   ./environment_setup.sh status
   ```
2. Check NebulaGraph console connectivity:
   ```bash
   docker run --rm --network nebula-net vesoft/nebula-console:v3-nightly \
     --addr nebula-graphd --port 9669 --user root --password nebula \
     --eval "SHOW SPACES;"
   ```

## Development

To modify the API:

1. **Add new endpoints**: Edit `Controllers/StateController.cs`
2. **Modify gRPC service**: Update `Protos/nebulagraph.proto` and `Services/NebulaGraphGrpcService.cs`
3. **Change TestAPI behavior**: Modify the service invocation calls to the main component

After changes, rebuild and restart:
```bash
cd /home/sen/repos/nebulagraph/src/NebulaGraphTestApi/setup/local
./apps.sh restart
```
