# NebulaGraph Dapr Pluggable Component

## Project Intent

This project provides a complete, containerized implementation of a Dapr pluggable state store component using NebulaGraph as the backend database. It is designed to enable cloud-native applications to leverage graph database capabilities for state management, with seamless integration into the Dapr ecosystem.

### Key Features
- **Dapr Pluggable Component**: Implements the Dapr state store protocol, supporting both HTTP and gRPC APIs.
- **NebulaGraph Backend**: Uses NebulaGraph for persistent, scalable, and schema-driven state storage.
- **ScyllaDB Backend**: Alternative distributed database backend with high performance and scalability.
- **Containerized Deployment**: All components (Dapr, NebulaGraph, ScyllaDB) run in Docker containers for easy setup and reproducibility.
- **Automatic Schema Management**: Initializes required spaces and schemas automatically.
- **Comprehensive Testing**: Includes .NET 9 HTTP and gRPC test APIs, with scripts for automated testing of all operations.

## Architecture Overview
- **Client Applications** interact with Dapr via HTTP (port 3501) or gRPC (port 50001).
- **Dapr Sidecar** communicates with the pluggable component over a shared Unix domain socket.
- **State Store Component** exposes a gRPC server and implements the state store logic.
- **Database Backend** provides the actual persistent storage (NebulaGraph or ScyllaDB).

## Quick Start

### Prerequisites
- Docker & Docker Compose
- Dapr CLI
- Go 1.24.5+
- .NET 9.0 (for test APIs)

### Setup & Run
```bash
# 1. Setup infrastructure
cd src/dependencies
./environment_setup.sh

# 2. Run the Dapr component
cd ../dapr-pluggable-components
./run_nebula.sh start

# 3. Test all operations
./tests/test_all.sh
```

## Example APIs
- **HTTP API**: `src/examples/NebulaGraphTestHttpApi/`
- **gRPC API**: `src/examples/NebulaGraphTestGrpcApi/`

## Configuration
- See `.env` and `src/components/*.yaml` for all environment and component settings.
- Full configuration guide: `docs/configuration.md`

## Documentation
- **Architecture**: `docs/architecture.md`
- **Component Configuration**: `docs/configuration.md`
- **Infrastructure Setup**: `src/dependencies/README.md`

## License & Usage
This is a sample project intended for demonstration, development, and educational purposes. Credentials and configuration in `.env` are for local/demo use only.

---
For more details, see the documentation files in the `docs/` and `src/` folders.
