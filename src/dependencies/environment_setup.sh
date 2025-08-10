#!/bin/bash

# Load environment configuration if available
if [ -f "../.env" ]; then
    source ../.env
fi

# NebulaGraph Environment Management Script
# Complete management of NebulaGraph infrastructure including setup, operations, and maintenance

set -e

# Set default values if not already set
NEBULA_NETWORK_NAME=${NEBULA_NETWORK_NAME:-nebula-net}
NEBULA_PORT=${NEBULA_PORT:-9669}
NEBULA_USERNAME=${NEBULA_USERNAME:-root}
NEBULA_PASSWORD=${NEBULA_PASSWORD:-nebula}
NEBULA_SPACE=${NEBULA_SPACE:-dapr_state}
NEBULA_META_PORT=${NEBULA_META_PORT:-9559}
NEBULA_STORAGE_PORT=${NEBULA_STORAGE_PORT:-9779}
NEBULA_HTTP_PORT=${NEBULA_HTTP_PORT:-19669}
NEBULA_META_HTTP_PORT=${NEBULA_META_HTTP_PORT:-19559}
NEBULA_STORAGE_HTTP_PORT=${NEBULA_STORAGE_HTTP_PORT:-19779}
REDIS_HOST_PORT=${REDIS_HOST_PORT:-6380}
REDIS_PASSWORD=${REDIS_PASSWORD:-dapr_redis}
NEBULA_STUDIO_PORT=${NEBULA_STUDIO_PORT:-7001}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${BLUE}======================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}======================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get docker compose command (docker-compose or docker compose)
get_docker_compose_cmd() {
    if command_exists docker-compose; then
        echo "docker-compose"
    elif command_exists docker && docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    else
        return 1
    fi
}

# Initialize Dapr with Docker Desktop workarounds
# Addresses Docker Desktop connectivity issues documented in:
# https://github.com/dapr/dapr/issues/5011
initialize_dapr_with_workarounds() {
    print_info "Initializing Dapr runtime with Docker Desktop compatibility..."
    
    # Pre-check: Ensure Docker is accessible
    if ! docker ps >/dev/null 2>&1; then
        print_warning "Docker connectivity issue detected - applying workarounds before Dapr init"
        if ! fix_docker_connectivity; then
            print_error "Could not establish Docker connectivity"
            return 1
        fi
    fi
    
    # First, try standard dapr init
    if dapr init; then
        print_success "Dapr runtime initialized successfully"
        print_info "Dapr Redis runs on port 6379, our Redis will use port $REDIS_HOST_PORT"
        return 0
    fi
    
    print_warning "Standard Dapr init failed - applying Docker Desktop workarounds..."
    
    # Apply Docker fixes and retry
    if fix_docker_connectivity && dapr init; then
        print_success "Dapr runtime initialized successfully after Docker connectivity fix"
        print_info "Dapr Redis runs on port 6379, our Redis will use port $REDIS_HOST_PORT"
        return 0
    fi
    
    # Fallback: Use slim mode (no containers) - ONLY if explicitly requested
    print_warning "All Docker connectivity workarounds failed"
    print_error "Cannot initialize Dapr in container mode (required for Docker-based applications)"
    print_info "This setup requires full Dapr init with containers for proper Docker integration"
    
    print_info "Manual steps to resolve (choose one):"
    local docker_endpoint=$(get_docker_endpoint)
    if [ -n "$docker_endpoint" ]; then
        print_info "  1. Set DOCKER_HOST manually: export DOCKER_HOST=$docker_endpoint && dapr init"
        print_info "  2. Create socket symlink: sudo ln -s ${docker_endpoint#unix://} /var/run/docker.sock && dapr init"
    else
        print_info "  1. Set DOCKER_HOST manually: export DOCKER_HOST=unix://\$HOME/.docker/desktop/docker.sock && dapr init"
        print_info "  2. Create socket symlink: sudo ln -s \$HOME/.docker/desktop/docker.sock /var/run/docker.sock && dapr init"
    fi
    print_info "  3. Enable 'Allow the default Docker socket to be used' in Docker Desktop Settings > Advanced"
    print_info "  4. Install Docker Engine instead of Docker Desktop"
    print_info "  5. Use Kubernetes mode: dapr init -k"
    print_info "  6. Reference: https://github.com/dapr/dapr/issues/5011"
    
    print_warning "Attempting slim mode as last resort (may not work with Docker applications)..."
    
    if dapr init --slim; then
        print_warning "Dapr runtime initialized in slim mode"
        print_warning "WARNING: Slim mode may not work properly with Docker-based applications"
        print_warning "Consider fixing Docker connectivity and re-running with container mode"
        return 0
    fi
    
    # Final failure
    print_error "Failed to initialize Dapr runtime in any mode"
    return 1
}

