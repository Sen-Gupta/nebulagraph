# Redis Pub/Sub and NebulaGraph Integration

This document describes the Redis pub/sub and NebulaGraph state store integration for the Dapr pluggable components.

## Overview

The integration provides:
- **Redis Pub/Sub**: For real-time messaging and event distribution
- **NebulaGraph State Store**: For persistent state storage with graph capabilities
- **Seamless Integration**: Messages published via pub/sub are automatically persisted in NebulaGraph

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Application   │    │   Dapr Sidecar   │    │   Components    │
│                 │    │                  │    │                 │
│  ┌─────────────┐│    │  ┌─────────────┐ │    │ ┌─────────────┐ │
│  │   Pub/Sub   ││◄──►│  │   Pub/Sub   │ │◄──►│ │    Redis    │ │
│  │   Client    ││    │  │   API       │ │    │ │   Server    │ │
│  └─────────────┘│    │  └─────────────┘ │    │ └─────────────┘ │
│                 │    │                  │    │                 │
│  ┌─────────────┐│    │  ┌─────────────┐ │    │ ┌─────────────┐ │
│  │    State    ││◄──►│  │    State    │ │◄──►│ │ NebulaGraph │ │
│  │   Client    ││    │  │    API      │ │    │ │   Database  │ │
│  └─────────────┘│    │  └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Components Configuration

### Redis Pub/Sub Component (`redis-pubsub`)

```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: redis-pubsub
spec:
  type: pubsub.redis
  version: v1
  metadata:
  - name: redisHost
    value: "redis:6379"
  - name: redisPassword
    value: "dapr_redis"
  - name: redisDB
    value: "0"
```

### NebulaGraph State Store Component (`nebulagraph-state`)

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
```

## API Endpoints

The NebulaGraph Test API provides the following endpoints for testing the integration:

### Pub/Sub Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/pubsub/publish/{topic}` | Publish a message to a specific topic |
| POST | `/api/pubsub/subscribe` | Subscription endpoint for Dapr (auto-configured) |
| GET | `/api/pubsub/health` | Health check for pub/sub connectivity |

### State Store Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/pubsub/messages` | Retrieve published messages from state store |
| GET | `/api/pubsub/events` | Retrieve processed events from state store |

## Message Flow

1. **Publishing**: 
   - Application publishes message via Dapr pub/sub API
   - Message is sent to Redis pub/sub
   - Message is also persisted in NebulaGraph state store

2. **Subscription**:
   - Dapr delivers messages to subscribed applications
   - Application processes message and stores event data in NebulaGraph

3. **State Persistence**:
   - All messages and events are stored in NebulaGraph
   - Provides audit trail and historical data access
   - Enables graph-based queries on message relationships

## Example Usage

### Publishing a Message

```bash
curl -X POST http://localhost:5000/api/pubsub/publish/orders \
  -H "Content-Type: application/json" \
  -d '{
    "orderId": "12345",
    "customerId": "customer-001",
    "items": [
      {"productId": "prod-001", "quantity": 2, "price": 29.99}
    ],
    "total": 59.98,
    "status": "pending"
  }'
```

### Publishing via Dapr CLI

```bash
dapr publish \
  --publish-app-id nebulagraph-test-api \
  --pubsub redis-pubsub \
  --topic events \
  --data '{"eventType": "user_registered", "userId": "user-123"}'
```

### Retrieving Messages from State Store

```bash
curl http://localhost:5000/api/pubsub/messages
```

### Testing Health

```bash
curl http://localhost:5000/api/pubsub/health
```

## Topics and Subscriptions

The application is configured to subscribe to the following topics:

- `orders` - Order-related events
- `notifications` - User notification events  
- `events` - General application events

New topics can be added by updating the `[Topic]` attributes in the `PubSubController.cs`.

## Testing

Run the complete integration test:

```bash
cd src/dapr-pluggable/tests
./test_pubsub_integration.sh
```

Test individual components:

```bash
# Test pub/sub health
./test_pubsub_integration.sh health

# Test message publishing
./test_pubsub_integration.sh publish

# Test state store integration
./test_pubsub_integration.sh state

# Test Redis directly
./test_pubsub_integration.sh redis

# Test NebulaGraph directly
./test_pubsub_integration.sh nebula
```

## Infrastructure Setup

1. **Start the infrastructure**:
   ```bash
   cd src/dependencies
   ./environment_setup.sh
   ```

2. **Verify services**:
   ```bash
   ./environment_setup.sh status
   ```

3. **Check connectivity**:
   ```bash
   ./environment_setup.sh test
   ```

## Troubleshooting

### Redis Connection Issues

1. Check Redis container status:
   ```bash
   docker ps | grep redis
   ```

2. Test Redis connectivity:
   ```bash
   redis-cli -h localhost -p 6379 -a dapr_redis ping
   ```

3. Check Redis logs:
   ```bash
   docker logs redis
   ```

### NebulaGraph Connection Issues

1. Check NebulaGraph containers:
   ```bash
   docker ps | grep nebula
   ```

2. Test NebulaGraph connectivity:
   ```bash
   docker exec nebula-console nebula-console -addr nebula-graphd -port 9669 -u root -p nebula -e "SHOW HOSTS;"
   ```

### Pub/Sub Message Delivery Issues

1. Check Dapr sidecar logs:
   ```bash
   dapr logs --app-id nebulagraph-test-api
   ```

2. Verify topic subscriptions:
   ```bash
   curl http://localhost:3500/v1.0/metadata
   ```

3. Test direct Redis pub/sub:
   ```bash
   # Terminal 1 - Subscribe
   redis-cli -h localhost -p 6379 -a dapr_redis subscribe test
   
   # Terminal 2 - Publish
   redis-cli -h localhost -p 6379 -a dapr_redis publish test "Hello World"
   ```

## Performance Considerations

- **Redis Connection Pooling**: Configured with 20 connections by default
- **NebulaGraph Connection Pooling**: Uses connection pool for efficient database access
- **Message Batching**: Consider batching for high-throughput scenarios
- **State Store Optimization**: Use bulk operations for multiple state updates

## Security

- **Redis Authentication**: Uses password-based authentication (`dapr_redis`)
- **NebulaGraph Authentication**: Uses username/password authentication
- **Network Security**: All components run in isolated Docker network (`nebula-net`)
- **Component Security**: Dapr provides additional security layers

## Production Deployment

For production deployment, consider:

1. **Redis Clustering**: Use Redis Cluster for high availability
2. **NebulaGraph Clustering**: Deploy NebulaGraph in cluster mode
3. **Monitoring**: Add metrics and monitoring for both components
4. **Backup**: Implement backup strategies for both Redis and NebulaGraph
5. **Security**: Use TLS/SSL for all connections
6. **Resource Limits**: Set appropriate CPU and memory limits
7. **Scaling**: Configure horizontal scaling based on load

## Related Documentation

- [NebulaGraph State Store Documentation](../stores/README.md)
- [Dapr Pub/Sub Documentation](https://docs.dapr.io/developing-applications/building-blocks/pubsub/)
- [Redis Pub/Sub Component](https://docs.dapr.io/reference/components-reference/supported-pubsub/setup-redis-pubsub/)
- [Architecture Overview](../../../docs/architecture-diagrams.md)
