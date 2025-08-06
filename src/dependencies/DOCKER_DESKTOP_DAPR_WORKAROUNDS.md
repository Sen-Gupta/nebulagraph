# Docker Desktop + Dapr Compatibility Workarounds

## Problem
When using Docker Desktop (especially on Linux with desktop-linux context), Dapr's `dapr init` command fails with:
```
❌ could not connect to docker. docker may not be installed or running
```

This happens because Dapr expects Docker to be available at the traditional Unix socket (`/var/run/docker.sock`), but Docker Desktop uses a different socket location.

## Workarounds

### 1. **Dapr Slim Mode (Recommended for Development)**
The script now automatically falls back to slim mode when standard initialization fails:

```bash
dapr init --slim
```

**Advantages:**
- ✅ Works perfectly with Docker Desktop
- ✅ No container dependencies
- ✅ Faster startup
- ✅ Good for development and testing

**Disadvantages:**
- ⚠️ No built-in Redis (you need to provide your own Redis instance)
- ⚠️ No automatic service discovery between Dapr applications

### 2. **Manual Docker Context Switch**
If you want to try container mode, you can attempt switching Docker contexts:

```bash
# Check available contexts
docker context ls

# Try switching to default (may not work with Docker Desktop)
docker context use default
dapr init
docker context use desktop-linux  # Switch back
```

**Note:** This usually doesn't work with Docker Desktop as the default context points to `/var/run/docker.sock` which doesn't exist.

### 3. **Use Docker Engine Instead of Docker Desktop**
For production-like environments, consider using Docker Engine directly:

```bash
# Uninstall Docker Desktop and install Docker Engine
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io
```

### 4. **Environment Variable Override**
Some users report success with:

```bash
export DOCKER_HOST=unix:///home/$USER/.docker/desktop/docker.sock
dapr init
```

## Current Script Behavior

Our `environment_setup.sh` script now handles this automatically:

1. **First attempt**: Try `dapr init` (container mode)
2. **Fallback**: If it fails, automatically try `dapr init --slim`
3. **Status detection**: Properly detects both container and slim mode installations

## Verification

After running the script, you can verify your Dapr installation:

```bash
# Check Dapr status
./environment_setup.sh dapr-status

# Check Dapr version
dapr --version

# Test the complete environment
./environment_setup.sh quick-test
```

## For Your Setup

Since you're using Docker Desktop, the script successfully initialized Dapr in **slim mode**:
- ✅ Dapr CLI: v1.15.2
- ✅ Dapr Runtime: v1.15.9
- ✅ Mode: Slim (no containers)
- ✅ Compatible with Docker Desktop

Your NebulaGraph + Redis setup provides the necessary infrastructure that Dapr components need, so the slim mode works perfectly for your use case.

## Testing Dapr Components

You can test your Dapr components with:

```bash
# Test state store (uses your NebulaGraph setup)
dapr run --app-id test-app --components-path ../components/ -- curl -X POST http://localhost:3500/v1.0/state/nebulagraph-state -H "Content-Type: application/json" -d '[{"key":"test","value":"hello"}]'

# Test pub/sub (uses your Redis setup)
dapr run --app-id test-app --components-path ../components/ -- curl -X POST http://localhost:3500/v1.0/publish/redis-pubsub/test -H "Content-Type: application/json" -d '{"message":"hello"}'
```