# Connect Dapr containers to nebula-net network for Docker-based applications
connect_dapr_to_nebula_network() {
    print_info "Connecting Dapr containers to nebula-net network..."
    
    # Check if nebula-net exists
    if ! docker network ls --filter "name=^${NEBULA_NETWORK_NAME}$" --format "{{.Name}}" | grep -q "^${NEBULA_NETWORK_NAME}$"; then
        print_warning "nebula-net network does not exist yet"
        return 0
    fi
    
    # List of Dapr containers that need to be connected to nebula-net
    local dapr_containers=("dapr_placement" "dapr_redis" "dapr_zipkin" "dapr_scheduler")
    local connected_count=0
    
    for container in "${dapr_containers[@]}"; do
        # Check if container exists and is running
        if docker ps --filter "name=^${container}$" --format "{{.Names}}" | grep -q "^${container}$"; then
            # Check if already connected to nebula-net
            local networks=$(docker inspect "$container" --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' 2>/dev/null)
            if [[ $networks == *"$NEBULA_NETWORK_NAME"* ]]; then
                print_info "Container $container already connected to $NEBULA_NETWORK_NAME"
            else
                # Connect to nebula-net
                if docker network connect "$NEBULA_NETWORK_NAME" "$container" 2>/dev/null; then
                    print_success "Connected $container to $NEBULA_NETWORK_NAME network"
                    ((connected_count++))
                else
                    print_warning "Failed to connect $container to $NEBULA_NETWORK_NAME network"
                fi
            fi
        else
            print_info "Container $container not running, skipping..."
        fi
    done
    
    if [ $connected_count -gt 0 ]; then
        print_success "Connected $connected_count Dapr container(s) to $NEBULA_NETWORK_NAME network"
        print_info "Dapr placement service is now accessible at dapr_placement:50005"
    fi
}

# Get Docker endpoint from current context
get_docker_endpoint() {
    if ! command_exists docker; then
        return 1
    fi
    
    local docker_endpoint=""
    if command_exists jq; then
        docker_endpoint=$(docker context ls --format json 2>/dev/null | jq -r '.[] | select(.Current == true) | .DockerEndpoint' 2>/dev/null || echo "")
    else
        # For Docker Desktop, try common paths as fallback
        local current_context=$(docker context ls 2>/dev/null | grep -E '^\S+\s+\*' | awk '{print $1}' 2>/dev/null || echo "unknown")
        if [[ "$current_context" == "desktop-linux" ]]; then
            docker_endpoint="unix://$HOME/.docker/desktop/docker.sock"
        fi
    fi
    echo "$docker_endpoint"
}

# Fix Docker connectivity issues
fix_docker_connectivity() {
    print_info "Attempting Docker connectivity fixes..."
    
    # Check Docker context - common issue with Docker Desktop
    local current_context=""
    if command_exists docker; then
        # Try with jq first, fall back to basic parsing if jq not available
        if command_exists jq; then
            current_context=$(docker context ls --format json 2>/dev/null | jq -r '.[] | select(.Current == true) | .Name' 2>/dev/null || echo "unknown")
        else
            # Fallback: basic grep parsing when jq not available
            current_context=$(docker context ls 2>/dev/null | grep -E '^\S+\s+\*' | awk '{print $1}' 2>/dev/null || echo "unknown")
        fi
        print_info "Current Docker context: $current_context"
        
        # Get Docker endpoint for potential DOCKER_HOST fix
        local docker_endpoint=$(get_docker_endpoint)
        if [ -n "$docker_endpoint" ]; then
            print_info "Docker endpoint: $docker_endpoint"
        fi
    fi
    
    # Workaround 1: Set DOCKER_HOST for Docker Desktop contexts
    if [[ "$current_context" == "desktop-linux" ]] || [[ "$docker_endpoint" == *"/.docker/desktop/"* ]]; then
        print_info "Detected Docker Desktop context - applying DOCKER_HOST workaround..."
        
        if [ -n "$docker_endpoint" ]; then
            export DOCKER_HOST="$docker_endpoint"
            print_info "Set DOCKER_HOST=$DOCKER_HOST"
            
            # Test Docker connectivity
            if docker ps >/dev/null 2>&1; then
                print_success "Docker connectivity restored with DOCKER_HOST"
                return 0
            fi
            
            # Reset DOCKER_HOST if it didn't work
            unset DOCKER_HOST
        fi
    fi
    
    # Workaround 2: Create symlink for Docker socket (Linux/macOS)
    local default_socket="/var/run/docker.sock"
    if [ ! -S "$default_socket" ] && [ -n "$docker_endpoint" ] && [[ "$docker_endpoint" == unix://* ]]; then
        local actual_socket="${docker_endpoint#unix://}"
        if [ -S "$actual_socket" ]; then
            print_info "Attempting Docker socket symlink workaround..."
            print_info "Creating symlink: $default_socket -> $actual_socket"
            
            if sudo ln -sf "$actual_socket" "$default_socket" 2>/dev/null; then
                print_success "Created Docker socket symlink"
                
                # Test Docker connectivity
                if docker ps >/dev/null 2>&1; then
                    print_success "Docker connectivity restored with socket symlink"
                    return 0
                fi
            else
                print_warning "Could not create Docker socket symlink (may need sudo access)"
                print_info "Please run manually: sudo ln -sf $actual_socket $default_socket"
            fi
        fi
    elif [ ! -S "$default_socket" ]; then
        # Try common Docker Desktop paths when endpoint detection fails
        local common_sockets=(
            "$HOME/.docker/desktop/docker.sock"
            "$HOME/.docker/run/docker.sock"
            "/usr/local/var/run/docker.sock"
        )
        
        for socket in "${common_sockets[@]}"; do
            if [ -S "$socket" ]; then
                print_info "Found Docker socket at $socket"
                print_info "Creating symlink: $default_socket -> $socket"
                
                if sudo ln -sf "$socket" "$default_socket" 2>/dev/null; then
                    print_success "Created Docker socket symlink"
                    
                    # Test Docker connectivity
                    if docker ps >/dev/null 2>&1; then
                        print_success "Docker connectivity restored with socket symlink"
                        return 0
                    fi
                else
                    print_warning "Could not create Docker socket symlink (may need sudo access)"
                    print_info "Please run manually: sudo ln -sf $socket $default_socket"
                fi
                break
            fi
        done
    fi
    
    # Workaround 3: Try setting Docker context to default
    if [ "$current_context" != "default" ] && command_exists docker; then
        print_info "Attempting to switch to default Docker context..."
        if docker context use default 2>/dev/null; then
            print_success "Switched to default Docker context"
            
            # Test Docker connectivity
            if docker ps >/dev/null 2>&1; then
                print_success "Docker connectivity restored with default context"
                return 0
            fi
            
            # Switch back to original context
            docker context use "$current_context" 2>/dev/null || true
        fi
    fi
    
    print_warning "Could not fix Docker connectivity automatically"
    return 1
}

# Install missing prerequisites
install_prerequisites() {
    print_header "Installing Missing Prerequisites"
    local install_needed=0
    local install_failed=0
    
    # Install Go if missing
    if ! command_exists go; then
        print_info "Installing Go 1.24.5..."
        if wget -q https://go.dev/dl/go1.24.5.linux-amd64.tar.gz; then
            if sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.24.5.linux-amd64.tar.gz; then
                export PATH=$PATH:/usr/local/go/bin
                echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
                rm -f go1.24.5.linux-amd64.tar.gz
                print_success "Go 1.24.5 installed successfully"
                install_needed=1
            else
                print_error "Failed to install Go"
                install_failed=1
            fi
        else
            print_error "Failed to download Go"
            install_failed=1
        fi
    fi
    
    # Install Dapr CLI and initialize if missing
    if ! command_exists dapr; then
        print_info "Installing Dapr CLI..."
        if wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash; then
            print_success "Dapr CLI installed successfully"
            
            # Add dapr to PATH if not already there
            export PATH=$PATH:$HOME/.dapr/bin
            echo 'export PATH=$PATH:$HOME/.dapr/bin' >> ~/.bashrc
            
            # Initialize Dapr with Docker Desktop compatibility
            if initialize_dapr_with_workarounds; then
                install_needed=1
            else
                print_error "Failed to initialize Dapr runtime"
                install_failed=1
            fi
        else
            print_error "Failed to install Dapr CLI"
            install_failed=1
        fi
    else
        # Check if Dapr is initialized by checking for Dapr directory
        print_info "Checking if Dapr runtime is initialized..."
        if [ -d "$HOME/.dapr" ] && [ -f "$HOME/.dapr/config.yaml" ]; then
            # Check if Dapr containers are running (full installation)
            local dapr_containers=$(docker ps --filter "name=dapr_" --format "{{.Names}}" 2>/dev/null)
            if [ -n "$dapr_containers" ]; then
                print_success "Dapr runtime is already initialized (full installation with containers)"
                print_info "Dapr Redis runs on port 6379, our Redis will use port $REDIS_HOST_PORT"
                # Connect Dapr containers to nebula-net for Docker-based applications
                connect_dapr_to_nebula_network
            else
                print_warning "Dapr configuration exists but no containers are running"
                print_info "Re-initializing Dapr with Docker Desktop compatibility..."
                if initialize_dapr_with_workarounds; then
                    install_needed=1
                    # Connect Dapr containers to nebula-net after initialization
                    connect_dapr_to_nebula_network
                else
                    print_error "Failed to re-initialize Dapr runtime"
                    install_failed=1
                fi
            fi
        else
            print_info "Dapr CLI found but runtime not initialized. Initializing with Docker Desktop compatibility..."
            if initialize_dapr_with_workarounds; then
                install_needed=1
                # Connect Dapr containers to nebula-net after initialization
                connect_dapr_to_nebula_network
            else
                print_error "Failed to initialize Dapr runtime"
                install_failed=1
            fi
        fi
    fi
    
    # Install grpcurl if missing (requires Go to be installed first)
    if ! command_exists grpcurl; then
        if command_exists go; then
            print_info "Installing grpcurl..."
            if go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest; then
                # Add GOPATH/bin to PATH if not already there
                export PATH=$PATH:$(go env GOPATH)/bin
                echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bashrc
                print_success "grpcurl installed successfully"
                install_needed=1
            else
                print_error "Failed to install grpcurl"
                install_failed=1
            fi
        else
            print_warning "Go is required to install grpcurl. Install Go first."
            install_failed=1
        fi
    fi
    
    # Install missing system packages
    local missing_packages=()
    
    if ! command_exists curl; then
        missing_packages+=("curl")
    fi
    
    if ! command_exists jq; then
        missing_packages+=("jq")
    fi
    
    if [ ${#missing_packages[@]} -gt 0 ]; then
        print_info "Installing missing system packages: ${missing_packages[*]}"
        
        # Detect package manager and install
        if command_exists apt-get; then
            if sudo apt-get update && sudo apt-get install -y "${missing_packages[@]}"; then
                print_success "System packages installed successfully: ${missing_packages[*]}"
                install_needed=1
            else
                print_error "Failed to install system packages: ${missing_packages[*]}"
                install_failed=1
            fi
        elif command_exists yum; then
            if sudo yum install -y "${missing_packages[@]}"; then
                print_success "System packages installed successfully: ${missing_packages[*]}"
                install_needed=1
            else
                print_error "Failed to install system packages: ${missing_packages[*]}"
                install_failed=1
            fi
        elif command_exists dnf; then
            if sudo dnf install -y "${missing_packages[@]}"; then
                print_success "System packages installed successfully: ${missing_packages[*]}"
                install_needed=1
            else
                print_error "Failed to install system packages: ${missing_packages[*]}"
                install_failed=1
            fi
        elif command_exists brew; then
            if brew install "${missing_packages[@]}"; then
                print_success "System packages installed successfully: ${missing_packages[*]}"
                install_needed=1
            else
                print_error "Failed to install system packages: ${missing_packages[*]}"
                install_failed=1
            fi
        else
            print_error "No supported package manager found. Please install manually: ${missing_packages[*]}"
            install_failed=1
        fi
    fi
    
    if [ $install_failed -eq 1 ]; then
        print_error "Some prerequisites failed to install"
        return 1
    fi
    
    if [ $install_needed -eq 1 ]; then
        print_info "Prerequisites installation completed. Please run 'source ~/.bashrc' or restart your terminal to update PATH."
        print_info "Alternatively, export the paths manually:"
        print_info "  export PATH=\$PATH:/usr/local/go/bin"
        if command_exists go; then
            print_info "  export PATH=\$PATH:\$(go env GOPATH)/bin"
        fi
    else
        print_success "All prerequisites are already installed"
    fi
    
    return 0
}

# Setup Docker network
setup_docker_network() {
    print_info "Setting up Docker network '$NEBULA_NETWORK_NAME'..."
    
    if docker network ls | grep -q "$NEBULA_NETWORK_NAME"; then
        print_success "Docker network '$NEBULA_NETWORK_NAME' already exists"
        
        # Check if network has active endpoints
        local active_endpoints=$(docker network inspect $NEBULA_NETWORK_NAME --format='{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null || echo "")
        if [ -n "$active_endpoints" ] && [ "$active_endpoints" != " " ]; then
            print_info "Network '$NEBULA_NETWORK_NAME' has active endpoints: $active_endpoints"
            print_info "This is expected if containers are already running"
        fi
    else
        print_info "Creating Docker network '$NEBULA_NETWORK_NAME'..."
        if docker network create "$NEBULA_NETWORK_NAME"; then
            print_success "Docker network '$NEBULA_NETWORK_NAME' created successfully"
        else
            print_error "Failed to create Docker network '$NEBULA_NETWORK_NAME'"
            print_info "This may be due to existing network conflicts"
            # Try to remove and recreate
            print_info "Attempting to remove existing network and recreate..."
            docker network rm "$NEBULA_NETWORK_NAME" 2>/dev/null || true
            sleep 2
            if docker network create "$NEBULA_NETWORK_NAME"; then
                print_success "Docker network '$NEBULA_NETWORK_NAME' recreated successfully"
            else
                print_error "Failed to create Docker network after cleanup"
                return 1
            fi
        fi
    fi
}

# Start NebulaGraph cluster
start_nebula_cluster() {
    print_info "Starting NebulaGraph cluster..."
    
    if [ -f "nebula/docker-compose.yml" ]; then
        local compose_cmd
        compose_cmd=$(get_docker_compose_cmd) || {
            print_error "Docker Compose is not installed or not in PATH"
            return 1
        }
        
        # Ensure network exists before starting
        setup_docker_network || {
            print_error "Failed to setup Docker network"
            return 1
        }
        
        # Try to start the cluster
        print_info "Starting containers with docker-compose..."
        cd nebula
        if $compose_cmd up -d; then
            print_success "NebulaGraph cluster started"
            print_info "Waiting for services to initialize..."
            sleep 20
        else
            print_warning "Initial startup failed, trying to recreate..."
            # If startup fails, try to recreate
            $compose_cmd down 2>/dev/null || true
            sleep 2
            
            # Recreate network if needed
            docker network rm "$NEBULA_NETWORK_NAME" 2>/dev/null || true
            if docker network create "$NEBULA_NETWORK_NAME"; then
                print_info "Network recreated, attempting to start containers again..."
                if $compose_cmd up -d; then
                    print_success "NebulaGraph cluster started after recreation"
                    print_info "Waiting for services to initialize..."
                    sleep 20
                else
                    print_error "Failed to start NebulaGraph cluster after recreation"
                    cd ..
                    return 1
                fi
            else
                print_error "Failed to recreate network"
                cd ..
                return 1
            fi
        fi
        cd ..
    else
        print_error "nebula/docker-compose.yml not found"
        return 1
    fi
}

# Start Redis service
start_redis_service() {
    print_info "Starting Redis service..."
    
    if [ -f "redis/docker-compose.yml" ]; then
        local compose_cmd
        compose_cmd=$(get_docker_compose_cmd) || {
            print_error "Docker Compose not available"
            return 1
        }
        
        # Ensure network exists before starting Redis
        setup_docker_network || {
            print_error "Failed to setup Docker network"
            return 1
        }
        
        print_info "Starting Redis container..."
        cd redis
        if $compose_cmd up -d; then
            print_success "Redis service started successfully"
            print_info "Waiting for Redis to initialize..."
            sleep 5
        else
            print_error "Failed to start Redis service"
            cd ..
            return 1
        fi
        cd ..
    else
        print_error "redis/docker-compose.yml not found"
        return 1
    fi
}

# Start ScyllaDB service
start_scylladb_service() {
    print_info "Starting ScyllaDB service..."
    
    if [ -f "scylladb/docker-compose.yml" ]; then
        local compose_cmd
        compose_cmd=$(get_docker_compose_cmd) || {
            print_error "Docker Compose not available"
            return 1
        }
        
        # Ensure network exists before starting ScyllaDB
        setup_docker_network || {
            print_error "Failed to setup Docker network"
            return 1
        }
        
        print_info "Starting ScyllaDB containers..."
        cd scylladb
        if $compose_cmd up -d; then
            print_success "ScyllaDB service started successfully"
            print_info "Waiting for ScyllaDB to initialize..."
            sleep 10
        else
            print_error "Failed to start ScyllaDB service"
            cd ..
            return 1
        fi
        cd ..
    else
        print_error "scylladb/docker-compose.yml not found"
        return 1
    fi
}

# Initialize Redis service
initialize_redis() {
    print_info "Initializing Redis service..."
    
    if [ -f "redis/init_redis.sh" ]; then
        cd redis
        ./init_redis.sh
        cd ..
        print_success "Redis service initialized"
    else
        print_error "redis/init_redis.sh not found"
        return 1
    fi
}

# Initialize ScyllaDB service
initialize_scylladb() {
    print_info "Initializing ScyllaDB service..."
    
    if [ -f "scylladb/init_scylladb.sh" ]; then
        cd scylladb
        ./init_scylladb.sh
        cd ..
        print_success "ScyllaDB service initialized"
    else
        print_error "scylladb/init_scylladb.sh not found"
        return 1
    fi
}

# Initialize NebulaGraph cluster
initialize_nebula() {
    print_info "Initializing NebulaGraph cluster..."
    
    if [ -f "nebula/init_nebula.sh" ]; then
        cd nebula
        ./init_nebula.sh
        cd ..
        print_success "NebulaGraph cluster initialized"
    else
        print_error "nebula/init_nebula.sh not found"
        return 1
    fi
}

# Wait for NebulaGraph to be ready
wait_for_nebula_ready() {
    print_info "Waiting for NebulaGraph cluster to be ready..."
    
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker exec nebula-console sh -c '/usr/local/bin/nebula-console -addr nebula-graphd -port 9669 -u root -p nebula -e "SHOW HOSTS;" > /dev/null 2>&1'; then
            print_success "NebulaGraph cluster is ready and responsive"
            break
        else
            attempt=$((attempt + 1))
            print_info "Waiting for NebulaGraph cluster... (attempt $attempt/$max_attempts)"
            sleep 5
        fi
    done
    
    if [ $attempt -eq $max_attempts ]; then
        print_error "NebulaGraph cluster failed to start within expected time"
        return 1
    fi
    
    # Verify the dapr_state space exists
    if docker exec nebula-console sh -c '/usr/local/bin/nebula-console -addr nebula-graphd -port 9669 -u root -p nebula -e "USE dapr_state; SHOW TAGS;" > /dev/null 2>&1'; then
        print_success "NebulaGraph dapr_state space is ready and accessible"
    else
        print_warning "dapr_state space verification failed - may need manual check"
    fi
    
    # Verify Redis is ready
    print_info "Verifying Redis connectivity..."
    local redis_attempts=10
    local redis_attempt=0
    
    while [ $redis_attempt -lt $redis_attempts ]; do
        if docker exec redis redis-cli -a dapr_redis ping >/dev/null 2>&1; then
            print_success "Redis is ready and accepting connections"
            break
        else
            redis_attempt=$((redis_attempt + 1))
            print_info "Waiting for Redis... (attempt $redis_attempt/$redis_attempts)"
            sleep 2
        fi
    done
    
    if [ $redis_attempt -eq $redis_attempts ]; then
        print_warning "Redis verification failed - may need manual check"
    fi
}

# Stop NebulaGraph cluster
# Stop NebulaGraph cluster
stop_nebula_cluster() {
    print_info "Stopping NebulaGraph cluster..."
    if [ -f "nebula/docker-compose.yml" ]; then
        local compose_cmd
        compose_cmd=$(get_docker_compose_cmd) || {
            print_error "Docker Compose not available"
            return 1
        }
        cd nebula
        $compose_cmd down
        cd ..
        print_success "NebulaGraph cluster stopped"
    else
        print_error "nebula/docker-compose.yml not found"
        return 1
    fi
}

# Stop Redis service
stop_redis_service() {
    print_info "Stopping Redis service..."
    if [ -f "redis/docker-compose.yml" ]; then
        local compose_cmd
        compose_cmd=$(get_docker_compose_cmd) || {
            print_error "Docker Compose not available"
            return 1
        }
        cd redis
        $compose_cmd down
        cd ..
        print_success "Redis service stopped"
    else
        print_error "redis/docker-compose.yml not found"
        return 1
    fi
}

# Stop ScyllaDB service
stop_scylladb_service() {
    print_info "Stopping ScyllaDB service..."
    if [ -f "scylladb/docker-compose.yml" ]; then
        local compose_cmd
        compose_cmd=$(get_docker_compose_cmd) || {
            print_error "Docker Compose not available"
            return 1
        }
        cd scylladb
        $compose_cmd down
        cd ..
        print_success "ScyllaDB service stopped"
    else
        print_error "scylladb/docker-compose.yml not found"
        return 1
    fi
}

# Stop all services
stop_all_services() {
    print_header "Stopping All Services"
    stop_scylladb_service
    stop_redis_service
    stop_nebula_cluster
    print_success "All services stopped"
}

# Show cluster status
show_nebula_status() {
    print_header "NebulaGraph Dependencies Status"
    if [ -f "nebula/docker-compose.yml" ]; then
        local compose_cmd
        compose_cmd=$(get_docker_compose_cmd) || {
            print_error "Docker Compose is not installed or not in PATH"
            return 1
        }
        cd nebula
        $compose_cmd ps
        cd ..
    else
        print_error "nebula/docker-compose.yml not found"
        return 1
    fi
}

# Show cluster logs
show_nebula_logs() {
    print_header "NebulaGraph Dependencies Logs"
    if [ -f "nebula/docker-compose.yml" ]; then
        local compose_cmd
        compose_cmd=$(get_docker_compose_cmd) || {
            print_error "Docker Compose is not installed or not in PATH"
            return 1
        }
        cd nebula
        $compose_cmd logs -f
        cd ..
    else
        print_error "nebula/docker-compose.yml not found"
        return 1
    fi
}

# Clean cluster (remove volumes and networks)
clean_nebula_cluster() {
    print_header "Cleaning NebulaGraph Dependencies"
    if [ -f "nebula/docker-compose.yml" ]; then
        local compose_cmd
        compose_cmd=$(get_docker_compose_cmd) || {
            print_error "Docker Compose is not installed or not in PATH"
            return 1
        }
        
        print_info "Stopping and removing containers and volumes..."
        cd nebula
        $compose_cmd down -v --remove-orphans
        cd ..
        
        # Also remove the network if it exists
        if docker network ls | grep -q "$NEBULA_NETWORK_NAME"; then
            print_info "Removing Docker network '$NEBULA_NETWORK_NAME'..."
            if docker network rm "$NEBULA_NETWORK_NAME" 2>/dev/null; then
                print_success "Docker network '$NEBULA_NETWORK_NAME' removed"
            else
                print_warning "Could not remove network '$NEBULA_NETWORK_NAME' (may still be in use)"
            fi
        fi
        
        print_success "NebulaGraph dependencies cleaned"
    else
        print_error "nebula/docker-compose.yml not found"
        return 1
    fi
}

# Quick test of essential services
quick_test_services() {
    print_info "Running quick connectivity test..."
    
    local tests_passed=0
    local total_tests=3
    
    # Test NebulaGraph
    if nc -z localhost 9669 2>/dev/null; then
        print_success "NebulaGraph Graph Service (port 9669) - OK"
        tests_passed=$((tests_passed + 1))
    else
        print_error "NebulaGraph Graph Service (port 9669) - FAILED"
    fi
    
    # Test Redis on our configured port
    if nc -z localhost $REDIS_HOST_PORT 2>/dev/null; then
        print_success "Redis Service (port $REDIS_HOST_PORT) - OK"
        tests_passed=$((tests_passed + 1))
    else
        print_error "Redis Service (port $REDIS_HOST_PORT) - FAILED"
    fi
    
    # Test NebulaGraph Studio
    if curl -s --connect-timeout 5 http://localhost:7001 >/dev/null 2>&1; then
        print_success "NebulaGraph Studio (port 7001) - OK"
        tests_passed=$((tests_passed + 1))
    else
        print_warning "NebulaGraph Studio (port 7001) - Not responding"
    fi
    
    echo ""
    if [ $tests_passed -eq $total_tests ]; then
        print_success "All essential services are running! ($tests_passed/$total_tests)"
    elif [ $tests_passed -gt 0 ]; then
        print_warning "Some services are running ($tests_passed/$total_tests)"
    else
        print_error "No services are responding ($tests_passed/$total_tests)"
    fi
}

# Test NebulaGraph services connectivity
test_nebula_services() {
    print_header "Testing NebulaGraph and Redis Dependencies"
    
    # Test NebulaGraph Graph Service
    print_info "Testing NebulaGraph Graph Service (port 9669)..."
    if nc -z localhost 9669 2>/dev/null; then
        print_success "NebulaGraph Graph Service is responding"
    else
        print_error "NebulaGraph Graph Service is not responding on port 9669"
    fi
    
    # Test Redis Service on our configured port
    print_info "Testing Redis Service (port $REDIS_HOST_PORT)..."
    if nc -z localhost $REDIS_HOST_PORT 2>/dev/null; then
        print_success "Redis Service is responding on port $REDIS_HOST_PORT"
        
        # Test Redis authentication
        if command_exists redis-cli; then
            if redis-cli -h localhost -p $REDIS_HOST_PORT -a $REDIS_PASSWORD ping >/dev/null 2>&1; then
                print_success "Redis authentication is working"
            else
                print_warning "Redis is running but authentication failed"
            fi
        else
            print_info "redis-cli not available for authentication test"
        fi
    else
        print_error "Redis Service is not responding on port $REDIS_HOST_PORT"
    fi
    
    # Test NebulaGraph Studio
    print_info "Testing NebulaGraph Studio (port 7001)..."
    if curl -s --connect-timeout 5 http://localhost:7001 >/dev/null 2>&1; then
        print_success "NebulaGraph Studio is responding"
    else
        print_error "NebulaGraph Studio is not responding on port 7001"
    fi
    
    # Test Meta Service
    print_info "Testing NebulaGraph Meta Service (port 9559)..."
    if nc -z localhost 9559 2>/dev/null; then
        print_success "NebulaGraph Meta Service is responding"
    else
        print_error "NebulaGraph Meta Service is not responding on port 9559"
    fi
    
    # Test Storage Service
    print_info "Testing NebulaGraph Storage Service (port 9779)..."
    if nc -z localhost 9779 2>/dev/null; then
        print_success "NebulaGraph Storage Service is responding"
    else
        print_error "NebulaGraph Storage Service is not responding on port 9779"
    fi
}

# Check if all required containers are running
check_all_containers_running() {
    local required_containers=("nebula-metad" "nebula-storaged" "nebula-graphd" "nebula-console" "nebula-studio" "redis-pubsub" "scylladb-node1" "scylla-manager")
    local running_count=0
    local total_count=${#required_containers[@]}
    
    print_info "Checking if all required containers are running..."
    
    for container in "${required_containers[@]}"; do
        if docker ps --filter "name=^${container}$" --filter "status=running" --format "{{.Names}}" | grep -q "^${container}$"; then
            running_count=$((running_count + 1))
            print_success "Container '$container' is running"
        else
            print_info "Container '$container' is not running"
        fi
    done
    
    if [ $running_count -eq $total_count ]; then
        return 0  # All containers are running
    else
        return 1  # Not all containers are running
    fi
}

# Check for existing containers and handle them
check_existing_containers() {
    print_info "Checking for existing NebulaGraph and Redis containers..."
    
    # Define the containers we expect from docker-compose
    local expected_containers=("nebula-metad" "nebula-storaged" "nebula-graphd" "nebula-console" "nebula-studio" "redis")
    
    # Check if all containers are running
    if check_all_containers_running; then
        print_success "All NebulaGraph and Redis containers are already running!"
        print_info "The environment appears to be already set up and operational."
        echo ""
        print_warning "Do you want to:"
        echo "  1) Keep the current setup (recommended if working)"
        echo "  2) Stop and clean all containers to start fresh"
        echo "  3) Just test the current setup"
        echo ""
        echo -n "Enter your choice (1/2/3): "
        read -r response
        
        case "$response" in
            "1"|"")
                print_success "Keeping current setup. Testing connectivity..."
                quick_test_services
                echo ""
                print_info "Environment is ready to use!"
                exit 0
                ;;
            "2")
                print_info "Stopping and cleaning existing containers..."
                clean_nebula_cluster
                # Also clean up network
                docker network rm "$NEBULA_NETWORK_NAME" 2>/dev/null || true
                print_success "Existing containers and network cleaned"
                return 0
                ;;
            "3")
                quick_test_services
                exit 0
                ;;
            *)
                print_info "Invalid choice. Keeping current setup."
                exit 0
                ;;
        esac
    fi
    
    # Check for any running containers (partial setup)
    local running_containers=$(docker ps --filter "name=nebula-" --filter "name=redis" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null | grep -v "^NAMES")
    local all_containers=$(docker ps -a --filter "name=nebula-" --filter "name=redis" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null | grep -v "^NAMES")
    
    if [ -n "$running_containers" ] && [ "$running_containers" != "" ]; then
        print_warning "Found some running containers (partial setup):"
        echo "NAMES	STATUS"
        echo "$running_containers"
        echo ""
        print_info "These containers need to be stopped before setting up a clean environment."
        echo -n "Do you want to stop and clean existing containers? (y/N): "
        read -r response
        
        case "$response" in
            [yY]|[yY][eE][sS])
                print_info "Stopping and cleaning existing containers..."
                clean_nebula_cluster
                # Also clean up network
                docker network rm "$NEBULA_NETWORK_NAME" 2>/dev/null || true
                print_success "Existing containers and network cleaned"
                ;;
            *)
                print_info "Setup cancelled by user. Please stop containers manually or run with 'clean' option."
                exit 0
                ;;
        esac
    elif [ -n "$all_containers" ] && [ "$all_containers" != "" ]; then
        print_warning "Found stopped containers:"
        echo "NAMES	STATUS"
        echo "$all_containers"
        echo ""
        echo -n "Do you want to clean existing containers before setup? (y/N): "
        read -r response
        
        case "$response" in
            [yY]|[yY][eE][sS])
                print_info "Cleaning existing containers..."
                clean_nebula_cluster
                # Also clean up network  
                docker network rm "$NEBULA_NETWORK_NAME" 2>/dev/null || true
                print_success "Existing containers and network cleaned"
                ;;
            *)
                print_info "Continuing with existing containers..."
                ;;
        esac
    else
        print_success "No existing NebulaGraph or Redis containers found"
    fi
}

