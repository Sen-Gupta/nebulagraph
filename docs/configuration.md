# Configuration Guide

## Quick Setup

```bash
# 1. Infrastructure setup
cd src/dependencies && ./environment_setup.sh start

# 2. Start components  
cd ../dapr-pluggable-components && ./run_dapr_pluggables.sh start

# 3. Run examples
cd ../examples && ./run_dotnet_examples.sh start
```

## Environment Configuration

### Primary Environment File: `src/.env`

```env
# Database Connections
NEBULA_HOST=nebula-graphd
NEBULA_PORT=9669
NEBULA_USERNAME=root
NEBULA_PASSWORD=nebula

SCYLLA_HOSTS=scylladb-node1,scylladb-node2
SCYLLA_PORT=9042
SCYLLA_USERNAME=cassandra
SCYLLA_PASSWORD=cassandra

# Dapr Settings
DAPR_HTTP_PORT=3501
DAPR_GRPC_PORT=50001
DAPR_PLACEMENT_PORT=50005
DAPR_SCHEDULER_PORT=50006

# Component Settings
COMPONENT_SOCKET_PATH=/var/run/dapr-components-sockets

# Application Ports
DOT_NET_HOST_PORT=5092
DOT_NET_APP_PORT=80
```

## Component Configurations

### NebulaGraph State Store: `src/components/nebulagraph-state.yaml`

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
    value: "${NEBULA_HOST}"
  - name: port
    value: "${NEBULA_PORT}"
  - name: username
    value: "${NEBULA_USERNAME}"
  - name: password
    value: "${NEBULA_PASSWORD}"
  - name: space
    value: "dapr_state"
  - name: connectionTimeout
    value: "10s"
  - name: executionTimeout
    value: "30s"
```

### ScyllaDB State Store: `src/components/scylladb-state.yaml`

```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: scylladb-state
spec:
  type: state.scylladb-state
  version: v1
  metadata:
  - name: hosts
    value: "${SCYLLA_HOSTS}"
  - name: port
    value: "${SCYLLA_PORT}"
  - name: username
    value: "${SCYLLA_USERNAME}"
  - name: password
    value: "${SCYLLA_PASSWORD}"
  - name: keyspace
    value: "dapr_state"
  - name: consistency
    value: "LOCAL_QUORUM"
  - name: replicationFactor
    value: "3"
```

## Configuration Parameters

### NebulaGraph Parameters

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `hosts` | Graph service address | `localhost` | Yes |
| `port` | Graph service port | `9669` | Yes |
| `username` | Database username | `root` | Yes |
| `password` | Database password | `nebula` | Yes |
| `space` | NebulaGraph space | `dapr_state` | Yes |
| `connectionTimeout` | Connection timeout | `10s` | No |
| `executionTimeout` | Query timeout | `30s` | No |

### ScyllaDB Parameters

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `hosts` | Node addresses (comma-separated) | `localhost` | Yes |
| `port` | CQL port | `9042` | Yes |
| `username` | Database username | `cassandra` | Yes |
| `password` | Database password | `cassandra` | Yes |
| `keyspace` | Keyspace name | `dapr_state` | Yes |
| `consistency` | Consistency level | `LOCAL_QUORUM` | No |
| `replicationFactor` | Replication factor | `3` | No |
```

Reference in component:
```yaml
metadata:
- name: username
  secretKeyRef:
    name: nebulagraph-credentials
    key: username
- name: password
  secretKeyRef:
    name: nebulagraph-credentials
    key: password
```

## Docker Configuration

### Development Docker Compose

The component uses Docker Compose for local development:

```yaml
version: '3.8'
services:
  # Dapr sidecar
  daprd-nebulagraph:
    image: daprio/daprd:latest
    command: [
      "./daprd",
      "--app-id", "nebulagraph-test",
      "--dapr-http-port", "3501",
      "--dapr-grpc-port", "50001",
      "--resources-path", "/components",
      "--config", "/components/config.yaml",
      "--unix-domain-socket", "/var/run"
    ]
    volumes:
      - ../components:/components:ro
      - /var/run:/var/run
    ports:
      - "3501:3501"
      - "50001:50001"
    depends_on:
      - nebulagraph-dapr-component
    networks:
      - dapr-pluggable-net

  # NebulaGraph component
  nebulagraph-dapr-component:
    build: ../..
    container_name: nebulagraph-dapr-component
    volumes:
      - /var/run:/var/run
    depends_on:
      - nebula-graphd
    networks:
      - dapr-pluggable-net

networks:
  dapr-pluggable-net:
    external: true
```

### Component Dockerfile

```dockerfile
FROM golang:1.24.5-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o component ./main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/component .
CMD ["./component"]
```

## NebulaGraph Configuration

### Database Schema

