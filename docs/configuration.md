# Configuration Guide

Complete configuration guide for the NebulaGraph Dapr component setup and deployment.

## Quick Start

### Development Setup
```bash
# 1. Setup infrastructure
cd src/dependencies
./environment_setup.sh

# 2. Run component
cd ../dapr-pluggable-components  
./run_docker_pluggable.sh start

# 3. Test
./tests/test_all.sh
```

## Component Configuration

### Dapr Component Definition

The main component configuration file: `src/components/nebulagraph-state.yaml`

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
    value: "nebula-graphd"
  - name: port
    value: "9669"
  - name: username
    value: "root"
  - name: password
    value: "nebula"
  - name: space
    value: "dapr_state"
  - name: connectionTimeout
    value: "10s"
  - name: executionTimeout
    value: "30s"
```

### Configuration Parameters

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `hosts` | NebulaGraph server address | `localhost` | Yes |
| `port` | NebulaGraph server port | `9669` | Yes |
| `username` | Database username | `root` | Yes |
| `password` | Database password | `nebula` | Yes |
| `space` | NebulaGraph space name | `dapr_state` | Yes |
| `connectionTimeout` | Connection timeout | `10s` | No |
| `executionTimeout` | Query execution timeout | `30s` | No |

## Environment Variables

### Development Environment

The project uses a `.env` file for Docker development:

```bash
# NebulaGraph Configuration
NEBULA_HOST=nebula-graphd
NEBULA_PORT=9669
NEBULA_USERNAME=root
NEBULA_PASSWORD=nebula
NEBULA_SPACE=dapr_state

# Dapr Configuration
DAPR_HTTP_PORT=3501
DAPR_GRPC_PORT=50001
DAPR_APP_ID=nebulagraph-test

# Component Configuration
COMPONENT_SOCKET_PATH=/var/run/dapr-components-sockets
```

### Production Environment

For production deployments, use Kubernetes secrets:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: nebulagraph-credentials
type: Opaque
stringData:
  username: "production-user"
  password: "secure-password"
  hosts: "nebula-cluster.prod.svc.cluster.local"
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
      "--components-path", "/components",
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
      - nebula-net

  # NebulaGraph component
  nebulagraph-dapr-component:
    build: ../..
    container_name: nebulagraph-dapr-component
    volumes:
      - /var/run:/var/run
    depends_on:
      - nebula-graphd
    networks:
      - nebula-net

networks:
  nebula-net:
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
./run_docker_pluggable.sh start

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
| Component not found | Wrong component path | Check `--components-path` |
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