# Main setup function
main() {
    print_header "NebulaGraph Environment Setup"
    echo -e "This script sets up the NebulaGraph infrastructure environment.\n"
    
    # Check for existing containers first
    check_existing_containers
    
    local overall_success=0
    
    # 1. Check prerequisites
    print_header "1. Prerequisites Check"
    
    if command_exists docker; then
        print_success "Docker is available: $(docker --version)"
    else
        print_error "Docker is not installed or not in PATH"
        overall_success=1
    fi
    
    # Check for Docker Compose (both v1 and v2)
    local compose_cmd
    if compose_cmd=$(get_docker_compose_cmd); then
        if [[ "$compose_cmd" == "docker-compose" ]]; then
            print_success "Docker Compose v1 is available: $(docker-compose --version)"
        else
            print_success "Docker Compose v2 is available: $(docker compose version)"
        fi
    else
        print_error "Docker Compose is not installed or not in PATH"
        print_info "Install Docker Compose: curl -L \"https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose"
        overall_success=1
    fi
    
    if command_exists dapr; then
        local dapr_version=$(dapr --version | head -n1)
        print_success "Dapr CLI is available: $dapr_version"
        
        # Check if Dapr runtime is initialized by checking for runtime directory
        if [ -d "$HOME/.dapr" ] && [ -f "$HOME/.dapr/config.yaml" ]; then
            # Check if Dapr containers are running (full installation)
            local dapr_containers=$(docker ps --filter "name=dapr_" --format "{{.Names}}" 2>/dev/null)
            if [ -n "$dapr_containers" ]; then
                print_success "Dapr runtime is initialized (full installation with containers)"
                print_info "Dapr Redis runs on port 6379, our Redis will use port $REDIS_HOST_PORT"
            else
                # Check if it's slim mode by looking for specific files
                if [ -f "$HOME/.dapr/bin/daprd" ]; then
                    print_success "Dapr runtime is initialized (slim mode - no containers)"
                    print_info "Dapr will run in standalone mode (compatible with Docker Desktop)"
                else
                    print_warning "Dapr configuration exists but no containers are running"
                    print_info "Dapr runtime needs to be re-initialized"
                    overall_success=1
                fi
            fi
        else
            print_warning "Dapr CLI found but runtime not initialized"
            print_info "Runtime needs to be initialized"
            overall_success=1
        fi
    else
        print_error "Dapr CLI is not installed or not in PATH"
        print_info "Install Dapr: wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash"
        print_info "           dapr init  # Initialize runtime (with containers)"
        overall_success=1
    fi
    
    if command_exists go; then
        local go_version=$(go version | awk '{print $3}' | sed 's/go//')
        local required_version="1.24.5"
        
        # Simple version comparison - works for most cases
        if [ "$(printf '%s\n' "$required_version" "$go_version" | sort -V | head -n1)" = "$required_version" ]; then
            print_success "Go is available: $(go version)"
        else
            print_error "Go version $go_version is installed but requires at least $required_version"
            print_info "Install Go: wget https://go.dev/dl/go1.24.5.linux-amd64.tar.gz && sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.24.5.linux-amd64.tar.gz"
            print_info "Add to PATH: export PATH=\$PATH:/usr/local/go/bin"
            overall_success=1
        fi
    else
        print_error "Go is not installed or not in PATH"
        print_info "Install Go: wget https://go.dev/dl/go1.24.5.linux-amd64.tar.gz && sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.24.5.linux-amd64.tar.gz"
        print_info "Add to PATH: export PATH=\$PATH:/usr/local/go/bin"
        overall_success=1
    fi

    # Testing Prerequisites
    print_header "Testing Prerequisites"
    
    if command_exists curl; then
        print_success "curl is available: $(curl --version | head -n1)"
    else
        print_error "curl is not installed (required for HTTP API testing)"
        print_info "Install curl: sudo apt-get install curl  # Ubuntu/Debian"
        print_info "             sudo yum install curl      # RHEL/CentOS"
        print_info "             brew install curl          # macOS"
        overall_success=1
    fi
    
    if command_exists grpcurl; then
        print_success "grpcurl is available: $(grpcurl --version 2>&1 | head -n1)"
    else
        print_error "grpcurl is not installed (required for gRPC API testing)"
        print_info "Install grpcurl: go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest"
        print_info "                sudo apt-get install grpcurl  # Ubuntu/Debian (if available)"
        print_info "                brew install grpcurl          # macOS"
        overall_success=1
    fi
    
    if command_exists jq; then
        print_success "jq is available: $(jq --version)"
    else
        print_error "jq is not installed (required for JSON parsing in tests)"
        print_info "Install jq: sudo apt-get install jq  # Ubuntu/Debian"
        print_info "           sudo yum install jq      # RHEL/CentOS" 
        print_info "           brew install jq          # macOS"
        overall_success=1
    fi
    
    if [ $overall_success -ne 0 ]; then
        print_warning "Prerequisites not met. Attempting to install missing components automatically..."
        
        # Attempt to install missing prerequisites
        if install_prerequisites; then
            print_success "Prerequisites installation completed successfully"
            print_info "Continuing with environment setup..."
        else
            print_error "Failed to install prerequisites automatically"
            print_info "Manual installation may be required. Use the commands shown above."
            exit 1
        fi
    fi
    
    # 2. Start services one by one
    print_header "2. Starting Infrastructure Services"
    
    # Start NebulaGraph cluster first (includes network setup)
    print_header "2.1. NebulaGraph Cluster Setup"
    start_nebula_cluster
    
    # Start Redis service
    print_header "2.2. Redis Service Setup"
    start_redis_service
    
    # Start ScyllaDB service
    print_header "2.3. ScyllaDB Service Setup"
    start_scylladb_service
    
    # 3. Initialize services one by one
    print_header "3. Initializing Services"
    
    # Initialize NebulaGraph
    print_header "3.1. NebulaGraph Initialization"
    initialize_nebula
    
    # Initialize Redis
    print_header "3.2. Redis Initialization"
    initialize_redis
    
    # Initialize ScyllaDB
    print_header "3.3. ScyllaDB Initialization"
    initialize_scylladb
    
    # 4. Wait for services to be ready
    print_header "4. Services Readiness Check"
    wait_for_nebula_ready
    
    # 5. Connect Dapr containers to nebula-net network
    print_header "5. Dapr Network Integration"
    connect_dapr_to_nebula_network
    
    # 6. Final summary
    print_header "Infrastructure Environment Ready"
    
    print_success "🎉 Multi-service environment setup completed successfully!"
    echo -e "\n${GREEN}Your infrastructure is ready with all services!${NC}"
    echo -e "\n${BLUE}Available services:${NC}"
    echo -e "  • NebulaGraph Cluster: nebula-graphd:9669"
    echo -e "  • Redis Pub/Sub: redis-pubsub:6379 (host port: $REDIS_HOST_PORT)"
    echo -e "  • ScyllaDB State Store: scylladb-node1:9042"
    echo -e "  • NebulaGraph Studio: http://localhost:7001"
    echo -e "  • ScyllaDB Manager: http://localhost:7002"
    
    echo -e "\n${BLUE}Dapr Components Available:${NC}"
    echo -e "  • State Store: nebulagraph-state (NebulaGraph backend)"
    echo -e "  • State Store: scylladb-state (ScyllaDB backend)"
    echo -e "  • Pub/Sub: redis-pubsub (Redis backend)"
    
    echo -e "\n${BLUE}Next steps:${NC}"
    echo -e "  • Start applications that use these services"
    echo -e "  • Test pub/sub: dapr publish --publish-app-id myapp --pubsub redis-pubsub --topic test --data '{\"message\":\"hello\"}'"
    echo -e "  • View logs: ./environment_setup.sh logs"
    echo -e "  • Stop environment: ./environment_setup.sh stop"
    echo -e "  • Status check: ./environment_setup.sh status"
    
    echo ""
}

