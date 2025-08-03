# NebulaGraph Setup

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

### 3. Start Applications
```bash
cd ../../
./apps.sh start
```

## Available Commands

| Command | Description |
|---------|-------------|
| `./deps.sh start` | Start NebulaGraph dependencies |
| `./deps.sh stop` | Stop NebulaGraph dependencies |
| `./deps.sh status` | Show dependency status |
| `./deps.sh logs` | Show dependency logs |
| `./deps.sh init` | Initialize NebulaGraph cluster |
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

- This setup uses Docker containers for NebulaGraph infrastructure only
- Application components (Dapr components and TestAPI) are managed separately by `../apps.sh`
- Volumes are persisted between restarts
- Use `./deps.sh clean` to remove all data and start fresh
- Use `../../apps.sh` to manage Dapr components and TestAPI
