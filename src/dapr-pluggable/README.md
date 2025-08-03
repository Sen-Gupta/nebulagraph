# NebulaGraph Dapr State Store Component

A Dapr pluggable component that provides state store functionality using NebulaGraph as the backend.

## 📁 Project Structure

```
src/dapr-pluggable/                   # Dapr pluggable component implementation
├── main.go                           # Component entry point  
├── stores/
│   └── nebulagraph_store.go          # NebulaGraph state store implementation
├── setup/
│   └── docker/
│       ├── docker-compose.yml        # Component and Dapr runtime
│       └── run_docker_pluggable.sh   # Complete component management
├── tests/
│   └── test_component.sh             # Comprehensive test suite
├── go.mod                            # Go module definition
├── go.sum                            # Go dependency checksums
├── Dockerfile                        # Component container
├── Dockerfile.test                   # Test container
├── README.md                         # Main documentation
└── README_DEV.md                     # Development setup guide
```

### Component Dependencies

The NebulaGraph infrastructure is managed separately:
```
src/dependencies/                     # NebulaGraph infrastructure
├── docker-compose.yml                # NebulaGraph cluster (metad, storaged, graphd, studio)
├── environment_setup.sh              # Complete environment management
├── init_nebula.sh                    # Cluster initialization
└── README.md                         # Infrastructure documentation
```

### Project Organization

The project follows a clean, modular structure:

- **`src/dapr-pluggable/`**: Complete Dapr component implementation
- **`src/dependencies/`**: NebulaGraph infrastructure management
- **`stores/`**: State store implementations (extensible for future stores)
- **`setup/`**: Deployment and management scripts
- **`tests/`**: All testing-related files
- **Component-level**: Core application code and documentation

This structure allows for:
- Clear separation between infrastructure and component code
- Easy extension with additional store types
- Professional testing organization
- Simplified deployment and management

### Binary Names

- **Local Development**: `nebulagraph` (follows Go module naming)
- **Docker Container**: `/component` (follows Dapr component conventions)

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose
- Dapr CLI
- Go 1.24.5 or later
- curl (for testing)

All prerequisites are automatically validated by our scripts.

### Option 1: Complete Automated Setup

For a full end-to-end setup with infrastructure and component:

```bash
# 1. Set up NebulaGraph infrastructure
cd src/dependencies/
./environment_setup.sh setup

# 2. Deploy and test the Dapr component
cd ../dapr-pluggable/setup/docker/
./run_docker_pluggable.sh start
./run_docker_pluggable.sh test-full
```

### Option 2: Development Setup

For development with step-by-step control:

```bash
# 1. Start NebulaGraph infrastructure
cd src/dependencies/
./environment_setup.sh start
./environment_setup.sh init    # Initialize the cluster

# 2. Validate infrastructure
./environment_setup.sh test
./environment_setup.sh status

# 3. Build and run the component
cd ../dapr-pluggable/setup/docker/
./run_docker_pluggable.sh validate  # Check prerequisites
./run_docker_pluggable.sh start     # Deploy component

# 4. Run comprehensive tests
./run_docker_pluggable.sh test-full # Full test suite
```

### Verification

After setup, verify everything is working:

```bash
# Check NebulaGraph cluster status
cd src/dependencies/
./environment_setup.sh status

# Check component status
cd ../dapr-pluggable/setup/docker/
./run_docker_pluggable.sh status

# Run tests to validate functionality
./run_docker_pluggable.sh test-full
```

Both approaches provide a working NebulaGraph + Dapr environment with comprehensive testing.

## 🔧 Manual Development Setup

If you prefer step-by-step control, you can manually set up each component:

### 1. Start NebulaGraph Infrastructure

```bash
cd src/dependencies/
./environment_setup.sh start
./environment_setup.sh init  # Initialize the cluster
```

### 2. Build and Start the Dapr Component

```bash
cd ../dapr-pluggable/setup/docker/
./run_docker_pluggable.sh validate  # Check prerequisites
./run_docker_pluggable.sh start     # Build and deploy
```

### 3. Test the Component

```bash
# Run comprehensive tests
./run_docker_pluggable.sh test-full

# Or run individual tests
cd ../../tests/
./test_component.sh
```

**Note**: The test script automatically creates the required `dapr_state` space and schema if they don't exist.

## ✅ Validate Your Setup

After setting up your development environment, validate that everything is working correctly:

### Quick Validation

```bash
# Check infrastructure status
cd src/dependencies/
./environment_setup.sh status

# Run comprehensive component tests
cd ../dapr-pluggable/setup/docker/
./run_docker_pluggable.sh test-full
```

### Infrastructure Validation

The environment setup script provides comprehensive validation:

```bash
cd src/dependencies/
./environment_setup.sh test    # Test NebulaGraph connectivity and operations
./environment_setup.sh status  # Show status of all services
./environment_setup.sh logs    # View logs if issues occur
```

### Component Validation

The component management script provides detailed testing:

