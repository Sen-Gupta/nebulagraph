# Dapr Runtime Infrastructure

Dapr runtime services for placement, scheduling, and tracing.

## Quick Commands

```bash
# From dependencies/ directory
./environment_setup.sh start    # Start all services (including Dapr runtime)
./environment_setup.sh status   # Check Dapr services status  
./environment_setup.sh stop     # Stop all services
./environment_setup.sh clean    # Reset and clean environment
```

## What's Included

- **Dapr Placement**: Actor placement service with health checks
- **Dapr Scheduler**: Job scheduling and reminders
- **Zipkin**: Distributed tracing for observability
- **Shared Networking**: Integration with `dapr-pluggable-net`

## Runtime Services

| Service | Container | Port | Purpose |
|---------|-----------|------|---------|
| Placement | dapr-placement | 50005 | Actor placement |
| Scheduler | dapr-scheduler | 50006 | Job scheduling |
| Zipkin | dapr-zipkin | 9411 | Distributed tracing |

## Configuration

Environment variables from `src/.env`:
- `DAPR_VERSION=1.15.9` - Dapr runtime version
- `DAPR_LOG_LEVEL=info` - Logging level
- `DAPR_PLACEMENT_PORT=50005` - Placement service port
- `DAPR_SCHEDULER_PORT=50006` - Scheduler service port

## Health Checks

All services include health checks:
- **Placement**: HTTP endpoint on `/v1.0/healthz`
- **Scheduler**: HTTP endpoint on `/v1.0/healthz`  
- **Zipkin**: HTTP endpoint on `/health`

## Observability

Access tracing dashboard:
```bash
# Zipkin UI
open http://localhost:9411
```

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
                    │  dapr-pluggable-net     │
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
      - dapr-pluggable-net
    environment:
      - DAPR_PLACEMENT_HOST_ADDRESS=dapr-placement:50090
      - DAPR_HTTP_ENDPOINT=http://your-dapr-sidecar:3500
      - DAPR_GRPC_ENDPOINT=your-dapr-sidecar:50001

networks:
  dapr-pluggable-net:
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

Ensure the `dapr-pluggable-net` network exists:

```bash
docker network ls | grep dapr-pluggable-net
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
| Network | Default bridge | Shared dapr-pluggable-net |
| Configuration | Not parameterized | Fully parameterized |
| Health Checks | Basic | Comprehensive |
| Integration | Isolated | Integrated with other services |
| Management | `dapr` commands | Docker Compose + scripts |

This setup provides much better control and integration for development environments with multiple services.
