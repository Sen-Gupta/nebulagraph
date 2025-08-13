# Docker Desktop Compatibility Notes

## Issue: Dapr Init Failures with Docker Desktop

**Problem**: `dapr init` fails on Docker Desktop with connectivity errors.

**Solution**: Automatically handled by `environment_setup.sh`:
1. Detects Docker Desktop configurations
2. Creates socket symlink: `sudo ln -sf ~/.docker/desktop/docker.sock /var/run/docker.sock`
3. Initializes Dapr in container mode

## Verification

```bash
./environment_setup.sh dapr-status

# Expected output:
# ✅ Dapr runtime is running (container mode)
# NAMES            IMAGE                STATUS
# dapr_placement   daprio/dapr:1.15.9   Up 2 minutes
# dapr_scheduler   daprio/dapr:1.15.9   Up 2 minutes  
# dapr_zipkin      openzipkin/zipkin    Up 2 minutes
```

## Manual Troubleshooting

If automatic detection fails:
```bash
# Check Docker context
docker context list

# Manual socket link (if needed)
sudo ln -sf ~/.docker/desktop/docker.sock /var/run/docker.sock

# Verify Dapr initialization
dapr --version
```

**Reference**: [Dapr GitHub Issue #5011](https://github.com/dapr/dapr/issues/5011)
```

## Root Cause
Docker Desktop changes the Docker context and socket location, causing Dapr to lose connectivity:

- **Traditional Docker:** Uses `/var/run/docker.sock`
- **Docker Desktop:** Uses `~/.docker/desktop/docker.sock` or similar platform-specific paths
- **Dapr expectation:** Looks for Docker at the standard socket location

## Automated Workarounds (Our Script)

Our `environment_setup.sh` script implements multiple workarounds automatically, based on community solutions from [dapr/dapr#5011](https://github.com/dapr/dapr/issues/5011):

### 1. **DOCKER_HOST Environment Variable** (Primary Fix)
For Docker Desktop contexts, the script automatically detects and sets:
```bash
export DOCKER_HOST=unix:///home/$USER/.docker/desktop/docker.sock
```

**Detection Logic:**
- Checks `docker context ls` for `desktop-linux` context
- Extracts the actual Docker endpoint from context metadata
- Applies this fix temporarily during `dapr init`

### 2. **Docker Socket Symlink** (Linux/macOS)
Creates a symlink from the expected location to the actual Docker Desktop socket:
```bash
sudo ln -sf ~/.docker/desktop/docker.sock /var/run/docker.sock
```

**Safety Notes:**
- Only attempted if default socket doesn't exist
- Requires sudo privileges
- Automatically skipped if not feasible

### 3. **Docker Context Switching** (Temporary)
Attempts to switch to default context during initialization:
```bash
docker context use default
dapr init
docker context use desktop-linux  # restore original
```

### 4. **Dapr Slim Mode** (Final Fallback)
If all connectivity fixes fail, falls back to container-less mode:
```bash
dapr init --slim
```

## Manual Workarounds

If our automated script fails, try these manual solutions from the community:

### Solution A: Docker Socket Symlink (Most Effective)
**This is the solution that works reliably:**
```bash
# Create symlink from Docker Desktop socket to expected location
sudo ln -sf ~/.docker/desktop/docker.sock /var/run/docker.sock
dapr init
```

**Benefits:**
- ✅ Works consistently with Docker Desktop
- ✅ Enables full container mode with Redis, Zipkin, Placement services
- ✅ No need to modify Docker Desktop settings
- ✅ Automatically applied by our environment_setup.sh script

### Solution B: Enable Default Docker Socket (Alternative)
**For Docker Desktop 4.19.0+:**
1. Open Docker Desktop
2. Go to Settings → Advanced
3. Enable "Allow the default Docker socket to be used" (requires password)
4. Restart Docker Desktop
5. Run `dapr init`

### Solution C: Manual DOCKER_HOST Setup
```bash
# Check your Docker context
docker context ls --format json | jq

# Find the DockerEndpoint and set it
export DOCKER_HOST=unix:///home/$USER/.docker/desktop/docker.sock
dapr init
```

### Solution D: Install Docker Engine (Production)
For production environments, consider Docker Engine instead of Docker Desktop:
```bash
# Remove Docker Desktop and install Docker Engine
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

## Current Script Behavior

The `environment_setup.sh` script handles Docker Desktop issues automatically:

1. **Detection**: Identifies Docker Desktop contexts and endpoints
2. **Workaround Application**: Tries multiple fixes in order of preference
3. **Graceful Fallback**: Uses slim mode if container mode fails
4. **Status Reporting**: Clearly indicates which mode was successful

## Verification Commands

Check your Dapr installation status:

```bash
# Comprehensive environment status
./environment_setup.sh dapr-status

# Quick service connectivity test  
./environment_setup.sh quick-test

# Check Dapr installation details
dapr --version

# List Dapr containers (if using container mode)
docker ps --filter "name=dapr_"

# Check Docker context
docker context ls
```

## Success Indicators

**Container Mode Success:**
```bash
✅ Dapr runtime initialized successfully
ℹ️  Using Redis on port 6380 for pub/sub messaging
```

**Slim Mode Success:**
```bash
✅ Dapr runtime initialized successfully in slim mode
⚠️  Note: This setup won't include Dapr's Zipkin containers
```

## Testing Dapr Components

Test your NebulaGraph + Redis Dapr setup:

```bash
# Test state store (NebulaGraph backend)
cd ../examples/NebulaGraphTestHttpApi
./test_net.sh test

# Test pub/sub (Redis backend)  
dapr run --app-id test-app --components-path ../../components \
  -- curl -X POST http://localhost:3500/v1.0/publish/redis-pubsub/test \
  -H "Content-Type: application/json" -d '{"message":"hello world"}'

# Test state operations
dapr run --app-id test-app --components-path ../../components \
  -- curl -X POST http://localhost:3500/v1.0/state/nebulagraph-state \
  -H "Content-Type: application/json" \
  -d '[{"key":"test","value":"hello from dapr"}]'
```

## Integration Notes

**For NebulaGraph Project:**
- ✅ Slim mode works perfectly with our external Redis and NebulaGraph containers
- ✅ Component configurations remain unchanged
- ✅ All pluggable component functionality preserved
- ⚠️ Use our Redis (port 6380) for pub/sub messaging in all modes

## References

- **Primary Issue:** [dapr/dapr#5011 - dapr init could not connect to Docker](https://github.com/dapr/dapr/issues/5011)
- **Docker Desktop Documentation:** [Docker Context Documentation](https://docs.docker.com/engine/context/working-with-contexts/)
- **Dapr Installation Modes:** [Dapr Self-Hosted Installation](https://docs.dapr.io/operations/hosting/self-hosted/)

## Troubleshooting

**If script still fails:**
1. Check Docker Desktop is running: `docker ps`
2. Verify Docker context: `docker context ls`
3. Try manual DOCKER_HOST: `export DOCKER_HOST=$(docker context ls --format json | jq -r '.[] | select(.Current == true) | .DockerEndpoint')`
4. Enable Docker Desktop socket in settings
5. Consider Docker Engine for production environments

**Need help?** The automated workarounds in `environment_setup.sh` should handle most Docker Desktop scenarios. If issues persist, refer to the GitHub issue for the latest community solutions.
