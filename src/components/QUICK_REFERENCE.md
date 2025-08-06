# Dapr Components Quick Reference

## 🚀 Quick Start

### For Docker Development
```bash
cd src/
./env-config.sh set-docker
cd dapr-pluggable/tests/
./test_all.sh
```

### For Local Development  
```bash
cd src/
./env-config.sh set-local
# Start NebulaGraph and Redis locally first
cd dapr-pluggable/tests/
./test_all.sh
```

## 📁 File Structure

```
src/
├── components/
│   ├── nebulagraph-state.yaml    # NebulaGraph component (env vars)
│   ├── redis-pubsub.yaml        # Redis component (env vars)  
│   ├── README.md               # Detailed documentation
│   └── QUICK_REFERENCE.md      # This quick reference
├── .env.local               # Local development config
├── .env.docker              # Docker development config
├── .env                     # Active config (auto-generated)
└── env-config.sh           # Environment manager
```

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

## 📋 Commands

### Environment Management
```bash
./env-config.sh show          # Show current environment
./env-config.sh set-local     # Switch to local development
./env-config.sh set-docker    # Switch to Docker development
./env-config.sh compare       # Compare environments
./env-config.sh test          # Test current configuration
```

### Component Testing
```bash
cd ../dapr-pluggable/tests/
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

1. **Wrong Environment**: Use `./env-config.sh set-docker` or `set-local`
2. **Missing Infrastructure**: Run `../dependencies/environment_setup.sh`  
3. **Component Not Loading**: Check `curl http://localhost:3500/v1.0/metadata`
4. **Connection Failed**: Verify services with `docker ps` or local processes

## 🎯 Benefits

- ✅ **Single Component Files**: No duplicate configurations
- ✅ **Environment Variables**: Easy switching between local/Docker
- ✅ **Default Values**: Components work even without environment files
- ✅ **Docker Integration**: Native docker-compose environment support
- ✅ **Maintainable**: Clear separation of config and deployment

## 🔗 Related Files

- [Components README](README.md) - Detailed documentation
- [Pub/Sub Integration](../dapr-pluggable/PUBSUB_INTEGRATION.md) - Redis guide
- [Test Suite](../dapr-pluggable/tests/README.md) - Testing documentation
