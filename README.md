# NebulaGraph Dapr State Store Component

A Dapr pluggable component that provides state store functionality using NebulaGraph as the backend.

## 🚀 Quick Start

### 1. Start Dependencies (NebulaGraph)

First, start the NebulaGraph cluster (this will create the shared network):

```bash
# Start NebulaGraph services (creates the nebula-net network)
docker-compose -f docker-compose.dependencies.yml up -d

# Wait for services to be ready (about 30 seconds)
docker-compose -f docker-compose.dependencies.yml logs -f nebula-graphd
```

### 2. Start the Dapr Component

Once NebulaGraph is running, start the Dapr component:

```bash
# Start the NebulaGraph Dapr component and Dapr runtime
docker-compose up --build -d

# Check logs
docker-compose logs -f
```

### 3. Test the Component (Optional)

Run the test application to verify everything works:

```bash
# Run test application
docker-compose --profile test up test-app

# Or test manually with curl
curl -X POST http://localhost:3500/v1.0/state/nebulagraph-state \
  -H "Content-Type: application/json" \
  -d '[{"key": "test-key", "value": "Hello NebulaGraph!"}]'

curl -X GET http://localhost:3500/v1.0/state/nebulagraph-state/test-key
```

## 📁 File Structure

```
.
├── main.go                           # Component entry point
├── components/
│   └── state_store.go               # NebulaGraph state store implementation
├── components/
│   └── nebulagraph-state.yaml       # Dapr component configuration
├── Dockerfile                       # Component container
├── Dockerfile.test                  # Test application container
├── docker-compose.yml               # Main Dapr component services
├── docker-compose.dependencies.yml  # NebulaGraph dependencies
└── component.yml                    # Standalone component config
```

## ⚙️ Configuration

The component can be configured through Dapr metadata:

```yaml
metadata:
- name: hosts
  value: "nebula-graphd"  # NebulaGraph host
- name: port
  value: "9669"           # NebulaGraph port
- name: username
  value: "root"           # Username
- name: password
  value: "nebula"         # Password
- name: space
  value: "dapr_state"     # NebulaGraph space
```

## 🧹 Cleanup

Stop and remove all services:

```bash
# Stop main services
docker-compose down -v

# Stop dependencies
docker-compose -f docker-compose.dependencies.yml down -v

# Remove network
docker network rm nebulagraph_nebula-net
```

## 🛠️ Development

Build and run locally:

```bash
# Build the component
go build -o nebulagraph-component .

# Create socket directory
mkdir -p /tmp/dapr-components-sockets

# Run the component
./nebulagraph-component
```

## 📋 Requirements

- Docker & Docker Compose
- Go 1.21+ (for local development)
- NebulaGraph v3.8.0+
- Dapr runtime v1.14.0+
