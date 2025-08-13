# NebulaGraph Dapr Pluggable Components

![Docker Pulls](https://img.shields.io/docker/pulls/foodinvitesadmin/dapr-pluggables)
![Docker Image Size](https://img.shields.io/docker/image-size/foodinvitesadmin/dapr-pluggables)
![Docker Image Version](https://img.shields.io/docker/v/foodinvitesadmin/dapr-pluggables)

A high-performance, multi-backend Dapr state store component supporting **NebulaGraph** and **ScyllaDB**. This pluggable component enables seamless graph database and wide-column database integration with your Dapr applications.

## 🚀 Quick Start

```bash
# Pull the image
docker pull foodinvitesadmin/dapr-pluggables:latest

# Run with Docker (exposing both gRPC and HTTP ports)
docker run -d \
  --name dapr-pluggable \
  -p 50001:50001 \
  -p 3501:3501 \
  -e STORE_TYPES=nebulagraph,scylladb \
  foodinvitesadmin/dapr-pluggables:latest
```

## 🏗️ Features

- **🔌 Pluggable Architecture**: Drop-in replacement for Dapr state stores
- **📊 Multi-Backend Support**: NebulaGraph (graph database) + ScyllaDB (wide-column)
- **⚡ High Performance**: Optimized connection pooling and async operations
- **🔒 Security First**: Built with distroless base image and non-root user
- **🐳 Container Ready**: Multi-platform support (linux/amd64, linux/arm64)
- **📈 Production Ready**: Comprehensive error handling and observability

## 📋 Supported Backends

| Backend | Type | Use Cases |
|---------|------|-----------|
| **NebulaGraph** | Graph Database | Social networks, fraud detection, recommendation engines |
| **ScyllaDB** | Wide-Column | High-throughput applications, time-series data, IoT |

## 🔧 Configuration

### Dapr Component Configuration

Create your Dapr component configuration file:

```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: nebulagraph-state
  namespace: default
spec:
  type: state.nebulagraph-state
  version: v1
  metadata:
  # Database Connection
  - name: hosts
    secretKeyRef:
      name: nebulagraph:host
      key: nebulagraph:host
  - name: port
    secretKeyRef:
      name: nebulagraph:port
      key: nebulagraph:port
  - name: username
    secretKeyRef:
      name: nebulagraph:username
      key: nebulagraph:username
  - name: password
    secretKeyRef:
      name: nebulagraph:password
      key: nebulagraph:password
  - name: space
    secretKeyRef:
      name: nebulagraph:space
      key: nebulagraph:space
  
  # Connection Pool Configuration
  - name: connectionTimeout
    secretKeyRef:
      name: nebulagraph:connectionTimeout
      key: nebulagraph:connectionTimeout
  - name: executionTimeout
    secretKeyRef:
      name: nebulagraph:executionTimeout
      key: nebulagraph:executionTimeout
  - name: maxConnPoolSize
    secretKeyRef:
      name: nebulagraph:maxConnPoolSize
      key: nebulagraph:maxConnPoolSize
  - name: minConnPoolSize
    secretKeyRef:
      name: nebulagraph:minConnPoolSize
      key: nebulagraph:minConnPoolSize
  - name: idleTime
    secretKeyRef:
      name: nebulagraph:idleTime
      key: nebulagraph:idleTime
auth:
  secretStore: local-secret-store
```

### Secret Store Configuration

```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: local-secret-store
  namespace: default
spec:
  type: secretstores.local.file
  version: v1
  metadata:
  - name: secretsFile
    value: "/path/to/secrets.json"
```

### Secrets Configuration (`secrets.json`)

```json
{
  "nebulagraph:host": "nebula-graphd",
  "nebulagraph:port": "9669",
  "nebulagraph:username": "your_username",
  "nebulagraph:password": "your_password",
  "nebulagraph:space": "dapr_state",
  "nebulagraph:connectionTimeout": "10s",
  "nebulagraph:executionTimeout": "30s",
  "nebulagraph:maxConnPoolSize": "50",
  "nebulagraph:minConnPoolSize": "5",
  "nebulagraph:idleTime": "8h"
}
```

## 🐳 Docker Compose Example

```yaml
version: '3.8'
services:
  dapr-pluggable:
    image: foodinvitesadmin/dapr-pluggables:latest
    container_name: dapr-pluggable
    ports:
      - "50001:50001"  # gRPC port for Dapr pluggable component
      - "3501:3501"    # HTTP port for health/metrics endpoints
    environment:
      - STORE_TYPES=nebulagraph,scylladb
    volumes:
      - ./components:/components
      - ./secrets:/secrets
    networks:
      - dapr-network

  # Your Dapr application
  your-app:
    image: your-app:latest
    depends_on:
      - dapr-pluggable
    networks:
      - dapr-network

networks:
  dapr-network:
    driver: bridge
```

## ⚙️ Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `STORE_TYPES` | Comma-separated list of enabled stores | `nebulagraph,scylladb` |
| `LOG_LEVEL` | Logging level (debug, info, warn, error) | `info` |
| `GRPC_PORT` | gRPC port for Dapr pluggable component | `50001` |
| `HTTP_PORT` | HTTP port for health/metrics endpoints | `3501` |

## 🔌 Port Configuration

| Port | Protocol | Purpose | Endpoint Examples |
|------|----------|---------|-------------------|
| **50001** | gRPC | Dapr Pluggable Component API | State operations, component communication |
| **3501** | HTTP | Health & Metrics | `/health`, `/metrics`, `/version` |

### Port Usage Examples

```bash
# Check component health
curl http://localhost:3501/health

# Get metrics
curl http://localhost:3501/metrics

# Get version info
curl http://localhost:3501/version

# Dapr state operations (through Dapr runtime on port 50001)
# Note: These are handled via gRPC by Dapr runtime
```

## 🚀 Usage Examples

### With Dapr CLI

```bash
# Start the pluggable component
dapr run \
  --app-id my-app \
  --components-path ./components \
  --config ./config.yaml \
  -- your-application

# Test state operations
dapr invoke --app-id my-app --method state/save --data '{"key":"test","value":"hello"}'
```

### With Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dapr-pluggable
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dapr-pluggable
  template:
    metadata:
      labels:
        app: dapr-pluggable
    spec:
      containers:
      - name: dapr-pluggable
        image: foodinvitesadmin/dapr-pluggables:latest
        ports:
        - containerPort: 50001  # gRPC port
          name: grpc
        - containerPort: 3501   # HTTP port
          name: http
        env:
        - name: STORE_TYPES
          value: "nebulagraph,scylladb"
```

## 📊 Performance

- **Throughput**: Up to 10K+ ops/sec per backend
- **Latency**: < 5ms average response time
- **Memory**: ~30MB container footprint
- **CPU**: Optimized for multi-core systems

## 🔍 Monitoring & Observability

The component exposes metrics and health endpoints on port **3501**:

- **Health**: `http://localhost:3501/health`
- **Metrics**: `http://localhost:3501/metrics` 
- **Version**: `http://localhost:3501/version`

### Health Check Example

```bash
# Basic health check
curl http://localhost:3501/health

# Expected response:
# {"status": "healthy", "timestamp": "2025-08-13T10:30:00Z"}
```

### Metrics Collection

```bash
# Get Prometheus-compatible metrics
curl http://localhost:3501/metrics

# Example metrics:
# dapr_component_requests_total{store="nebulagraph",operation="get"} 1234
# dapr_component_request_duration_seconds{store="scylladb",operation="set"} 0.005
```

## 🛠️ Development

### Building from Source

```bash
git clone https://github.com/Sen-Gupta/nebulagraph.git
cd nebulagraph/local-build
./build.sh
```

### Running Tests

```bash
cd src/dapr-pluggable-components
go test ./...
```

## 📚 Documentation

- **Architecture**: [docs/architecture.md](https://github.com/Sen-Gupta/nebulagraph/blob/main/docs/architecture.md)
- **Configuration**: [docs/configuration.md](https://github.com/Sen-Gupta/nebulagraph/blob/main/docs/configuration.md)
- **Examples**: [src/examples/](https://github.com/Sen-Gupta/nebulagraph/tree/main/src/examples)

## 🤝 Contributing

Contributions are welcome! Please see our [Contributing Guide](https://github.com/Sen-Gupta/nebulagraph/blob/main/CONTRIBUTING.md).

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/Sen-Gupta/nebulagraph/blob/main/LICENSE) file for details.

## 🔗 Links

- **GitHub Repository**: https://github.com/Sen-Gupta/nebulagraph
- **Docker Hub**: https://hub.docker.com/r/foodinvitesadmin/dapr-pluggables
- **Issues**: https://github.com/Sen-Gupta/nebulagraph/issues

---

**Built with ❤️ for the Dapr community**
