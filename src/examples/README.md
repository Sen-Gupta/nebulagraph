# .NET Examples

Comprehensive .NET 9 examples demonstrating Dapr state store integration with NebulaGraph and ScyllaDB.

## Overview

The unified `DotNet/` project provides a single API that can connect to either backend, demonstrating the power of Dapr's abstraction layer.

## Features

- **Multi-Backend API**: Single codebase works with both NebulaGraph and ScyllaDB
- **Full CRUD Operations**: Get, Set, Delete, Bulk operations
- **Performance Testing**: Benchmarking and load testing capabilities
- **Health Monitoring**: Service health checks and status endpoints
- **Swagger Documentation**: Interactive API documentation
- **Docker Ready**: Containerized deployment with Docker Compose

## Quick Start

```bash
# Start infrastructure and components
cd ../dependencies && ./environment_setup.sh start
cd ../dapr-pluggable-components && ./run_dapr_pluggables.sh start

# Run .NET examples
cd ../examples && ./run_dotnet_examples.sh start

# Access Swagger UI
open http://localhost:5092/swagger
```

## API Endpoints

### State Store Operations
- `GET /api/statestore/nebula/{key}` - Get from NebulaGraph
- `POST /api/statestore/nebula` - Set in NebulaGraph
- `DELETE /api/statestore/nebula/{key}` - Delete from NebulaGraph
- `GET /api/statestore/scylla/{key}` - Get from ScyllaDB
- `POST /api/statestore/scylla` - Set in ScyllaDB
- `DELETE /api/statestore/scylla/{key}` - Delete from ScyllaDB

### Bulk Operations
- `POST /api/statestore/nebula/bulk` - Bulk operations for NebulaGraph
- `POST /api/statestore/scylla/bulk` - Bulk operations for ScyllaDB

### Health & Monitoring
- `GET /health` - Application health status
- `GET /api/statestore/health` - Component health status

## Testing

```bash
# Run automated test suites
./tests/test_all_net.sh          # All tests
./tests/test_nebula_net.sh       # NebulaGraph specific
./tests/test_scylladb_net.sh     # ScyllaDB specific
```

## Management

```bash
./run_dotnet_examples.sh start   # Start services
./run_dotnet_examples.sh stop    # Stop services  
./run_dotnet_examples.sh status  # Check status
./run_dotnet_examples.sh logs    # View logs
./run_dotnet_examples.sh test    # Run functionality tests
```

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
