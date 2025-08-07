# Dapr Components Configuration Guide

This guide covers the Dapr component configurations for the NebulaGraph project using Docker-based development.

## 🚀 Quick Start

### Docker Development Setup
```bash
cd src/
# Environment is pre-configured in .env file
cd dapr-pluggable-components/tests/
./test_all.sh
```

## 📁 Directory Structure

```
src/
├── .env                         # Environment configuration for Docker development
└── components/
    ├── nebulagraph-state.yaml   # NebulaGraph state store component
    ├── redis-pubsub.yaml        # Redis pub/sub component
    ├── config.yaml               # Dapr configuration file
    └── local-secret-store.yaml   # Local secret store component
```

## Environment Configuration

The component files use environment variables from the `.env` file, allowing configuration without changing YAML files. All configuration is optimized for Docker-based development with container networking.

### Component Files

#### `nebulagraph-state.yaml`
- **Type**: `state.nebulagraph-state`
- **Purpose**: Graph-based state storage using NebulaGraph
- **Configuration**: Uses Docker container networking (`nebula-graphd:9669`)

#### `redis-pubsub.yaml`
- **Type**: `pubsub.redis`
- **Purpose**: Redis-based pub/sub messaging  
- **Configuration**: Uses Docker container networking (`redis:6379`)
- **Purpose**: Message publishing and subscription via Redis  
- **Variables**: `${REDIS_HOST}`, `${REDIS_PASSWORD}`, `${REDIS_POOL_SIZE}`, etc.

## 🔧 Environment Variables

### NebulaGraph Variables
| Variable | Local | Docker | Description |
|----------|-------|---------|-------------|
| `NEBULA_HOST` | localhost | nebula-graphd | NebulaGraph hostname |
| `NEBULA_PORT` | 9669 | 9669 | NebulaGraph port |
| `NEBULA_USERNAME` | root | root | Username |
| `NEBULA_PASSWORD` | nebula | nebula | Password |
| `NEBULA_SPACE` | dapr_state | dapr_state | Graph space name |

### Redis Variables  
| Variable | Local | Docker | Description |
|----------|-------|---------|-------------|
| `REDIS_HOST` | localhost:6379 | redis:6379 | Redis hostname:port |
| `REDIS_PASSWORD` | dapr_redis | dapr_redis | Redis password |
| `REDIS_POOL_SIZE` | 5 | 20 | Connection pool size |
| `REDIS_TYPE` | node | node | Redis deployment type |

### Environment Files

Environment configuration is managed at the `src/` level:

#### `../env.local` - Local Development
- **NebulaGraph**: `localhost:9669`
#### Environment Variables
Key configuration variables in `.env`:
- **NebulaGraph**: `nebula-graphd:9669` (container networking)
- **Redis**: `redis:6379` (container networking)
- **Pool Size**: 20 (optimized for containers)
- **Timeouts**: Standard (container networking)

## 📋 Usage Patterns

### Docker Development
```bash
# Navigate to source directory
cd src/

# Configuration is pre-set in .env file
# Components are auto-loaded in docker-compose.yml
docker-compose up
```

### Manual Environment Override
```bash
# Override specific variables (from src/)
export NEBULA_HOST=custom-host
export REDIS_POOL_SIZE=50
dapr run --components-path ./components/ ...
```

## 📋 Commands Reference

### Component Testing
```bash
cd dapr-pluggable-components/tests/
./test_all.sh                 # Full test suite
./test_component.sh           # HTTP interface only
./test_component_grpc.sh      # gRPC interface only
./test_pubsub_integration.sh  # Pub/sub integration only
```

### Infrastructure Management
```bash
cd ../dependencies/
./environment_setup.sh        # Start NebulaGraph + Redis
./environment_setup.sh status # Check infrastructure status
./environment_setup.sh test   # Test infrastructure connectivity
```

## Configuration Management

### Environment-Specific Settings

| Setting | Docker/Production | Local Development |
|---------|-------------------|-------------------|
| NebulaGraph Host | `nebula-graphd:9669` | `localhost:9669` |
| Redis Host | `redis:6379` | `localhost:6379` |
| Connection Pool Size | 20 | 5 |
| Connection Timeout | 10s | 3s |
| Retry Attempts | 3 | 2 |

### Security Considerations

- **Passwords**: Use environment variables or secrets management in production
- **TLS**: Enable TLS for production deployments
- **Network**: Isolate components within secure networks
- **Authentication**: Configure proper authentication for all components

## Adding New Components

1. **Create Component File**: Add new `.yaml` file with descriptive name
2. **Follow Naming Convention**: `{service}-{type}.yaml` (e.g., `mongodb-state.yaml`)
3. **Environment Variants**: Create local version in `local/` directory
4. **Documentation**: Update this guide with component details
5. **Testing**: Add component tests in the test suite

