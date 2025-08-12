# Dapr Runtime Services

This folder contains a Docker Compose configuration for running Dapr runtime services with controlled ports and networking.

## Overview

Instead of using the default `dapr init` which creates containers with fixed configurations, this setup provides:

- **Controlled port mapping** - All ports are parameterized and configurable
- **Shared network integration** - Uses the same `nebula-net` network as other services
- **Consistent parameterization** - Follows the `${VAR:-default}` pattern used by other services
- **Health checks** - Built-in health monitoring for all services
- **Persistence** - Named volumes for data persistence

## Services

| Service | Default Port | Purpose | Health Check |
|---------|-------------|---------|--------------|
| `dapr-placement` | 50090 | Actor placement service | HTTP healthz endpoint |
| `dapr-scheduler` | 50091 | Scheduled jobs and reminders | HTTP healthz endpoint |
| `dapr-zipkin` | 9411 | Distributed tracing | HTTP health endpoint |

## Port Configuration

All ports are configurable via environment variables in `../.env`:

```bash
# Dapr Runtime Configuration
DAPR_VERSION=1.15.9
DAPR_LOG_LEVEL=info

# Dapr Placement Service
DAPR_PLACEMENT_PORT=50090
DAPR_PLACEMENT_METRICS_HOST_PORT=59090
DAPR_PLACEMENT_HEALTH_HOST_PORT=58090

# Dapr Scheduler Service
DAPR_SCHEDULER_PORT=50091
DAPR_SCHEDULER_METRICS_HOST_PORT=59091
DAPR_SCHEDULER_HEALTH_HOST_PORT=58091
DAPR_ETCD_HOST_PORT=52379

# Dapr Zipkin Tracing
DAPR_ZIPKIN_PORT=9411
```

## Network Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   NebulaGraph   │    │      Redis      │    │    ScyllaDB     │
│     Cluster     │    │   (Pub/Sub)     │    │ (State Store)   │
│                 │    │                 │    │                 │
│ Ports: 9669     │    │ Port: 6380      │    │ Ports: 9042     │
│        7001     │    │                 │    │        7004     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │  nebula-net     │
                    │   (External)    │
                    └─────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ dapr-placement  │    │ dapr-scheduler  │    │  dapr-zipkin    │
│ Port: 50090     │    │ Port: 50091     │    │  Port: 9411     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Port Allocation Strategy

To avoid conflicts, ports are allocated as follows:

- **6380**: Our Redis service (pub/sub messaging)  
- **7001**: NebulaGraph Studio
- **7004**: ScyllaDB Manager
- **9042**: ScyllaDB CQL Protocol
- **9411**: Zipkin Tracing UI
- **50090**: Dapr Placement Service
- **50091**: Dapr Scheduler Service
- **58090-58091**: Health check endpoints
- **59090-59091**: Metrics endpoints

## Usage

### Start Dapr Runtime

```bash
# From the dependencies folder
cd dependencies
./environment_setup.sh start

# Or start just Dapr services
cd dapr
docker compose up -d
```

### Check Status

```bash
# Show all services including Dapr
./environment_setup.sh status

# Show only Dapr services
./environment_setup.sh dapr-status
```

### Stop Services

```bash
# Stop all services
./environment_setup.sh stop

# Or stop just Dapr services
cd dapr
docker compose down
```

## Health Monitoring

The setup includes comprehensive health checks:

- **Zipkin**: HTTP GET `/health`
- **Placement**: HTTP GET `/v1.0/healthz`  
- **Scheduler**: HTTP GET `/v1.0/healthz`

Health check results are shown in the status command.

## Data Persistence

All services use named volumes for data persistence:

- `dapr-placement-data`: Placement service state
- `dapr-scheduler-data`: Scheduler state  
- `dapr-etcd-data`: etcd data for scheduler
- `dapr-zipkin-data`: Zipkin traces

## Integration with Applications

Applications using Dapr can connect to these services:

```yaml
# In your application's docker-compose.yml
services:
  your-app:
    # ... other config
    networks:
      - nebula-net
    environment:
      - DAPR_PLACEMENT_HOST_ADDRESS=dapr-placement:50090
      - DAPR_HTTP_ENDPOINT=http://your-dapr-sidecar:3500
      - DAPR_GRPC_ENDPOINT=your-dapr-sidecar:50001

networks:
  nebula-net:
    external: true
```

## Troubleshooting

### Port Conflicts

If you encounter port conflicts, update the environment variables in `../.env`:

```bash
# Example: Change Zipkin port
DAPR_ZIPKIN_PORT=9412
```

### Network Issues

Ensure the `nebula-net` network exists:

```bash
docker network ls | grep nebula-net
```

If not found, run the environment setup:

```bash
./environment_setup.sh start
```

### Service Health

Check individual service health:

```bash
# Zipkin
curl http://localhost:9411/health

# Placement service
curl http://localhost:58080/v1.0/healthz

# Scheduler service  
curl http://localhost:58081/v1.0/healthz
```

## Comparison with Default Dapr Init

| Aspect | Default `dapr init` | This Setup |
|--------|-------------------|------------|
| Port Control | Fixed ports | Configurable ports |
| Network | Default bridge | Shared nebula-net |
| Configuration | Not parameterized | Fully parameterized |
| Health Checks | Basic | Comprehensive |
| Integration | Isolated | Integrated with other services |
| Management | `dapr` commands | Docker Compose + scripts |

This setup provides much better control and integration for development environments with multiple services.