# Handle command line arguments
case "${1:-setup}" in
    "setup"|"start")
        main
        ;;
    "install-prereqs")
        install_prerequisites
        ;;
    "stop"|"down")
        stop_all_services
        ;;
    "status")
        show_nebula_status
        ;;
    "logs")
        show_nebula_logs
        ;;
    "clean")
        clean_nebula_cluster
        ;;
    "init")
        print_header "Initializing NebulaGraph Cluster"
        initialize_nebula
        ;;
    "test")
        test_nebula_services
        ;;
    "quick-test"|"qt")
        print_header "Quick Service Test"
        quick_test_services
        ;;
    "dapr-status"|"ds")
        print_header "Dapr Runtime Status"
        if command_exists dapr; then
            dapr_containers=$(docker ps --filter "name=dapr_" --format "{{.Names}}" 2>/dev/null)
            if [ -n "$dapr_containers" ]; then
                docker ps --filter "name=dapr_" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
                echo ""
                print_success "Dapr runtime is running (container mode)"
            else
                # Check if slim mode is installed
                if [ -f "$HOME/.dapr/bin/daprd" ]; then
                    print_warning "Dapr runtime is installed (slim mode - no containers)"
                    print_info "Runtime version: $(dapr --version | grep 'Runtime version' | cut -d' ' -f3)"
                    print_info "CLI version: $(dapr --version | grep 'CLI version' | cut -d' ' -f3)"
                    print_info "Dapr binary location: $HOME/.dapr/bin/daprd"
                    print_warning "WARNING: Slim mode may not work properly with Docker-based applications"
                    print_info "Consider running './environment_setup.sh dapr-reinit' to switch to container mode"
                elif [ -d "$HOME/.dapr" ]; then
                    print_warning "Dapr configuration directory exists but runtime may not be fully installed"
                    print_info "Run './environment_setup.sh install-prereqs' to complete installation"
                else
                    print_warning "Dapr CLI is installed but no containers are running and no slim mode detected"
                    print_info "Run 'dapr init' or 'dapr init --slim' to initialize Dapr runtime"
                fi
            fi
        else
            print_error "Dapr CLI is not installed"
        fi
        ;;
    "dapr-reinit"|"dr")
        print_header "Forcing Dapr Reinitialization in Container Mode"
        if command_exists dapr; then
            print_info "Stopping existing Dapr runtime..."
            dapr uninstall 2>/dev/null || true
            
            print_info "Cleaning up Dapr containers..."
            docker stop $(docker ps -q --filter "name=dapr_") 2>/dev/null || true
            docker rm $(docker ps -aq --filter "name=dapr_") 2>/dev/null || true
            
            print_info "Re-initializing Dapr in container mode with Docker Desktop compatibility..."
            initialize_dapr_with_workarounds
        else
            print_error "Dapr CLI is not installed"
            print_info "Run './environment_setup.sh install-prereqs' first"
        fi
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [COMMAND]"
        echo ""
        echo "Multi-Service Infrastructure Environment Management"
        echo ""
        echo "Commands:"
        echo "  setup, start      Set up the complete infrastructure environment (default)"
        echo "  install-prereqs   Install missing prerequisites (Go, Dapr CLI + init, grpcurl)"
        echo "  stop, down        Stop all services (NebulaGraph, Redis, ScyllaDB)"
        echo "  status            Show all services status"
        echo "  logs              Show all services logs"
        echo "  init              Initialize all services"
        echo "  test              Full test of all services connectivity"
        echo "  quick-test, qt    Quick test of essential services"
        echo "  dapr-status, ds   Show Dapr runtime status and containers"
        echo "  dapr-reinit, dr   Force reinitialize Dapr in container mode (fixes slim mode)"
        echo "  clean             Clean up all services (volumes and networks)"
        echo "  help              Show this help message"
        echo ""
        echo "Setup will:"
        echo "  1. Check prerequisites (Docker, Docker Compose, Dapr CLI + runtime, Go 1.24.5+, curl, grpcurl, jq)"
        echo "  2. Start all services: NebulaGraph cluster, Redis, and ScyllaDB (includes network setup)"
        echo "  3. Initialize all services with required spaces/schemas/keyspaces"
        echo "  4. Wait for all services to be ready"
        echo ""
        echo "Access Points:"
        echo "  • NebulaGraph Studio: http://localhost:7001"
        echo "  • ScyllaDB Manager: http://localhost:7002"
        echo "  • NebulaGraph Graph Service: localhost:9669"
        echo "  • NebulaGraph Meta Service: localhost:$NEBULA_META_PORT"
        echo "  • NebulaGraph Storage Service: localhost:$NEBULA_STORAGE_PORT"
        echo "  • Redis Pub/Sub Service: localhost:$REDIS_HOST_PORT (password: $REDIS_PASSWORD)"
        echo "  • ScyllaDB CQL Service: localhost:9042"
        echo ""
        echo "Dapr Components:"
        echo "  • State Store: nebulagraph-state (NebulaGraph backend)"
        echo "  • State Store: scylladb-state (ScyllaDB backend)"
        echo "  • Pub/Sub: redis-pubsub (Redis backend)"
        echo ""
        echo "After running setup, you can start applications that use these services."
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
