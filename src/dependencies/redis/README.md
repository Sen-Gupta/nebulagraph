# Redis for Dapr Pub/Sub

This directory contains the Redis setup for Dapr pub/sub messaging, isolated from the NebulaGraph cluster.

## Overview

Redis serves as the pub/sub messaging backend for Dapr applications. This setup uses environment variables from the root `.env` file for configuration.

## Configuration

The Redis service uses the following environment variables from `../../.env`:

- `REDIS_HOST_PORT`: Host port mapping (default: 6380)
- `REDIS_PASSWORD`: Redis authentication password

## Files

- `docker-compose.yml`: Redis service definition
- `init_redis.sh`: Initialization and validation script
- `README.md`: This documentation

## Usage

### Start Redis

```bash
# From the redis directory
docker-compose up -d

# Or from the root dependencies directory
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
