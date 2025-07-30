# NebulaGraph Dapr Component Test API

This is a .NET 9 test API for validating the NebulaGraph Dapr state store component. It provides both HTTP REST and gRPC endpoints to test all CRUD operations through Dapr.

## Project Structure

```
src/
├── NebulaGraphTestApi/                 # .NET 9 Web API project
│   ├── Controllers/
│   │   └── StateController.cs         # HTTP REST API controller
│   ├── Services/
│   │   └── NebulaGraphGrpcService.cs  # gRPC service implementation
│   ├── Protos/
│   │   └── nebulagraph.proto          # gRPC service definition
│   ├── dapr/
│   │   └── nebulagraph-store.yaml     # Dapr component configuration
│   ├── Program.cs                     # Application startup configuration
│   ├── start_api.sh                   # Script to start API with Dapr
│   ├── test_api.sh                    # HTTP API test script
│   ├── test_grpc.sh                   # gRPC API test script
│   └── README.md                      # This file
├── dapr-pluggable/                    # NebulaGraph Dapr component
└── nebulagraph_test.sln               # Solution file
```

## Prerequisites

1. **NebulaGraph cluster** running (see main project README)
2. **Dapr runtime** installed and initialized
3. **NebulaGraph Dapr component** built and running
4. **.NET 9 SDK** installed
5. **grpcurl** for gRPC testing (optional, auto-installed by test script)

## Quick Start

### 1. Ensure Prerequisites

Make sure NebulaGraph cluster is running:
```bash
cd /home/sen/repos/nebulagraph/src/dapr-pluggable
docker-compose -f docker-compose.dependencies.yml up -d
```

Build and start the Dapr component:
```bash
cd /home/sen/repos/nebulagraph/src/dapr-pluggable
./setup_dev.sh
```

### 2. Start the Test API

From within the `NebulaGraphTestApi` directory:
```bash
cd /home/sen/repos/nebulagraph/src/NebulaGraphTestApi
./start_api.sh
```

This will:
- Build the .NET application
- Start it with Dapr runtime
- Expose HTTP API on `http://localhost:5000`
- Expose gRPC API on `localhost:5000`
- Configure Dapr HTTP port on `3500`

### 3. Test the APIs

#### HTTP REST API Testing
```bash
./test_api.sh
```

#### gRPC API Testing
```bash
./test_grpc.sh
```

#### Manual Testing with Swagger UI
Visit: `http://localhost:5000/swagger`

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
curl -X POST "http://localhost:5000/api/state/mykey" \
     -H "Content-Type: application/json" \
     -d '{"value":"myvalue"}'

# Get a value
curl -X GET "http://localhost:5000/api/state/mykey"

# Delete a value
curl -X DELETE "http://localhost:5000/api/state/mykey"

# Bulk operations
curl -X POST "http://localhost:5000/api/state/bulk" \
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

### Direct Dapr API Testing

You can also test the Dapr component directly:

```bash
# Set via Dapr
curl -X POST "http://localhost:3500/v1.0/state/nebulagraph-store" \
     -H "Content-Type: application/json" \
     -d '[{"key":"testkey", "value":"testvalue"}]'

# Get via Dapr
curl -X GET "http://localhost:3500/v1.0/state/nebulagraph-store/testkey"
```

## Configuration

The Dapr component configuration is in `dapr/nebulagraph-store.yaml`:

```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: nebulagraph-store
spec:
  type: state.nebulagraph
  version: v1
  metadata:
  - name: graphHost
    value: "127.0.0.1"
  - name: graphPort
    value: "9669"
  - name: space
    value: "dapr_state"
  - name: username
    value: "root"
  - name: password
    value: "nebula"
  - name: tag
    value: "state_tag"
```

## Troubleshooting

### Component Not Found
If you get "component not found" errors:
1. Ensure the NebulaGraph Dapr component is running
2. Check the component configuration path in `start_api.sh`
3. Verify NebulaGraph cluster connectivity

### Build Errors
```bash
~/.dotnet/dotnet clean
~/.dotnet/dotnet restore
~/.dotnet/dotnet build
```

### Connection Errors
1. Verify NebulaGraph cluster is running:
   ```bash
   docker-compose -f docker-compose.dependencies.yml ps
   ```
2. Check NebulaGraph console connectivity:
   ```bash
   docker exec -it nebula-console nebula-console -addr graphd -port 9669 -u root -p nebula
   ```

## Development

To modify the API:

1. **Add new endpoints**: Edit `Controllers/StateController.cs`
2. **Modify gRPC service**: Update `Protos/nebulagraph.proto` and `Services/NebulaGraphGrpcService.cs`
3. **Change configuration**: Modify `dapr/nebulagraph-store.yaml`

After changes, rebuild and restart:
```bash
~/.dotnet/dotnet build
./start_api.sh
```
