# NebulaGraph Infrastructure

NebulaGraph cluster setup for Dapr component development.

## Quick Commands

```bash
# From dependencies/ directory
./environment_setup.sh start    # Start all services (including NebulaGraph)
./environment_setup.sh status   # Check NebulaGraph cluster status
./environment_setup.sh stop     # Stop all services
./environment_setup.sh clean    # Reset and clean environment
```

## What's Included

- **NebulaGraph Cluster**: metad, storaged, graphd services with automatic initialization
- **NebulaGraph Studio**: Web UI available at http://localhost:7001
- **Health Checks**: Automatic readiness verification
- **Schema Setup**: `dapr_state` space and `state` tag created automatically

## Cluster Services

| Service | Container | Port | Purpose |
|---------|-----------|------|---------|
| Meta | nebula-metad | 9559 | Metadata management |
| Storage | nebula-storaged | 9779 | Data storage |
| Graph | nebula-graphd | 9669 | Query processing |
| Studio | nebula-studio | 7001 | Web interface |

## Direct Access

```bash
# Connect via console (requires nebula-console installed)
nebula-console -addr nebula-graphd -port 9669 -u root -p nebula

# Example queries
USE dapr_state;
SHOW HOSTS;
MATCH (v:state) RETURN v LIMIT 10;
```
cd ../
./environment_setup.sh

# That's it! The script handles everything:
# - Prerequisites validation
# - Docker network creation
# - NebulaGraph cluster startup
# - Cluster initialization
# - Readiness verification
```

### For Daily Development
```bash
# Start environment (from dependencies folder)
cd ../
./environment_setup.sh start

# Check what's running
./environment_setup.sh status

# View logs if needed
./environment_setup.sh logs

# Stop when done
./environment_setup.sh stop
```

### For Maintenance
```bash
./environment_setup.sh test     # Test connectivity
./environment_setup.sh clean    # Clean reset (removes all data)
./environment_setup.sh init     # Re-initialize cluster only
```

## Available Commands

All operations are handled by the single `environment_setup.sh` script:

| Command | Description |
|---------|-------------|
| `./environment_setup.sh` | Complete environment setup with prerequisites (default) |
| `./environment_setup.sh start` | Start NebulaGraph cluster (same as above) |
| `./environment_setup.sh stop` | Stop NebulaGraph dependencies |
| `./environment_setup.sh status` | Show dependency status |
| `./environment_setup.sh logs` | Show dependency logs |
| `./environment_setup.sh init` | Initialize NebulaGraph cluster |
| `./environment_setup.sh test` | Test NebulaGraph services connectivity |
| `./environment_setup.sh clean` | Clean up dependencies (volumes and networks) |
| `./environment_setup.sh help` | Show detailed help |

## Prerequisites (Automatically Checked)

The `environment_setup.sh` script automatically checks for and provides installation instructions for:

**Core Development Prerequisites:**
- **Docker**: Container runtime
- **Docker Compose**: Multi-container orchestration  
- **Dapr**: Distributed application runtime
- **Go 1.24.5+**: Go programming language

**Testing Prerequisites:**
- **curl**: HTTP API testing (for HTTP interface validation)
- **grpcurl**: gRPC API testing (for gRPC interface validation)
- **jq**: JSON parsing (for test result processing)

## Access Points

- **NebulaGraph Studio**: http://localhost:7001 (Web management interface)
- **NebulaGraph Graph Service**: localhost:9669 (Client connections)
- **NebulaGraph Meta Service**: localhost:9559 (Cluster metadata)
- **NebulaGraph Storage Service**: localhost:9779 (Data storage)

## Default Credentials

- **Username**: `root`
- **Password**: `nebula`

## Notes

- **Single Script Solution**: All operations are now handled by one unified `environment_setup.sh` script
- **Prerequisites Validation**: Automatic checking and installation guidance for all required tools
- **Infrastructure Focus**: Script manages only NebulaGraph Docker containers, not applications that use them
- **Comprehensive Testing**: Built-in connectivity testing for all NebulaGraph services
- **Data Persistence**: Volumes are persisted between restarts
- **Clean Operations**: Easy cleanup and reset capabilities
- **Default Credentials**: Username `root`, password `nebula`

## Migration Note

If you were previously using `./deps.sh`, all functionality has been consolidated into `./environment_setup.sh`. Simply replace your old commands:

- `./deps.sh start` → `./environment_setup.sh start`
- `./deps.sh stop` → `./environment_setup.sh stop`
- `./deps.sh status` → `./environment_setup.sh status`
- `./deps.sh test` → `./environment_setup.sh test`
- etc.