### Example New Component

```yaml
# kafka-pubsub.yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: kafka-pubsub
  namespace: default
spec:
  type: pubsub.kafka
  version: v1
  metadata:
  - name: brokers
    value: "kafka:9092"
  - name: authType
    value: "none"
```

## Component Dependencies

### NebulaGraph State Store
- **Dependencies**: NebulaGraph cluster (metad, storaged, graphd)
- **Initialization**: Requires `dapr_state` space to be created
- **Health Check**: Verify connection to graphd service

### Redis Pub/Sub
- **Dependencies**: Redis server
- **Authentication**: Password-based authentication (`dapr_redis`)
- **Health Check**: Verify connection and authentication

## 🔍 Troubleshooting

### Check Current Environment
```bash
cd src/components/
./env-config.sh show
```

### Verify Component Loading
```bash
# After starting Dapr
curl http://localhost:3500/v1.0/metadata
```

### Test Individual Components
```bash
# Test state store
curl -X POST http://localhost:3500/v1.0/state/nebulagraph-state \
  -H "Content-Type: application/json" \
  -d '[{"key":"test","value":"hello"}]'

# Test pub/sub
curl -X POST http://localhost:3500/v1.0/publish/redis-pubsub/test \
  -H "Content-Type: application/json" \
  -d '{"message":"hello world"}'
```

### Common Issues

1. **Infrastructure Missing**: Run `dependencies/environment_setup.sh` to start NebulaGraph and Redis  
2. **Component Not Loading**: Check `curl http://localhost:3500/v1.0/metadata`
3. **Connection Failed**: Verify services with `docker ps` or check container logs
4. **Environment Variables**: Ensure `.env` file exists and contains proper Docker networking configuration

### Detailed Troubleshooting

#### Component Not Found
```bash
# Check components path
dapr components --app-id myapp
```

#### Connection Failed
```bash
# Verify service availability
docker ps | grep redis
docker ps | grep nebula
```

#### Authentication Failed
```bash
# Test Redis authentication
redis-cli -h localhost -p 6379 -a dapr_redis ping

# Test NebulaGraph connection
docker exec nebula-console nebula-console -addr nebula-graphd -port 9669 -u root -p nebula
```

### Debug Commands

```bash
# List all components
dapr components

# Check component metadata
curl http://localhost:3500/v1.0/metadata

# View component logs
dapr logs --app-id myapp

# Test state store
curl -X POST http://localhost:3500/v1.0/state/nebulagraph-state \
  -H "Content-Type: application/json" \
  -d '[{"key":"test","value":"hello"}]'

# Test pub/sub
curl -X POST http://localhost:3500/v1.0/publish/redis-pubsub/test \
  -H "Content-Type: application/json" \
  -d '{"message":"hello world"}'
```

## 🎯 Benefits

- ✅ **Single Component Files**: No duplicate configurations
- ✅ **Environment Variables**: Easy switching between local/Docker
- ✅ **Default Values**: Components work even without environment files
- ✅ **Docker Integration**: Native docker-compose environment support
- ✅ **Maintainable**: Clear separation of config and deployment

## Migration from Legacy Files

The following files are deprecated and should not be used for new deployments:

- `docker-component.yml` - Combined file (replaced by individual files)
- `component-local.yml` - Local combined file (replaced by `local/` directory)

### Migration Steps

1. **Stop Applications**: Stop any running Dapr applications
2. **Update Component Path**: Change `--components-path` to use new structure
3. **Verify Components**: Ensure all components load correctly
4. **Test Functionality**: Run test suite to verify everything works
5. **Remove Legacy Files**: Delete old combined files after successful migration

## Best Practices

1. **Separation of Concerns**: One component per file
2. **Environment-Specific Configs**: Use different directories for different environments
3. **Descriptive Names**: Use clear, descriptive filenames
4. **Version Control**: Track all component files in version control
5. **Documentation**: Keep this guide updated with new components
6. **Testing**: Include component tests in CI/CD pipeline
7. **Security**: Never commit secrets directly in component files

## 🔗 Related Documentation

- [Dapr Components Reference](https://docs.dapr.io/reference/components-reference/)
- [NebulaGraph State Store](../src/dapr-pluggable-components/stores/README.md)
- [Testing Guide](../src/dapr-pluggable-components/tests/README.md)
- [Architecture Overview](./architecture-diagrams.md)
- [Pub/Sub Integration](../src/dapr-pluggable-components/PUBSUB_INTEGRATION.md)
- [Technical Architecture](./technical-architecture.md)
