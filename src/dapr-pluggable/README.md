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
│       ├── Dockerfile.test           # Test container (optional)
│       ├── docker-compose.yml        # Main Dapr component services
│       ├── docker-compose.dependencies.yml  # NebulaGraph dependencies
│       ├── init_nebula.sh            # NebulaGraph cluster initialization
│       ├── setup_dev.sh              # One-stop development setup
│       ├── test_component.sh         # Comprehensive test suite
│       ├── README.md                 # Main documentation
│       ├── README_DEV.md             # Development setup guide
│       └── .gitignore                # Git ignore rules
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

### Option 1: Automated Setup (Recommended)

For new developers or complete setup:

```bash
# 1. Start NebulaGraph dependencies
docker-compose -f docker-compose.dependencies.yml up -d

# 2. One-command development setup (runs initialization + tests)
./setup_dev.sh

# 3. Start your Dapr component
docker-compose up -d
```

### Option 2: Manual Step-by-Step Setup

### 1. Start NebulaGraph Dependencies

First, start the NebulaGraph cluster:

```bash
# Start NebulaGraph services (creates the shared network)
docker-compose -f docker-compose.dependencies.yml up -d

# Wait for services to be ready (about 30 seconds)
# Check that all services are running
docker-compose -f docker-compose.dependencies.yml ps
```

### 2. Initialize NebulaGraph Cluster (Development Only)

**Important**: NebulaGraph requires cluster initialization for development:

```bash
# Initialize the cluster (required once per environment)
./init_nebula.sh
```

### 3. Build and Start the Dapr Component

### 3. Build and Start the Dapr Component

Build and start the NebulaGraph Dapr component:

```bash
# Build the component image
docker-compose build nebulagraph-component

# Start the component and Dapr runtime
docker-compose up -d

# Verify services are running
docker-compose ps
```

### 4. Test the Component

Run the comprehensive test script:

```bash
# Run all tests (includes automatic schema setup)
./test_component.sh
```

**Note**: The test script automatically creates the required `dapr_state` space and schema if they don't exist.

## 📖 Development Guide

For detailed development setup, testing, and troubleshooting, see [README_DEV.md](README_DEV.md).

The development guide includes:
- Detailed explanation of all 3 shell scripts
- Multiple development workflows
- NebulaGraph console access and commands
- Comprehensive troubleshooting guide

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
├── stores/
│   └── nebulagraph_store.go         # NebulaGraph state store implementation
├── components/
│   └── component.yml                # Dapr component configuration
├── Dockerfile                       # Component container
├── Dockerfile.test                  # Test container (optional)
├── docker-compose.yml               # Main Dapr component services
├── docker-compose.dependencies.yml  # NebulaGraph dependencies
├── init_nebula.sh                   # NebulaGraph cluster initialization
├── setup_dev.sh                     # One-stop development setup
├── test_component.sh                # Comprehensive test suite
├── README.md                        # Main documentation (this file)
├── README_DEV.md                    # Development setup guide
└── .gitignore                       # Git ignore rules
```

### Script Files Overview

- **`setup_dev.sh`**: Complete development environment setup (calls other scripts)
- **`init_nebula.sh`**: NebulaGraph cluster initialization (required for development)
- **`test_component.sh`**: Comprehensive test suite with automatic schema setup

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

### Quick Fixes

1. **"Space not found" errors**: Run `./init_nebula.sh` to initialize the cluster
2. **Component won't start**: Ensure dependencies are running and cluster is initialized
3. **Network issues**: Verify all services are on the same Docker network
4. **Test failures**: The test script handles schema creation automatically

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

# Check NebulaGraph cluster status
./init_nebula.sh

# Run tests
./test_component.sh
```

For detailed troubleshooting, see [README_DEV.md](README_DEV.md).

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

For detailed development setup, see [README_DEV.md](README_DEV.md).

Quick local development:

```bash
# Install dependencies
go mod download

# Build the component (creates 'nebulagraph' binary)
go build

# Run locally (requires NebulaGraph running and initialized)
export DAPR_COMPONENT_SOCKETS_FOLDER=/tmp/dapr-components-sockets
mkdir -p $DAPR_COMPONENT_SOCKETS_FOLDER
./nebulagraph
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

### Development Workflow

```bash
# Fresh environment setup
docker-compose -f docker-compose.dependencies.yml up -d
./setup_dev.sh

# Daily development
docker-compose up -d
./test_component.sh  # Run when making changes
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

## 🌐 NebulaGraph Studio (Web Interface)

NebulaGraph Studio provides a powerful web-based management interface for exploring and managing your graph data.

### Starting Studio

```bash
# Start Studio along with dependencies
docker-compose -f docker-compose.dependencies.yml --profile studio up -d

# Or start Studio separately if dependencies are already running
docker-compose -f docker-compose.dependencies.yml --profile studio up -d nebula-studio
```

### Accessing Studio

1. Open your browser and navigate to: http://localhost:7001
2. Configure the connection:
   - **Host**: `nebula-graphd` (or `localhost` if accessing from browser)
   - **Port**: `9669`
   - **Username**: `root`
   - **Password**: `nebula`

### Studio Features

- **Visual Graph Exploration**: Interactive graph visualization
- **Query Interface**: Execute nGQL queries with syntax highlighting
- **Schema Management**: Visual schema design and management
- **Performance Monitoring**: Real-time query performance metrics
- **Data Import/Export**: Import data from CSV files or export results
- **Multi-Space Support**: Manage multiple graph spaces

### Using Studio with Dapr State Data

After running your Dapr component tests, you can visualize the stored state data:

```sql
-- Switch to the dapr_state space
USE dapr_state;

-- View all state vertices
MATCH (v:state) RETURN v LIMIT 50;

-- Explore data with filters
MATCH (v:state) WHERE v.state.data CONTAINS "test" RETURN v;
```

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
