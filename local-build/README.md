# Local Build System

**One script to rule them all!** 🚀

This directory contains a unified build script for the NebulaGraph Dapr Pluggable Components. The script handles Docker Hub authentication, image building, and pushing in a single command.

## Quick Start

```bash
cd local-build
./build.sh
```

That's it! The script will:
1. ✅ Check prerequisites (Docker, files)
2. 🔐 Handle Docker Hub authentication
3. 🔨 Build the Docker image with metadata
4. 📤 Push to Docker Hub
5. 📊 Show results

## Usage

### Basic Commands

```bash
# Build and push with default tag (latest)
./build.sh

# Build with custom tag
./build.sh --tag v1.0.0

# Build only (no push)
./build.sh --no-push

# Quiet mode (minimal output)
./build.sh --quiet

# Force re-authentication
./build.sh --force-login
```

### Advanced Examples

```bash
# Development build with timestamp
./build.sh -t dev-$(date +%s)

# Quick local build for testing
./build.sh -n -q

# Production release
./build.sh -t v1.2.3 -f

# Help and options
./build.sh --help
```

## Configuration

The script uses these default settings:

- **Registry Username**: `foodinvitesadmin`
- **Image Name**: `experiom`
- **Default Tag**: `latest`
- **Full Image**: `foodinvitesadmin/experiom:tag`

## Authentication

### First Time Setup

1. Get your Docker Hub Personal Access Token from: https://hub.docker.com/settings/security
2. Run the script - it will prompt for your token
3. Token is securely saved for future builds

### Token Management

- Token is saved in `.docker_token` (gitignored)
- Use `--force-login` to update token
- Delete `.docker_token` to reset authentication

## Script Features

### 🔍 Smart Detection
- Automatically finds component directory
- Validates Docker and file prerequisites
- Detects existing authentication

### 🏗️ Build Metadata
- **Build Time**: UTC timestamp
- **Version**: Git tag or custom version  
- **Revision**: Git commit SHA (short)

### 🛡️ Error Handling
- Comprehensive validation
- Graceful error messages
- Interrupt handling (Ctrl+C)

### 📊 Output Modes
- **Normal**: Full progress information
- **Quiet**: Minimal output for automation
- **Help**: Detailed usage information

## Directory Structure

```
local-build/
├── build.sh              # Main build script
├── README.md             # This documentation
└── .docker_token         # Saved auth token (auto-generated)
```

## Build Process

### 1. Prerequisites Check
- ✅ Docker daemon running
- ✅ Component directory exists (`../src/dapr-pluggable-components`)
- ✅ Dockerfile present
- ⚠️ Warning if main.go missing

### 2. Authentication
- Check existing Docker Hub login
- Use saved token if available
- Prompt for new token if needed
- Save token securely for reuse

### 3. Image Build
- Navigate to component directory
- Inject build metadata (time, version, git revision)
- Build with optimized Docker settings
- Tag with specified name

### 4. Push to Registry
- Push to `foodinvitesadmin/experiom:tag`
- Show Docker Hub URL
- Display pull command

### 5. Results
- Show local image information
- Confirm successful completion

## Command Line Options

| Option | Short | Description |
|--------|-------|-------------|
| `--tag TAG` | `-t` | Set custom image tag |
| `--no-push` | `-n` | Build only, skip push |
| `--force-login` | `-f` | Force re-authentication |
| `--quiet` | `-q` | Minimal output |
| `--help` | `-h` | Show help message |

## Integration with CI/CD

This local build system complements the automated CI/CD pipeline:

- **Local**: Development and testing (`./build.sh`)
- **CI/CD**: Automated builds on push/release

Both use the same Docker configuration for consistency.

## Troubleshooting

### Common Issues

**"Docker is not running"**
```bash
# Start Docker Desktop or service
sudo systemctl start docker  # Linux
```

**"Component directory not found"**
```bash
# Make sure you're in the local-build directory
cd /path/to/nebulagraph/local-build
```

**"Authentication failed"**
```bash
# Reset authentication
rm .docker_token
./build.sh --force-login
```

**Build errors**
```bash
# Check component directory
ls -la ../src/dapr-pluggable-components/

# Verify Go version
cd ../src/dapr-pluggable-components
go version
```

### Getting Help

Run `./build.sh --help` for detailed usage information.

For CI/CD issues, see: `../docs/ci-cd.md`

## Migration from Old Scripts

If you were using the previous individual scripts in `src/dapr-pluggable-components/`:

**Old way:**
```bash
cd src/dapr-pluggable-components
./docker_login.sh
./local_docker_build.sh v1.0.0
```

**New way:**
```bash
cd local-build
./build.sh -t v1.0.0
```

The old scripts can be safely removed as this unified script provides all functionality.
