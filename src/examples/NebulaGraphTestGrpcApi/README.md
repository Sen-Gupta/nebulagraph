# NebulaGraph Test gRPC API

.NET 9 gRPC service for testing the NebulaGraph Dapr state store component.

## Quick Start

### Prerequisites
- .NET 9.0
- NebulaGraph infrastructure running (see `src/dependencies/`)
- Dapr component running (see `src/dapr-pluggable-components/`)

### Run the API

**Docker (Recommended):**
```bash
docker-compose up --build
```
gRPC service available at: `localhost:5093` (or `$TEST_GRPC_API_HOST_PORT`)

**Local Development:**
```bash
dotnet run
```
gRPC service available at: `localhost:5000`

### Test the API
```bash
./test_grpc.sh
```

## gRPC Service

Service definition in `Protos/nebulagraph.proto`:

```protobuf
service NebulaGraphService {
  rpc GetValue (GetValueRequest) returns (GetValueResponse);
  rpc SetValue (SetValueRequest) returns (SetValueResponse);
  rpc DeleteValue (DeleteValueRequest) returns (DeleteValueResponse);
  rpc ListKeys (ListKeysRequest) returns (ListKeysResponse);
}
```

## Testing with grpcurl

```bash
# Set value
grpcurl -plaintext \
    -d '{"key": "test-key", "value": "test-value"}' \
    localhost:5093 nebulagraph.NebulaGraphService/SetValue

# Get value
grpcurl -plaintext \
    -d '{"key": "test-key"}' \
    localhost:5093 nebulagraph.NebulaGraphService/GetValue
```

## Configuration

Environment variables (set in `.env`):
- `TEST_GRPC_API_HOST_PORT` - External port (default: 5093)
- `DAPR_HTTP_ENDPOINT` - Dapr HTTP endpoint  
- `DAPR_GRPC_ENDPOINT` - Dapr gRPC endpoint interface while maintaining separation of concerns.

The application is configured to use HTTP/2 for gRPC communication as defined in `appsettings.json`.
