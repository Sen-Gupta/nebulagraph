# NebulaGraph Dapr Full Stack

Complete integration testing environment for NebulaGraph with Dapr components and .NET TestAPI.

## Quick Start

```bash
# Start the complete stack
./full-stack.sh up

# Run comprehensive tests
./full-stack.sh test

# Stop everything
./full-stack.sh down
```

## What's Included

This full stack setup includes:

### 🗃️ **NebulaGraph Database Cluster**
- **nebula-metad**: Metadata service
- **nebula-storaged**: Storage service  
- **nebula-graphd**: Graph query service
- **nebula-console**: Command-line interface
- **nebula-studio**: Web-based management interface

### 🔌 **Dapr Pluggable Component**
- **nebulagraph-component**: Custom NebulaGraph state store component
- **daprd-pluggable**: Dapr sidecar for the pluggable component

### 🌐 **TestAPI Application**
- **nebulagraph-test-api**: .NET 9 web API for testing Dapr integration
- **daprd-test-api**: Dapr sidecar for the TestAPI

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   TestAPI       │    │  Dapr Pluggable │    │  NebulaGraph    │
│                 │    │   Component     │    │   Cluster       │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ .NET API    │ │    │ │   Go App    │ │    │ │  metad      │ │
│ │ :5000       │ │    │ │             │ │    │ │  :9559      │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ Dapr        │◄┼────┼►│ Dapr        │◄┼────┼►│ storaged    │ │
│ │ :3501       │ │    │ │ :3500       │ │    │ │ :9779       │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    │ ┌─────────────┐ │
                                              │ │ graphd      │ │
                                              │ │ :9669       │ │
                                              │ └─────────────┘ │
                                              │ ┌─────────────┐ │
                                              │ │ studio      │ │
                                              │ │ :7001       │ │
                                              │ └─────────────┘ │
                                              └─────────────────┘
```

## Service Endpoints

| Service | URL | Purpose |
|---------|-----|---------|
| **TestAPI** | http://localhost:5000 | Main API endpoints |
| **TestAPI Swagger** | http://localhost:5000/swagger | API documentation |
| **NebulaGraph Studio** | http://localhost:7001 | Graph visualization |
| **Dapr Pluggable API** | http://localhost:3500 | Direct component access |
| **Dapr TestAPI** | http://localhost:3501 | TestAPI sidecar |

## Management Commands

```bash
# Stack Management
./full-stack.sh up        # Start everything
./full-stack.sh down      # Stop everything  
./full-stack.sh restart   # Restart everything
./full-stack.sh clean     # Clean up volumes and networks

# Development
./full-stack.sh build     # Build all Docker images
./full-stack.sh logs      # Show logs from all services
./full-stack.sh status    # Check service health

# Testing
./full-stack.sh test      # Run comprehensive tests
./full-stack.sh init      # Initialize NebulaGraph cluster
```

## Testing Scenarios

### 1. **Direct Dapr Component Testing**
Test the NebulaGraph component directly via Dapr:

```bash
# Store data via Dapr
curl -X POST "http://localhost:3500/v1.0/state/nebulagraph-state" \
  -H "Content-Type: application/json" \
  -d '[{"key": "test1", "value": "Hello NebulaGraph!"}]'

# Retrieve data via Dapr  
curl "http://localhost:3500/v1.0/state/nebulagraph-state/test1"

# Delete data via Dapr
curl -X DELETE "http://localhost:3500/v1.0/state/nebulagraph-state/test1"
```

### 2. **TestAPI Integration Testing**
Test the complete integration via the .NET API:

```bash
# Store data via TestAPI
curl -X POST "http://localhost:5000/api/state" \
  -H "Content-Type: application/json" \
  -d '{"key": "user1", "value": {"name": "John", "age": 30}}'

# Retrieve data via TestAPI
curl "http://localhost:5000/api/state/user1"

# List all keys via TestAPI
curl "http://localhost:5000/api/state"

# Delete data via TestAPI
curl -X DELETE "http://localhost:5000/api/state/user1"
```

### 3. **gRPC Testing**
Test the gRPC service:

```bash
cd NebulaGraphTestApi
./test_grpc.sh
```

## Data Flow

1. **TestAPI** receives HTTP requests
2. **TestAPI** calls **Dapr sidecar** (port 3501) 
3. **Dapr sidecar** communicates with **Dapr pluggable component** (port 3500)
4. **Pluggable component** stores/retrieves data from **NebulaGraph**
5. **NebulaGraph** persists data as graph vertices and edges

## Development Workflow

### Initial Setup
```bash
# Clone and navigate to project
cd /path/to/nebulagraph

# Start the full stack
./full-stack.sh up

# Wait for initialization, then test
./full-stack.sh test
```

### Daily Development
```bash
# Check status
./full-stack.sh status

# View logs during development
./full-stack.sh logs

# Restart after changes
./full-stack.sh restart
```

### Debugging
```bash
# Check individual service logs
docker logs nebulagraph-test-api
docker logs nebulagraph-dapr-component
docker logs daprd-test-api

# Access NebulaGraph console
docker exec -it nebula-console nebula-console -addr nebula-graphd -port 9669 -u root -p nebula

# Access NebulaGraph Studio
open http://localhost:7001
```

## Troubleshooting

### Common Issues

**Services not starting**: 
```bash
./full-stack.sh status
./full-stack.sh logs
```

**NebulaGraph cluster issues**:
```bash
./full-stack.sh init
```

**Port conflicts**:
```bash
./full-stack.sh clean
./full-stack.sh up
```

**Data persistence issues**:
- Check NebulaGraph Studio at http://localhost:7001
- Verify data in console: `USE dapr_state; MATCH (v:state) RETURN v;`

### Health Checks

The stack includes automatic health checks for:
- NebulaGraph cluster connectivity
- Dapr component registration  
- TestAPI responsiveness
- Studio web interface

Run `./full-stack.sh status` to see current health status.

## Performance Testing

The full stack supports performance and load testing:

```bash
# Run concurrent requests
for i in {1..100}; do
  curl -X POST "http://localhost:5000/api/state" \
    -H "Content-Type: application/json" \
    -d "{\"key\": \"perf-test-$i\", \"value\": \"data-$i\"}" &
done
wait

# Verify all data was stored
curl "http://localhost:5000/api/state" | jq length
```

## Next Steps

1. **Develop your application**: Use the TestAPI as a template
2. **Add custom components**: Extend the Dapr component as needed  
3. **Scale the setup**: Add more TestAPI instances with load balancing
4. **Production deployment**: Adapt the compose file for production use

## Contributing

When making changes:
1. Test with `./full-stack.sh test`
2. Update documentation as needed
3. Ensure all services start cleanly with `./full-stack.sh restart`