The component automatically creates the required schema:

```sql
-- Create space for Dapr state
CREATE SPACE IF NOT EXISTS dapr_state (
    vid_type = FIXED_STRING(256)
);

-- Create state vertex type
CREATE TAG IF NOT EXISTS state (
    key string NOT NULL,
    data string,
    etag string,
    created timestamp DEFAULT timestamp(),
    modified timestamp DEFAULT timestamp()
);

-- Create index for efficient lookups
CREATE TAG INDEX IF NOT EXISTS state_key_index ON state(key);
```

### NebulaGraph Cluster Setup

For production, configure a NebulaGraph cluster:

```yaml
# Meta service configuration
--meta_server_addrs=meta1:9559,meta2:9559,meta3:9559
--local_ip=192.168.1.100
--ws_ip=192.168.1.100
--port=9559

# Storage service configuration  
--meta_server_addrs=meta1:9559,meta2:9559,meta3:9559
--local_ip=192.168.1.101
--ws_ip=192.168.1.101
--port=9779

# Graph service configuration
--meta_server_addrs=meta1:9559,meta2:9559,meta3:9559
--local_ip=192.168.1.102
--ws_ip=192.168.1.102
--port=9669
```

## Dapr Configuration

### Dapr Config File

`src/components/config.yaml`:

```yaml
apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: dapr-config
spec:
  tracing:
    samplingRate: "1"
    zipkin:
      endpointAddress: "http://zipkin:9411/api/v2/spans"
  
  logging:
    level: "info"
  
  features:
    - name: proxy.grpc
      enabled: true
    - name: pluggable-components
      enabled: true
```

### Component Registration

Components are registered via the components directory:

```
src/components/
├── config.yaml              # Dapr configuration
├── nebulagraph-state.yaml   # State store component
├── redis-pubsub.yaml        # Pub/sub component (optional)
└── local-secret-store.yaml  # Local secrets (development)
```

## Testing Configuration

### Test Environment Setup

Tests use the same Docker environment:

```bash
# Start infrastructure
cd src/dependencies
./environment_setup.sh start

# Start component
cd ../dapr-pluggable-components
./run_nebula.sh start

# Run tests
./tests/test_all.sh
```

### Test Configuration

Test scripts validate configuration:

```bash
#!/bin/bash
# Validate component registration
curl -f http://localhost:3501/v1.0/state/nebulagraph-state/health || exit 1

# Test state operations
curl -X POST http://localhost:3501/v1.0/state/nebulagraph-state \
  -H "Content-Type: application/json" \
  -d '[{"key": "test", "value": "config-test"}]'
```

## Production Deployment

### Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nebulagraph-component
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nebulagraph-component
  template:
    metadata:
      labels:
        app: nebulagraph-component
      annotations:
        dapr.io/enabled: "true"
        dapr.io/app-id: "nebulagraph-component"
        dapr.io/config: "dapr-config"
    spec:
      containers:
      - name: component
        image: your-registry/nebulagraph-component:latest
        env:
        - name: NEBULA_HOST
          value: "nebula-cluster.database.svc.cluster.local"
        - name: NEBULA_PORT
          value: "9669"
        volumeMounts:
        - name: component-socket
          mountPath: /var/run
      volumes:
      - name: component-socket
        emptyDir: {}
```

### Monitoring Configuration

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nebulagraph-component-metrics
spec:
  selector:
    app: nebulagraph-component
  ports:
  - port: 9090
    name: metrics
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: nebulagraph-component
spec:
  selector:
    matchLabels:
      app: nebulagraph-component
  endpoints:
  - port: metrics
```

## Troubleshooting Configuration

### Common Configuration Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Component not found | Wrong component path | Check `--resources-path` |
| Connection refused | Wrong NebulaGraph host/port | Verify `hosts` and `port` in config |
| Authentication failed | Wrong credentials | Check `username` and `password` |
| Space not found | Database not initialized | Run initialization script |
| Unix socket error | Permission/path issues | Check socket path and permissions |

### Debug Configuration

Enable debug logging:

```yaml
# In config.yaml
spec:
  logging:
    level: "debug"
```

View component logs:
```bash
docker logs nebulagraph-dapr-component
```

Test configuration:
```bash
# Test Dapr component loading
dapr list

# Test component health
curl http://localhost:3501/v1.0/healthz
```

## Configuration Examples

### Local Development
- Uses Docker containers
- Shared Docker network
- Volume mounts for rapid development
- Debug logging enabled

### Staging Environment
- Kubernetes deployment
- External NebulaGraph cluster
- ConfigMaps for non-sensitive config
- Secrets for credentials

### Production Environment
- Multi-replica deployment
- High-availability NebulaGraph cluster
- Resource limits and monitoring
- TLS encryption