```bash
cd src/dapr-pluggable/setup/docker/
./run_docker_pluggable.sh validate  # Check prerequisites
./run_docker_pluggable.sh status    # Show component status  
./run_docker_pluggable.sh test-full # Run comprehensive test suite
```

The test suite validates:
- ✅ Prerequisites (Docker, Docker Compose, curl, Go)
- ✅ All Docker containers are running
- ✅ Network connectivity between services
- ✅ NebulaGraph cluster health and accessibility
- ✅ Dapr component registration and response
- ✅ Complete CRUD operations (SET, GET, DELETE, BULK)
- ✅ Data persistence verification
- ✅ Cleanup operations

### Manual Validation Commands

If you prefer to validate manually or troubleshoot specific issues:

#### 1. Check Prerequisites
```bash
# Verify required tools are installed
docker --version
docker-compose --version
curl --version
```

#### 2. Check Container Status
```bash
# Check infrastructure status
cd src/dependencies/
./environment_setup.sh status

# Check component status
cd ../dapr-pluggable/setup/docker/
./run_docker_pluggable.sh status

# Expected infrastructure containers:
# - nebula-metad (NebulaGraph metadata service)
# - nebula-storaged (NebulaGraph storage service)  
# - nebula-graphd (NebulaGraph graph service)
# - nebula-console (NebulaGraph console for debugging)

# Expected component containers:
# - nebulagraph-dapr-component (your Dapr component)
# - daprd-nebulagraph (Dapr sidecar)
```

#### 3. Test NebulaGraph Connectivity
```bash
# Test NebulaGraph cluster is responsive
docker exec nebula-console /usr/local/bin/nebula-console \
  -addr nebula-graphd -port 9669 -u root -p nebula -e "SHOW HOSTS;"

# Check if dapr_state space exists (will show error if not initialized)
docker exec nebula-console /usr/local/bin/nebula-console \
  -addr nebula-graphd -port 9669 -u root -p nebula -e "USE dapr_state; SHOW TAGS;"
```

#### 4. Test Dapr Component Accessibility
```bash
# Test Dapr sidecar is responding
curl -s http://localhost:3500/v1.0/state/nebulagraph-state/test-key
# Expected: Empty response with 204 status (key doesn't exist)
```

#### 5. Test Complete CRUD Operations
```bash
# Test SET operation
curl -X POST http://localhost:3500/v1.0/state/nebulagraph-state \
  -H "Content-Type: application/json" \
  -d '[{"key": "validation-test", "value": "Hello Setup!"}]'
# Expected: Empty response with 204 status

# Test GET operation  
curl -X GET http://localhost:3500/v1.0/state/nebulagraph-state/validation-test
# Expected: "Hello Setup!"

# Test DELETE operation
curl -X DELETE http://localhost:3500/v1.0/state/nebulagraph-state/validation-test
# Expected: Empty response with 204 status

# Verify deletion
curl -X GET http://localhost:3500/v1.0/state/nebulagraph-state/validation-test
# Expected: Empty response with 204 status (key no longer exists)
```

### Validation Troubleshooting

If validation fails, here are common solutions:

| Issue | Solution |
|-------|----------|
| **Prerequisites missing** | Install Docker, Docker Compose, and curl |
| **Containers not running** | Use our management scripts to start services |
| **NebulaGraph not accessible** | Wait 30s for startup, check container logs |
| **"Space not found" error** | Run `./init_nebula.sh` to initialize the cluster |
| **Dapr component not responding** | Check component logs: `docker logs nebulagraph-dapr-component` |
| **Network connectivity issues** | Restart services: `docker-compose down && docker-compose up -d` |
| **CRUD operations failing** | Ensure NebulaGraph is initialized and accessible |

### Expected Validation Output

When everything is working correctly, our test suite provides comprehensive validation output:

```
======================================
NebulaGraph Dapr Component - Setup Validation
======================================

======================================
1. Prerequisites Check
======================================
✅ Docker is installed: Docker version 24.0.0
✅ Docker Compose is installed: docker-compose version 2.20.0
✅ curl is installed: curl 7.81.0

======================================
2. Docker Containers Status
======================================
✅ Container 'nebula-metad' is running
✅ Container 'nebula-storaged' is running
✅ Container 'nebula-graphd' is running
✅ Container 'nebula-console' is running
✅ Container 'nebulagraph-dapr-component' is running
✅ Container 'daprd-nebulagraph' is running

======================================
3. Network Connectivity
======================================
ℹ️  Checking Docker network configuration...
✅ Docker network 'nebula-net' exists
✅ Key containers are connected to the network

======================================
4. NebulaGraph Cluster Validation
======================================
✅ NebulaGraph cluster is accessible and responsive
✅ NebulaGraph 'dapr_state' space exists and is accessible

======================================
5. Dapr Component Validation
======================================
✅ Dapr sidecar is responding on port 3500
✅ Dapr component is responding to state requests

======================================
6. CRUD Operations Test
======================================
✅ SET operation successful
✅ GET operation successful - data retrieved correctly
✅ DELETE operation successful
✅ Deletion verified - key no longer exists

======================================
Validation Summary
======================================
✅ 🎉 All validation checks passed! Your development setup is working correctly.

Your NebulaGraph Dapr component is ready for development!

Next steps:
  • Start developing with your Dapr component
  • Run './test_component.sh' for comprehensive testing
  • Check logs with: docker logs nebulagraph-dapr-component
  • Access NebulaGraph Studio at: http://localhost:7001 (if Studio profile is running)
```

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

