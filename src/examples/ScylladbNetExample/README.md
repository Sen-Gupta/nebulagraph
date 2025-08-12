# ScyllaDB .NET Example

This example demonstrates how to use the ScyllaDB Dapr pluggable state store component with a .NET 9 web application.

## Overview

The ScylladbNetExample is a comprehensive .NET web application that showcases:
- **ScyllaDB State Store Integration**: Full CRUD operations using Dapr's state management API
- **Performance Testing**: Built-in performance benchmarks and metrics
- **Bulk Operations**: Efficient batch operations for high-throughput scenarios
- **Health Checks**: Monitoring and validation endpoints
- **Cross-Protocol Support**: Compatible with both HTTP and gRPC protocols
- **Swagger Documentation**: Interactive API documentation

## Features

### Core Operations
- **Save State**: Store key-value pairs with JSON serialization
- **Get State**: Retrieve values by key with type safety
- **Delete State**: Remove specific keys from the state store
- **Bulk Operations**: Batch save/get operations for efficiency

### Advanced Features
- **Performance Testing**: Automated benchmarks measuring operations per second
- **Concurrent Operations**: Multi-threaded operation support
- **Large Data Handling**: Support for complex JSON objects and large payloads
- **Health Monitoring**: Real-time health checks and status reporting
- **Comprehensive Test Suite**: 20+ automated tests covering all functionality

## Architecture

```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│  .NET Application   │    │   Dapr Sidecar     │    │ ScyllaDB Component  │
│                     │◄──►│                     │◄──►│                     │
│ ScylladbNetExample  │    │  State Management   │    │   Pluggable Store   │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
```

## API Endpoints

### Health Check
```http
GET /api/StateStore/health
```
Returns the health status of the ScyllaDB state store connection.

### Basic Operations
```http
POST /api/StateStore/save/{key}          # Save state
GET  /api/StateStore/get/{key}           # Get state
DELETE /api/StateStore/delete/{key}      # Delete state
```

### Bulk Operations
```http
POST /api/StateStore/bulk/save           # Bulk save
POST /api/StateStore/bulk/get            # Bulk get
```

### Testing & Performance
```http
POST /api/StateStore/run/comprehensive   # Run complete test suite
POST /api/StateStore/performance/test    # Performance benchmark
```

## Getting Started

### Prerequisites
- .NET 9 SDK
- Docker and Docker Compose
- ScyllaDB infrastructure running
- Dapr CLI (for local development)

### Running with Docker Compose

1. **Start the complete environment:**
   ```bash
   docker-compose up -d
   ```

2. **Access the application:**
   - Application: http://localhost:5001
   - Swagger UI: http://localhost:5001 (redirects to Swagger)
   - HTTPS: https://localhost:7001

3. **Run health check:**
   ```bash
   curl http://localhost:5001/api/StateStore/health
   ```

### Running Locally with Dapr

1. **Build the application:**
   ```bash
   dotnet build
   ```

2. **Start with Dapr sidecar:**
   ```bash
   dapr run --app-id scylladb-net-example \
            --app-port 5001 \
            --dapr-http-port 3501 \
            --components-path ../../components \
            -- dotnet run
   ```

### Testing the Application

#### Quick Health Check
```bash
curl -X GET http://localhost:5001/api/StateStore/health
```

#### Run Comprehensive Test Suite
```bash
curl -X POST http://localhost:5001/api/StateStore/run/comprehensive
```

#### Performance Test
```bash
curl -X POST "http://localhost:5001/api/StateStore/performance/test?operations=100"
```

#### Basic CRUD Operations
```bash
# Save a simple value
curl -X POST http://localhost:5001/api/StateStore/save/test-key \
     -H "Content-Type: application/json" \
     -d '"Hello ScyllaDB!"'

# Get the value
curl -X GET http://localhost:5001/api/StateStore/get/test-key

# Save a JSON object
curl -X POST http://localhost:5001/api/StateStore/save/user-1 \
     -H "Content-Type: application/json" \
     -d '{"name": "Alice", "age": 30, "department": "Engineering"}'

# Delete the value
curl -X DELETE http://localhost:5001/api/StateStore/delete/test-key
```

#### Bulk Operations
```bash
# Bulk save
curl -X POST http://localhost:5001/api/StateStore/bulk/save \
     -H "Content-Type: application/json" \
     -d '{
       "user-1": {"name": "Alice", "age": 30},
       "user-2": {"name": "Bob", "age": 25},
       "user-3": {"name": "Charlie", "age": 35}
     }'

# Bulk get
curl -X POST http://localhost:5001/api/StateStore/bulk/get \
     -H "Content-Type: application/json" \
     -d '["user-1", "user-2", "user-3"]'
```

## Configuration

### State Store Configuration
The application connects to the ScyllaDB state store using the component name `scylladb-state`. Ensure your Dapr components are configured correctly:

```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: scylladb-state
spec:
  type: state.scylladb
  version: v1
  metadata:
    - name: hosts
      value: "scylladb:9042"
    - name: keyspace
      value: "dapr_state_store"
```

### Application Settings
- **Port Configuration**: Default ports 5001 (HTTP) and 7001 (HTTPS)
- **Logging**: Configurable log levels for development and production
- **Environment**: Supports Development and Production environments

## Performance Characteristics

The ScyllaDB state store provides excellent performance characteristics:

- **Write Operations**: ~20-30ms average latency
- **Read Operations**: ~15-25ms average latency
- **Concurrent Operations**: Supports high concurrency with linear scaling
- **Large Objects**: Efficient handling of complex JSON structures
- **Bulk Operations**: Optimized batch processing

## Development

### Project Structure
```
ScylladbNetExample/
├── Controllers/
│   └── StateStoreController.cs    # Main API controller
├── Properties/
│   └── launchSettings.json        # Launch configuration
├── Program.cs                     # Application entry point
├── ScylladbNetExample.csproj      # Project file
├── appsettings.json               # Application configuration
├── appsettings.Development.json   # Development settings
├── Dockerfile                     # Container definition
├── docker-compose.yml             # Multi-container setup
└── README.md                      # This file
```

### Adding New Features
1. Extend the `StateStoreController` with new endpoints
2. Update the comprehensive test suite to include new functionality
3. Add corresponding API documentation
4. Update this README with new endpoints and examples

## Troubleshooting

### Common Issues

1. **Connection Errors**
   - Verify ScyllaDB infrastructure is running
   - Check network connectivity (`dapr-pluggable-net`)
   - Validate component configuration

2. **Performance Issues**
   - Monitor ScyllaDB cluster health
   - Check for network latency
   - Validate keyspace and table structure

3. **API Errors**
   - Check Dapr sidecar logs
   - Verify component registration
   - Validate JSON serialization

### Logs and Debugging
```bash
# Application logs
docker logs scylladb-net-example

# Dapr sidecar logs  
docker logs scylladb-net-example-dapr

# Component logs
docker logs scylladb-net-component
```

## Integration with Other Examples

This ScyllaDB example can be used alongside the NebulaGraph example to demonstrate:
- **Dual State Store Architecture**: Different stores for different use cases
- **Performance Comparison**: Benchmarking different database backends
- **Protocol Compatibility**: Ensuring consistent behavior across stores
- **Failover Scenarios**: Using backup state stores

## Contributing

When contributing to this example:
1. Maintain API consistency with the NebulaGraph example
2. Add comprehensive tests for new features
3. Update performance benchmarks
4. Document new endpoints and configurations
5. Ensure Docker compatibility

## License

This example is part of the Dapr pluggable components project and follows the same licensing terms.
