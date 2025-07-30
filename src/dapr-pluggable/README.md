# NebulaGraph Dapr State Store Component

A Dapr pluggable component that provides state store functionality using NebulaGraph as the backend.

## 📁 Project Structure

```
nebulagraph/
├── src/
│   └── dapr-pluggable/               # Dapr pluggable component implementation
│       ├── main.go                   # Component entry point  
│       ├── stores/
│       │   └── nebulagraph_store.go  # NebulaGraph state store implementation
│       ├── components/
│       │   └── component.yml         # Dapr component configuration
│       ├── go.mod                    # Go module definition (module: nebulagraph)
│       ├── Dockerfile                # Component container
│       ├── docker-compose.yml        # Main Dapr component services
│       ├── docker-compose.dependencies.yml  # NebulaGraph dependencies
│       ├── test_component.sh         # Test script for verification
│       └── README.md                 # This file
└── (other potential components/tools in the future)
```

### Project Organization

The project follows a hierarchical, modular structure:

- **`src/dapr-pluggable/`**: Contains the complete Dapr pluggable component implementation
- **`main.go`**: Entry point that registers the NebulaGraph state store with Dapr
- **`stores/`**: Contains all state store implementations (designed for future extensibility)
- **`components/`**: Dapr component configuration files
- **`go.mod`**: Defines the `nebulagraph` module with clean internal imports
- **Root level**: Docker configuration, documentation, and utility scripts

This structure allows for:
- Easy extension with additional store types within the same component
- Future addition of other Dapr components or NebulaGraph tools in parallel directories
- Clear separation between different types of implementations
- Professional, enterprise-ready project layout

### Binary Names

- **Local Development**: `nebulagraph` (follows Go module naming)
- **Docker Container**: `/component` (follows Dapr component conventions)

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose
- NebulaGraph v3.8.0+ cluster
- Dapr runtime v1.15.8+

### 1. Start NebulaGraph Dependencies

First, start the NebulaGraph cluster:

```bash
# Start NebulaGraph services (creates the shared network)
docker-compose -f docker-compose.dependencies.yml up -d

# Wait for services to be ready (about 30 seconds)
# Check that all services are running
docker-compose -f docker-compose.dependencies.yml ps
```

### 2. Build and Start the Dapr Component

Build and start the NebulaGraph Dapr component:

```bash
# Build the component image
docker-compose build nebulagraph-component

# Start the component and Dapr runtime
docker-compose up -d

# Verify services are running
docker-compose ps
```

### 3. Verify Component Registration

Check that the component is properly registered with Dapr:

```bash
# Check component logs
docker logs nebulagraph-dapr-component

# Check Dapr runtime logs (should show successful initialization)
docker logs daprd-nebulagraph
```

### 4. Test the Component

Run the comprehensive test script:

```bash
# Make the test script executable
chmod +x test_component.sh

# Run all tests
./test_component.sh
```

Or test manually with individual operations:

```bash
# Test SET operation
curl -X POST http://localhost:3500/v1.0/state/nebulagraph-state \
  -H "Content-Type: application/json" \
  -d '[{"key": "test-key", "value": "Hello NebulaGraph!"}]'

# Test GET operation
curl -X GET http://localhost:3500/v1.0/state/nebulagraph-state/test-key

# Test DELETE operation
curl -X DELETE http://localhost:3500/v1.0/state/nebulagraph-state/test-key

# Test BULK GET operation
curl -X POST http://localhost:3500/v1.0/state/nebulagraph-state/bulk \
  -H "Content-Type: application/json" \
  -d '{"keys": ["key1", "key2"]}'
```

## 📁 File Structure

```
.
├── main.go                           # Component entry point
├── components/
│   ├── state_store.go               # NebulaGraph state store implementation
│   └── component.yml                # Dapr component configuration
├── Dockerfile                       # Component container
├── docker-compose.yml               # Main Dapr component services
├── docker-compose.dependencies.yml  # NebulaGraph dependencies
├── test_component.sh                # Test script for verification
└── README.md                        # This file
```

## ⚙️ Component Configuration

The component is configured through the `components/component.yml` file:

```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: nebulagraph-state
spec:
  type: state.nebulagraph-state
  version: v1
  metadata:
  - name: hosts
    value: "nebula-graphd"          # NebulaGraph host (comma-separated for multiple)
  - name: port
    value: "9669"                   # NebulaGraph port
  - name: username
    value: "root"                   # Username
  - name: password
    value: "nebula"                 # Password
  - name: space
    value: "dapr_state"             # NebulaGraph space name
  - name: connectionTimeout
    value: "10s"                    # Connection timeout (optional)
  - name: executionTimeout
    value: "30s"                    # Execution timeout (optional)
```

## 🔧 Troubleshooting

### Common Issues

1. **Component not found**: Ensure socket names match between component registration and Dapr configuration
2. **Connection refused**: Verify NebulaGraph services are running and accessible
3. **Network issues**: Ensure both component and NebulaGraph are on the same Docker network
4. **Permission issues**: Check that socket volumes are properly mounted

### Debug Commands

```bash
# Check service status
docker-compose ps
docker-compose -f docker-compose.dependencies.yml ps

# View logs
docker logs nebulagraph-dapr-component
docker logs daprd-nebulagraph
docker logs nebula-graphd

# Test network connectivity
docker exec nebulagraph-dapr-component ping nebula-graphd

# Check socket files
docker exec daprd-nebulagraph ls -la /var/run/
```

## 🧹 Cleanup

Stop and remove all services:

```bash
# Stop main services
docker-compose down

# Stop NebulaGraph dependencies
docker-compose -f docker-compose.dependencies.yml down

# Optional: Remove the shared network
docker network rm nebulagraph_nebula-net
```

## 🛠️ Development

### Local Development

Build and run locally for development:

```bash
# Install dependencies
go mod download

# Build the component
go build -o nebulagraph-component .

# Run locally (requires NebulaGraph running)
export DAPR_COMPONENT_SOCKETS_FOLDER=/tmp/dapr-components-sockets
mkdir -p $DAPR_COMPONENT_SOCKETS_FOLDER
./nebulagraph-component
```

### Testing Changes

After making changes to the component:

```bash
# Rebuild and restart
docker-compose build nebulagraph-component
docker-compose down && docker-compose up -d

# Run tests
./test_component.sh
```

## 📋 Requirements

- Docker & Docker Compose
- Go 1.24+ (for local development)
- NebulaGraph v3.8.0+
- Dapr runtime v1.15.8+

## 🚀 Usage in Applications

To use this component in your Dapr applications:

1. Ensure the component is running and registered
2. Reference the component by name in your application:

```bash
# Set state
curl -X POST http://localhost:3500/v1.0/state/nebulagraph-state \
  -H "Content-Type: application/json" \
  -d '[{"key": "mykey", "value": "myvalue"}]'

# Get state  
curl -X GET http://localhost:3500/v1.0/state/nebulagraph-state/mykey
```

Or use the Dapr SDK in your preferred programming language.

## 📖 Additional Resources

- [Dapr State Store API](https://docs.dapr.io/reference/api/state_api/)
- [NebulaGraph Documentation](https://docs.nebula-graph.io/)
- [Dapr Pluggable Components](https://docs.dapr.io/operations/components/pluggable-components/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly using the provided test script
5. Submit a pull request
