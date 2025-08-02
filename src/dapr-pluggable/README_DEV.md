# NebulaGraph Dapr Component - Development Setup

## Quick Start (Development Environment)

1. **Start NebulaGraph dependencies:**
   ```bash
   docker-compose -f docker-compose.dependencies.yml up -d
   ```

2. **Setup development environment (run once):**
   ```bash
   ./setup_dev.sh
   ```

3. **Run your Dapr component:**
   ```bash
   docker-compose up -d
   ```

That's it! Your NebulaGraph Dapr component is ready.

## Development Scripts Overview

This project includes 3 shell scripts for different purposes:

### 🚀 `setup_dev.sh` - One-Stop Development Setup
**Purpose**: Complete development environment setup in one command
**When to use**: First time setup or full environment reset
**What it does**:
- Waits for NebulaGraph cluster to be ready
- Calls `init_nebula.sh` to initialize the cluster
- Calls `test_component.sh` to create schema and run tests
- Provides status feedback and next steps

### 🔧 `init_nebula.sh` - Cluster Initialization
**Purpose**: Initialize NebulaGraph cluster for development
**When to use**: Required once after starting NebulaGraph dependencies
**What it does**:
- Registers storage hosts with the cluster (ADD HOSTS command)
- Required for single-node NebulaGraph development setup
- Only needed in development (production clusters are pre-configured)

### 🧪 `test_component.sh` - Component Testing Suite
**Purpose**: Comprehensive testing of the Dapr component
**When to use**: Development testing, CI/CD, validation
**What it does**:
- **Test 0**: Creates `dapr_state` space and schema automatically
- **Tests 1-6**: Full CRUD operations testing
- Validates data persistence in NebulaGraph
- Can be run independently for testing

## What the setup does

- Initializes the NebulaGraph cluster (required for development)
- Creates the `dapr_state` space and schema
- Runs comprehensive tests to validate everything works
- Shows you how to access NebulaGraph console for debugging

## Manual Steps (Individual Script Usage)

If you prefer to run scripts individually or need granular control:

### Option 1: Full Manual Setup
```bash
# 1. Start dependencies
docker-compose -f docker-compose.dependencies.yml up -d

# 2. Initialize NebulaGraph cluster (required once)
./init_nebula.sh

# 3. Run tests and create schema
./test_component.sh
```

### Option 2: Testing Only (if cluster already initialized)
```bash
# Just run the test suite
./test_component.sh
```

### Option 3: Cluster Initialization Only
```bash
# Just initialize the cluster (useful for debugging)
./init_nebula.sh
```

## Development Workflows

### 🔄 Daily Development
```bash
# Start/restart your component for testing
docker-compose up -d

# Run tests when you make changes
./test_component.sh
```

### 🧹 Fresh Environment Reset
```bash
# Stop everything
docker-compose down
docker-compose -f docker-compose.dependencies.yml down

# Start fresh
docker-compose -f docker-compose.dependencies.yml up -d
./setup_dev.sh
```

### 🐛 Debugging Issues
```bash
# Check NebulaGraph cluster status
./init_nebula.sh

# Check component functionality
./test_component.sh

# Access NebulaGraph console directly
docker exec -it nebula-console nebula-console -addr nebula-graphd -port 9669 -u root -p nebula

# Access NebulaGraph Studio for visual debugging at http://localhost:7001
# (Studio is automatically started with dependencies)
```

## NebulaGraph Console Access

For debugging and manual data inspection:

```bash
docker exec -it nebula-console nebula-console -addr nebula-graphd -port 9669 -u root -p nebula
```

**Useful console commands:**
```sql
-- Check spaces
SHOW SPACES;

-- Use the dapr_state space
USE dapr_state;

-- Check schema
SHOW TAGS;
DESCRIBE TAG state;

-- View stored data
MATCH (v:state) RETURN v LIMIT 10;
```

## NebulaGraph Studio (Web Interface)

For visual graph exploration and easier management, Studio is automatically started with the dependencies:

```bash
# Access via browser: http://localhost:7001
# Connection: nebula-graphd:9669, root/nebula
```

**Studio Benefits for Development:**
- Visual data exploration
- Query building with autocomplete
- Real-time performance monitoring
- Easy schema visualization
- Import/export data tools

## Test Suite Details

The `test_component.sh` includes comprehensive testing:

- **Test 0**: Space and Schema Setup
  - Checks if `dapr_state` space exists
  - Creates space and `state` tag if needed
  - Ensures proper schema is in place

- **Test 1**: Component Initialization 
  - Validates Dapr component starts correctly
  - Checks component registration

- **Test 2**: Data Storage (CREATE)
  - Tests storing new state data
  - Validates data is written to NebulaGraph

- **Test 3**: Data Retrieval (READ)  
  - Tests reading stored state data
  - Validates data consistency

- **Test 4**: Data Updates (UPDATE)
  - Tests updating existing state data
  - Validates changes are persisted

- **Test 5**: Data Deletion (DELETE)
  - Tests deleting state data
  - Validates data is removed from NebulaGraph

- **Test 6**: Cleanup and Verification
  - Ensures test data is properly cleaned up
  - Validates system state after tests

All tests validate that data is properly persisted in NebulaGraph using the correct schema.

## Troubleshooting

### Common Issues

1. **"Space not found" errors**: Run `./init_nebula.sh` first
2. **"No storage host" errors**: NebulaGraph cluster needs initialization
3. **Component won't start**: Check if dependencies are running
4. **Tests fail**: Ensure schema is created (Test 0 handles this automatically)

### Health Checks

```bash
# Check all containers are running
docker ps

# Check NebulaGraph cluster status
docker exec nebula-console nebula-console -addr nebula-graphd -port 9669 -u root -p nebula -e "SHOW HOSTS"

# Check component logs
docker-compose logs nebulagraph-component
```
