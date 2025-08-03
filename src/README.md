# NebulaGraph Dapr Integration

Clean separation of infrastructure and application components for NebulaGraph with Dapr.

## Architecture Overview

```
src/
├── setup/                          # 🏗️  Complete Setup Organization
│   ├── dependencies/               # Infrastructure layer
│   │   ├── docker-compose.yml      # NebulaGraph containers  
│   │   ├── init_nebula.sh          # Cluster initialization
│   │   ├── deps.sh                 # Infrastructure management
│   │   └── README.md               # Infrastructure docs
│   └── projects/                   # Deployment configurations
│       ├── docker/                 # Docker-based deployment
│       │   └── components/         # Docker component configs
│       └── local/                  # Local development
│           ├── apps.sh             # Application management
│           └── components/         # Local component configs
├── dapr-pluggable/                 # � Dapr Component (Go)
├── NebulaGraphTestApi/             # 🌐 Test API (.NET)
└── nebulagraph_test.sln           # Solution file
```

## Quick Start

### 1. Start Infrastructure Dependencies
```bash
cd setup/dependencies
./deps.sh start     # Start NebulaGraph cluster
./deps.sh init      # Initialize cluster (first time only)
```

### 2. Start Applications
```bash
cd ../projects/local
./apps.sh start     # Start Dapr component + TestAPI
```

### 3. Test the Integration
```bash
./apps.sh test      # Run integration tests
```

## Management Scripts

| Script | Purpose | Location |
|--------|---------|----------|
| `setup/dependencies/deps.sh` | Manage NebulaGraph infrastructure | Infrastructure layer |
| `setup/projects/local/apps.sh` | Manage Dapr components and API | Local development layer |

## Service Endpoints

### Infrastructure (setup/dependencies/deps.sh)
- **NebulaGraph Studio**: http://localhost:7001 (Web management)
- **NebulaGraph Graph Service**: localhost:9669 (Client connections)

### Applications (setup/projects/local/apps.sh)
- **TestAPI**: http://localhost:5000
- **TestAPI Swagger**: http://localhost:5000/swagger
- **Dapr Component**: http://localhost:3500
- **Dapr TestAPI Sidecar**: http://localhost:3501

## Clean Separation Benefits

✅ **Infrastructure vs Application** - Clear boundaries between database setup and application code
✅ **Environment-Specific Configs** - Separate configurations for local vs docker development
✅ **Independent Management** - Start/stop infrastructure and applications separately  
✅ **Development Workflow** - Restart apps without touching infrastructure
✅ **Deployment Flexibility** - Easy switching between local and containerized setups
✅ **Maintenance** - Easier to maintain and understand each layer

## Development Workflow

```bash
# 1. One-time infrastructure setup
cd setup/dependencies && ./deps.sh start && ./deps.sh init

# 2. Daily development cycle
cd ../projects/local && ./apps.sh restart    # Restart applications only

# 3. Full cleanup when needed
./apps.sh stop                               # Stop applications
cd ../../dependencies && ./deps.sh clean     # Clean infrastructure
```

## Documentation

- [Setup Documentation](setup/dependencies/README.md) - Infrastructure management
- [Component Documentation](dapr-pluggable/README.md) - Dapr component details
- [API Documentation](NebulaGraphTestApi/README.md) - TestAPI details

## Testing

```bash
# Test infrastructure
cd setup/dependencies && ./deps.sh status

# Test applications  
cd ../projects/local && ./apps.sh test

# Full integration test
./apps.sh restart && ./apps.sh test
```