### Script Files Overview

The project uses consolidated, single-purpose scripts:

**Infrastructure Management** (in `src/dependencies/`):
- **`environment_setup.sh`**: Complete NebulaGraph infrastructure lifecycle (setup, start, stop, status, logs, test, clean, init)

**Component Management** (in `setup/docker/`):
- **`run_docker_pluggable.sh`**: Complete Dapr component lifecycle (validate, start, test, test-full, status, logs, stop, clean)

**Testing** (in `tests/`):
- **`test_component.sh`**: Comprehensive test suite with automatic schema setup and clear pass/fail indicators

**Initialization** (in project root):
- **`init_nebula.sh`**: NebulaGraph cluster initialization (called by environment_setup.sh)

## ⚙️ Component Configuration

The component is configured through the `src/components/docker-component.yml` file:

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

### Quick Diagnosis

Use our management scripts for quick issue resolution:

```bash
# Check infrastructure status
cd src/dependencies/
./environment_setup.sh status

# Check component status
cd ../dapr-pluggable/setup/docker/
./run_docker_pluggable.sh status

# Run comprehensive tests
./run_docker_pluggable.sh test-full
```

### Common Issues

1. **"Space not found" errors**: 
   ```bash
   cd src/dependencies/
   ./environment_setup.sh init
   ```

2. **Component won't start**: Ensure infrastructure is running:
   ```bash
   cd src/dependencies/
   ./environment_setup.sh start
   ```

3. **Network issues**: Clean and restart everything:
   ```bash
   cd src/dapr-pluggable/setup/docker/
   ./run_docker_pluggable.sh clean
   cd ../../../dependencies/
   ./environment_setup.sh clean
   ./environment_setup.sh setup
   ```

### Debug Commands

```bash
# View infrastructure logs
cd src/dependencies/
./environment_setup.sh logs

# View component logs  
cd ../dapr-pluggable/setup/docker/
./run_docker_pluggable.sh logs

# Test infrastructure connectivity
cd ../../../dependencies/
./environment_setup.sh test
```

For detailed troubleshooting, see [README_DEV.md](README_DEV.md).

## 🧹 Cleanup

### Quick Cleanup

Stop all services using our management scripts:

```bash
# Stop component
cd src/dapr-pluggable/setup/docker/
./run_docker_pluggable.sh stop

# Stop infrastructure
cd ../../../dependencies/
./environment_setup.sh stop
```

### Complete Cleanup

Remove all containers, networks, and volumes:

```bash
# Clean component (removes containers, images, networks)
cd src/dapr-pluggable/setup/docker/
./run_docker_pluggable.sh clean

# Clean infrastructure (removes containers, images, networks, volumes)
cd ../../../dependencies/
./environment_setup.sh clean
```

This will completely reset your environment for a fresh start.

## 🛠️ Development

### Development Workflow

For detailed development setup, see [README_DEV.md](README_DEV.md).

Quick development cycle:

```bash
# 1. Set up infrastructure (one time)
cd src/dependencies/
./environment_setup.sh setup

# 2. Start development cycle
cd ../dapr-pluggable/setup/docker/
./run_docker_pluggable.sh start
./run_docker_pluggable.sh test-full

# 3. Make changes to code...

# 4. Test changes
./run_docker_pluggable.sh stop
./run_docker_pluggable.sh start  # Rebuilds automatically
./run_docker_pluggable.sh test-full
```

### Local Development

```bash
# Install dependencies
go mod download

# Build the component (creates 'nebulagraph' binary)
go build

# Run locally (requires infrastructure running)
export DAPR_COMPONENT_SOCKETS_FOLDER=/tmp/dapr-components-sockets
mkdir -p $DAPR_COMPONENT_SOCKETS_FOLDER
./nebulagraph
```

### Testing Changes

After making changes to the component:

```bash
# Quick restart and test
cd setup/docker/
./run_docker_pluggable.sh stop
./run_docker_pluggable.sh start  # Rebuilds automatically
./run_docker_pluggable.sh test-full

# Or run tests directly
cd ../../tests/
./test_component.sh
```

### Daily Development Workflow

```bash
# Start infrastructure (if stopped)
cd src/dependencies/
./environment_setup.sh start

# Start component development
cd ../dapr-pluggable/setup/docker/
./run_docker_pluggable.sh start

# Make code changes...

# Test changes
./run_docker_pluggable.sh test-full

# When done
./run_docker_pluggable.sh stop
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

Studio is automatically included when you start the infrastructure:

```bash
# Studio starts automatically with all other services
cd src/dependencies/
./environment_setup.sh start
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
