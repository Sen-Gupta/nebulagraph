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

```bash
dotnet run
```

The gRPC service will be available on the configured port (default: 5000 for HTTP, 5001 for HTTPS).

## Testing with gRPC Client

To test this service, you'll need a gRPC client. You can use tools like:

- [grpcurl](https://github.com/fullstorydev/grpcurl)
- [BloomRPC](https://github.com/uw-labs/bloomrpc)
- Custom .NET gRPC client

## Configuration

The service expects Dapr to be running and configured with the NebulaGraph state store component.
