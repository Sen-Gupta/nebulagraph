# Dapr Pluggable Components .NET Examples

This directory contains comprehensive .NET examples demonstrating the integration of Dapr pluggable state store components with .NET 9 applications.

## Overview

The `dapr_pluggables.sln` solution includes two parallel .NET example projects that showcase different state store backends:

- **NebulaGraphNetExample** - Demonstrates NebulaGraph as a Dapr state store
- **ScylladbNetExample** - Demonstrates ScyllaDB as a Dapr state store

Both examples provide identical API interfaces, making it easy to compare performance, features, and behavior across different database backends.

## Projects

### NebulaGraphNetExample
A comprehensive .NET web application demonstrating NebulaGraph integration with Dapr's state management API.

**Features:**
- Full CRUD operations using Dapr state store
- Performance testing and benchmarking
- Bulk operations for high-throughput scenarios
- Health checks and monitoring
- Swagger API documentation

**Key Files:**
- `NebulaGraphNetExample.csproj` - Project configuration
- `Controllers/StateStoreController.cs` - Main API implementation
- `docker-compose.yml` - Container orchestration
- `test_nebula_net.sh` - Automated test suite

### ScylladbNetExample
A parallel .NET web application demonstrating ScyllaDB integration with identical functionality to the NebulaGraph example.

**Features:**
- Identical API interface to NebulaGraphNetExample
- ScyllaDB-optimized state store operations
- Comprehensive test suite with 20+ test scenarios
- Performance benchmarking and monitoring
- Docker containerization support

**Key Files:**
- `ScylladbNetExample.csproj` - Project configuration
- `Controllers/StateStoreController.cs` - Main API implementation
- `docker-compose.yml` - Container orchestration
- `test_scylladb_net.sh` - Automated test suite
- `README.md` - Detailed project documentation

## Common Features

Both examples share the following capabilities:

### API Endpoints
- **Health Check**: `GET /api/StateStore/health`
- **Basic Operations**: Save, Get, Delete state by key
- **Bulk Operations**: Batch save and retrieve operations
- **Testing**: Comprehensive test suite execution
- **Performance**: Automated performance benchmarking

### Architecture
```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│  .NET Application   │    │   Dapr Sidecar     │    │   State Store       │
│                     │◄──►│                     │◄──►│   Component         │
│ NebulaGraph/Scylla  │    │  State Management   │    │  (Pluggable)        │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
```

### Development Workflow
1. **Build**: `dotnet build dapr_pluggables.sln`
2. **Run Individual**: `dotnet run` in project directory
3. **Test**: Execute `test_*_net.sh` scripts
4. **Docker**: Use `docker-compose up` for containerized deployment

## Getting Started

### Prerequisites
- .NET 9 SDK
- Docker and Docker Compose
- Dapr CLI (for local development)
- Infrastructure services (NebulaGraph, ScyllaDB)

### Building the Solution
```bash
cd /home/sen/repos/nebulagraph/src/examples
dotnet build dapr_pluggables.sln
```

### Running Examples

#### NebulaGraphNetExample
```bash
cd NebulaGraphNetExample
dotnet run
# Access: http://localhost:5000
```

#### ScylladbNetExample
```bash
cd ScylladbNetExample
dotnet run
# Access: http://localhost:5001
```

### Docker Deployment

Each project includes Docker Compose configuration for complete environment setup:

```bash
# NebulaGraph example
cd NebulaGraphNetExample
docker-compose up -d

# ScyllaDB example
cd ScylladbNetExample
docker-compose up -d
```

## Testing

Both examples include comprehensive test suites:

### NebulaGraph Tests
```bash
cd NebulaGraphNetExample
./test_nebula_net.sh
```

### ScyllaDB Tests
```bash
cd ScylladbNetExample
./test_scylladb_net.sh
```

## Performance Comparison

Both examples include built-in performance testing endpoints that allow direct comparison:

```bash
# NebulaGraph performance
curl -X POST "http://localhost:5000/api/StateStore/performance/test?operations=100"

# ScyllaDB performance
curl -X POST "http://localhost:5001/api/StateStore/performance/test?operations=100"
```

## Use Cases

### Dual State Store Architecture
Use both examples together to implement:
- **Primary/Secondary Store**: NebulaGraph for graph queries, ScyllaDB for high-throughput operations
- **Performance Testing**: Compare database performance under identical workloads
- **Failover Scenarios**: Switch between state stores based on availability
- **Data Migration**: Move data between different backend systems

### Development Scenarios
- **API Consistency**: Ensure identical behavior across different databases
- **Performance Optimization**: Choose optimal database for specific use cases
- **Protocol Testing**: Validate HTTP and gRPC compatibility
- **Load Testing**: Benchmark applications under various conditions

## Configuration

### State Store Components
Both examples connect to their respective state stores using Dapr component configurations:

**NebulaGraph Component** (`nebulagraph-state`)
```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: nebulagraph-state
spec:
  type: state.nebulagraph
  version: v1
```

**ScyllaDB Component** (`scylladb-state`)
```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: scylladb-state
spec:
  type: state.scylladb
  version: v1
```

## Contributing

When contributing to these examples:
1. Maintain API consistency between both projects
2. Add comprehensive tests for new features
3. Update performance benchmarks
4. Document new endpoints and configurations
5. Ensure Docker compatibility

## Integration

These examples integrate with the broader Dapr pluggable components ecosystem:
- **Component Implementation**: `/src/dapr-pluggable-components`
- **Infrastructure**: `/src/dependencies`
- **Configuration**: `/src/components`

## License

These examples are part of the Dapr pluggable components project and follow the same licensing terms.
