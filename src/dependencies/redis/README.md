# Redis Infrastructure

Redis setup for Dapr pub/sub messaging.

## Quick Commands

```bash
# From dependencies/ directory
./environment_setup.sh start    # Start all services (including Redis)
./environment_setup.sh status   # Check Redis status
./environment_setup.sh stop     # Stop all services
./environment_setup.sh clean    # Reset and clean environment
```

## What's Included

- **Redis Server**: Pub/sub messaging backend on port 6380
- **Health Checks**: Automatic readiness verification
- **Authentication**: Password-protected access

## Service Details

| Service | Container | Port | Purpose |
|---------|-----------|------|---------|
| Redis | redis-pubsub | 6380 | Pub/sub messaging |

## Configuration

Environment variables from `src/.env`:
- `REDIS_HOST_PORT=6380` - Host port mapping
- `REDIS_PASSWORD` - Authentication password

## Direct Access

```bash
# Connect via redis-cli (requires Redis tools)
redis-cli -h localhost -p 6380 -a ${REDIS_PASSWORD}

# Example commands
PING
INFO server
PUBSUB CHANNELS
```
cd redis && docker-compose up -d
```

### Initialize and Validate

```bash
# Run initialization script
./init_redis.sh
```

### Stop Redis

```bash
# From the redis directory
docker-compose down

# Remove volumes (data will be lost)
docker-compose down -v
```

## Service Details

- **Image**: redis:7.0-alpine
- **Container**: redis-pubsub
- **Host Port**: 6380 (configurable via REDIS_HOST_PORT)
- **Internal Port**: 6379
- **Network**: redis-net (isolated)
- **Persistence**: Enabled with appendonly log
- **Health Checks**: 30s interval with 5 retries

## Connection

From Dapr components or applications:

```yaml
# For docker-compose services in same network
host: redis-pubsub:6379
password: <REDIS_PASSWORD>

# For host connections
host: localhost:6380
password: <REDIS_PASSWORD>
```

## Troubleshooting

1. **Connection Issues**: Check if Redis is running and healthy
   ```bash
   docker ps | grep redis-pubsub
   docker logs redis-pubsub
   ```

2. **Authentication**: Verify password in environment file
   ```bash
   docker exec redis-pubsub redis-cli -a $REDIS_PASSWORD ping
   ```

3. **Port Conflicts**: Ensure port 6380 is available on host
   ```bash
   netstat -tulpn | grep 6380
   ```

## Integration with Dapr

This Redis instance is configured for Dapr pub/sub components. See the Dapr component configurations in `../components/` for connection details.
