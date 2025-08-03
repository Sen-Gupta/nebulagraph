# NebulaGraph Dependencies

This folder contains all the infrastructure setup files for NebulaGraph dependencies.

## Structure

```
dependencies/               # Docker infrastructure files
├── docker-compose.yml      # NebulaGraph cluster (metad, storaged, graphd, studio)
├── init_nebula.sh          # Cluster initialization script
├── deps.sh                 # Dependency management script
└── README.md              # This file
```

## Quick Start

### 1. Start NebulaGraph Dependencies
```bash
./deps.sh start
```

This starts:
- NebulaGraph Meta Service (port 9559)
- NebulaGraph Storage Service (port 9779) 
- NebulaGraph Graph Service (port 9669)
- NebulaGraph Studio Web UI (port 7001)
- NebulaGraph Console

### 2. Initialize the Cluster (First time only)
```bash
./deps.sh init
```

### 3. Test the Setup
```bash
./deps.sh test
```

### 4. Access NebulaGraph
```bash
# NebulaGraph Studio (Web Interface)
open http://localhost:7001

# Connect with credentials: root/nebula
```

## Typical Workflow

```bash
# First time setup
./deps.sh start    # Start services
./deps.sh init     # Initialize cluster
./deps.sh test     # Validate setup

# Daily usage
./deps.sh start    # Start services
./deps.sh test     # Quick health check

# Maintenance
./deps.sh status   # Check container status
./deps.sh logs     # View logs
./deps.sh stop     # Stop services
./deps.sh clean    # Clean reset (removes all data)
```

## Available Commands

| Command | Description |
|---------|-------------|
| `./deps.sh start` | Start NebulaGraph dependencies |
| `./deps.sh stop` | Stop NebulaGraph dependencies |
| `./deps.sh status` | Show dependency status |
| `./deps.sh logs` | Show dependency logs |
| `./deps.sh init` | Initialize NebulaGraph cluster |
| `./deps.sh test` | Test NebulaGraph services connectivity |
| `./deps.sh clean` | Clean up dependencies (volumes and networks) |

## Access Points

- **NebulaGraph Studio**: http://localhost:7001 (Web management interface)
- **NebulaGraph Graph Service**: localhost:9669 (Client connections)
- **NebulaGraph Meta Service**: localhost:9559 (Cluster metadata)
- **NebulaGraph Storage Service**: localhost:9779 (Data storage)

## Default Credentials

- **Username**: `root`
- **Password**: `nebula`

## Notes

- **Infrastructure Only**: This setup manages only NebulaGraph Docker containers
- **Testing**: Use `./deps.sh test` to validate all services are running correctly
- **Data Persistence**: Volumes are persisted between restarts
- **Clean Start**: Use `./deps.sh clean` to remove all data and start fresh
- **Credentials**: Default username `root`, password `nebula`
