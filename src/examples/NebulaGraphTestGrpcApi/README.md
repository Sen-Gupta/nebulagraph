# NebulaGraphTestGrpcApi

A gRPC API example for testing NebulaGraph state store operations through Dapr.

## Overview

This project demonstrates how to use gRPC with Dapr to interact with NebulaGraph as a state store. It provides gRPC endpoints for basic CRUD operations on the NebulaGraph database.

## Features

- **gRPC Service**: `NebulaGraphService` with the following operations:
  - `GetValue`: Retrieve a value by key
  - `SetValue`: Store a key-value pair
  - `DeleteValue`: Delete a key
  - `ListKeys`: List keys with optional prefix filtering

## gRPC Service Definition

The service is defined in `Protos/nebulagraph.proto` and includes:

```protobuf
service NebulaGraphService {
  rpc GetValue (GetValueRequest) returns (GetValueResponse);
  rpc SetValue (SetValueRequest) returns (SetValueResponse);
  rpc DeleteValue (DeleteValueRequest) returns (DeleteValueResponse);
  rpc ListKeys (ListKeysRequest) returns (ListKeysResponse);
}
```

## Dependencies

- .NET 9.0
- Dapr.AspNetCore (1.15.4)
- Dapr.Client (1.15.4)
- Grpc.AspNetCore (2.71.0)
- Grpc.Net.Client (2.71.0)

## Running the Service

### Local Development

```bash
dotnet run
```

The gRPC service will be available on port 5000 (HTTP/2).

### Docker Environment

Use Docker Compose to run the complete setup with Dapr sidecar:

```bash
docker-compose up --build
```

This will start:
- NebulaGraph component
- Test gRPC API service (accessible on port from `TEST_GRPC_API_HOST_PORT` env var, default: 5093)
- Dapr sidecar with gRPC protocol support

The service uses components and configurations from the `../../components` folder.

## Testing with gRPC Client

### Automated Testing

Use the provided test script to test all endpoints:

```bash
./test_grpc.sh
```

This script will automatically:
- Install grpcurl if needed
- Test all gRPC service methods
- Demonstrate CRUD operations

### Manual Testing

To test this service, you'll need a gRPC client. You can use tools like:

- [grpcurl](https://github.com/fullstorydev/grpcurl) - included in test script
- [BloomRPC](https://github.com/uw-labs/bloomrpc)
- Custom .NET gRPC client

#### Using grpcurl

Install grpcurl:
```bash
go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
```

Example commands:
```bash
# For local development (port 5000)
grpcurl -plaintext \
    -d '{"key": "test-key", "value": "test-value"}' \
    localhost:5000 nebulagraph.NebulaGraphService/SetValue

# For Docker environment (use TEST_GRPC_API_HOST_PORT, default: 5093)
grpcurl -plaintext \
    -d '{"key": "test-key", "value": "test-value"}' \
    localhost:5093 nebulagraph.NebulaGraphService/SetValue
```

## Configuration

The service expects Dapr to be running and configured with the NebulaGraph state store component.

### Environment Variables

- `TEST_GRPC_API_HOST_PORT` - Host port for accessing the gRPC API (Docker: default 5093)
- `TEST_GRPC_API_APP_PORT` - Internal application port (Docker: default 80) 
- `TEST_GRPC_API_HTTP_PORT` - Dapr HTTP port (Docker: default 3503)
- `TEST_GRPC_API_GRPC_PORT` - Dapr gRPC port (Docker: default 50003)
- `DAPR_HTTP_ENDPOINT` - Dapr HTTP endpoint for service communication
- `DAPR_GRPC_ENDPOINT` - Dapr gRPC endpoint for service communication

All ports are configurable via environment variables defined in `.env.docker`.

### Architecture

The gRPC API acts as a client to the main NebulaGraph component, making service invocation calls through Dapr. This allows testing of the component's gRPC interface while maintaining separation of concerns.

The application is configured to use HTTP/2 for gRPC communication as defined in `appsettings.json`.
