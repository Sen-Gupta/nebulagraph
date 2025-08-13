# NebulaGraph Da```bash
# Pull the latest image
docker pull foodinvitesadmin/dapr-pluggables:latest

# Or use in your docker-compose.yml
services:
  dapr-pluggable:
    image: foodinvitesadmin/dapr-pluggables:latest
    environment:
      - STORE_TYPES=nebulagraph,scylladb
```e Components

A production-ready implementation of Dapr pluggable state store components supporting both NebulaGraph and ScyllaDB backends.

## Features

- **Multi-Backend Support**: NebulaGraph (graph database) and ScyllaDB (wide-column) state stores
- **Dapr Integration**: Full HTTP/gRPC API compatibility with automatic schema management
- **Container-First**: Docker Compose orchestration for development and production
- **Comprehensive Testing**: .NET 9 examples and automated test suites
- **Production Ready**: Health checks, monitoring, and robust error handling

## Quick Start

### Using Pre-built Docker Image

```bash
# Pull the latest image
docker pull sengupta/dapr-pluggable:latest

# Or use in your docker-compose.yml
services:
  dapr-component:
    image: sengupta/dapr-pluggable:latest
    environment:
      - STORE_TYPES=nebulagraph,scylladb
```

### Building from Source

**Quick Local Build:**
```bash
# Build and push Docker image locally  
cd local-build
./build.sh
```

**Development Setup:**
```bash
# 1. Start infrastructure (NebulaGraph, ScyllaDB, Dapr, Redis)
cd src/dependencies && ./environment_setup.sh start

# 2. Run pluggable components
cd ../dapr-pluggable-components && ./run_dapr_pluggables.sh start

# 3. Test with .NET examples
cd ../examples && ./run_dotnet_examples.sh start

# 4. Run comprehensive tests
cd ../dapr-pluggable-components && ./tests/test_all.sh
```

## Architecture

**Client App** → **Dapr Sidecar** → **Unix Socket** → **Pluggable Component** → **Backend Database**

- **Dapr Sidecar**: HTTP (3501) and gRPC (50001) APIs
- **Components**: Multi-store Go binary supporting NebulaGraph/ScyllaDB
- **Backends**: NebulaGraph cluster (graphd:9669) or ScyllaDB cluster (9042)

## Project Structure

- `src/dependencies/` - Infrastructure setup and management
- `src/dapr-pluggable-components/` - Go implementation of state store components  
- `src/examples/` - .NET 9 API examples and integration tests
- `src/components/` - Dapr component configurations
- `docs/` - Architecture and configuration documentation

## Documentation
- **Architecture**: `docs/architecture.md`
- **Component Configuration**: `docs/configuration.md`
- **Infrastructure Setup**: `src/dependencies/README.md`

## License & Usage
This is a sample project intended for demonstration, development, and educational purposes. Credentials and configuration in `.env` are for local/demo use only.

---
For more details, see the documentation files in the `docs/` and `src/` folders.
