#!/bin/bash

# NebulaGraph Environment Management Script
# Complete management of NebulaGraph infrastructure including setup, operations, and maintenance

set -e

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

# Install missing prerequisites
install_prerequisites() {
    print_header "Installing Missing Prerequisites"
    local install_needed=0
    
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
                return 1
            fi
        else
            print_error "Failed to download Go"
            return 1
        fi
    fi
    
    # Install Dapr if missing
    if ! command_exists dapr; then
        print_info "Installing Dapr runtime..."
        if wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash; then
            print_success "Dapr runtime installed successfully"
            install_needed=1
        else
            print_error "Failed to install Dapr runtime"
            return 1
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
                return 1
            fi
        else
            print_warning "Go is required to install grpcurl. Install Go first."
        fi
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
}

# Setup Docker network
setup_docker_network() {
    print_info "Setting up Docker network..."
    local network_name="nebula-net"
    
    if docker network ls | grep -q "$network_name"; then
        print_success "Docker network '$network_name' already exists"
        
        # Check if network has active endpoints
        local active_endpoints=$(docker network inspect $network_name --format='{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null || echo "")
        if [ -n "$active_endpoints" ] && [ "$active_endpoints" != " " ]; then
            print_warning "Network '$network_name' has active endpoints: $active_endpoints"
            print_info "This is expected if containers are already running"
        fi
    else
        print_info "Creating Docker network '$network_name'..."
        if docker network create "$network_name"; then
            print_success "Docker network '$network_name' created"
        else
            print_error "Failed to create Docker network '$network_name'"
            print_info "This may be due to existing network conflicts"
            # Try to remove and recreate
            print_info "Attempting to remove existing network and recreate..."
            docker network rm "$network_name" 2>/dev/null || true
            sleep 2
            if docker network create "$network_name"; then
                print_success "Docker network '$network_name' recreated successfully"
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
    
    if [ -f "docker-compose.yml" ]; then
        local compose_cmd
        compose_cmd=$(get_docker_compose_cmd) || {
            print_error "Docker Compose is not installed or not in PATH"
            return 1
        }
        # Try to start the cluster
        if $compose_cmd up -d; then
            print_success "NebulaGraph cluster started"
            print_info "Waiting for services to initialize..."
            sleep 15
        else
            print_warning "Initial startup failed, trying to recreate..."
            # If startup fails due to network issues, try to recreate
            $compose_cmd down
            sleep 2
            # Remove and recreate network if needed
            if docker network ls | grep -q "nebula-net"; then
                print_info "Recreating Docker network..."
                docker network rm nebula-net 2>/dev/null || true
                docker network create nebula-net
            fi
            # Try starting again
            if $compose_cmd up -d; then
                print_success "NebulaGraph cluster started after recreation"
                print_info "Waiting for services to initialize..."
                sleep 15
            else
                print_error "Failed to start NebulaGraph cluster after recreation"
                return 1
            fi
        fi
    else
        print_error "docker-compose.yml not found in current directory"
        return 1
    fi
}

# Initialize NebulaGraph cluster
initialize_nebula() {
    print_info "Initializing NebulaGraph cluster..."
    
    if [ -f "init_nebula.sh" ]; then
        ./init_nebula.sh
        print_success "NebulaGraph cluster initialized"
    else
        print_error "init_nebula.sh not found in current directory"
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
}

# Stop NebulaGraph cluster
stop_nebula_cluster() {
    print_header "Stopping NebulaGraph Dependencies"
    if [ -f "docker-compose.yml" ]; then
        local compose_cmd
        compose_cmd=$(get_docker_compose_cmd) || {
            print_error "Docker Compose is not installed or not in PATH"
            return 1
        }
        $compose_cmd down
        print_success "NebulaGraph dependencies stopped"
    else
        print_error "docker-compose.yml not found in current directory"
        return 1
    fi
}

# Show cluster status
show_nebula_status() {
    print_header "NebulaGraph Dependencies Status"
    if [ -f "docker-compose.yml" ]; then
        local compose_cmd
        compose_cmd=$(get_docker_compose_cmd) || {
            print_error "Docker Compose is not installed or not in PATH"
            return 1
        }
        $compose_cmd ps
    else
        print_error "docker-compose.yml not found in current directory"
        return 1
    fi
}

# Show cluster logs
show_nebula_logs() {
    print_header "NebulaGraph Dependencies Logs"
    if [ -f "docker-compose.yml" ]; then
        local compose_cmd
        compose_cmd=$(get_docker_compose_cmd) || {
            print_error "Docker Compose is not installed or not in PATH"
            return 1
        }
        $compose_cmd logs -f
    else
        print_error "docker-compose.yml not found in current directory"
        return 1
    fi
}

# Clean cluster (remove volumes and networks)
clean_nebula_cluster() {
    print_header "Cleaning NebulaGraph Dependencies"
    if [ -f "docker-compose.yml" ]; then
        local compose_cmd
        compose_cmd=$(get_docker_compose_cmd) || {
            print_error "Docker Compose is not installed or not in PATH"
            return 1
        }
        $compose_cmd down -v --remove-orphans
        print_success "NebulaGraph dependencies cleaned"
    else
        print_error "docker-compose.yml not found in current directory"
        return 1
    fi
}

# Test NebulaGraph services connectivity
test_nebula_services() {
    print_header "Testing NebulaGraph Dependencies"
    
    # Test NebulaGraph Graph Service
    print_info "Testing NebulaGraph Graph Service (port 9669)..."
    if nc -z localhost 9669 2>/dev/null; then
        print_success "NebulaGraph Graph Service is responding"
    else
        print_error "NebulaGraph Graph Service is not responding on port 9669"
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

# Check for existing containers
check_existing_containers() {
    print_info "Checking for existing NebulaGraph containers..."
    
    # Check for any running containers related to nebula or dapr
    local running_containers=$(docker ps --filter "name=nebula" --filter "name=dapr" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || echo "")
    local all_containers=$(docker ps -a --filter "name=nebula" --filter "name=dapr" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || echo "")
    
    if [ -n "$running_containers" ] && [ "$running_containers" != "NAMES	STATUS" ]; then
        print_warning "Found running containers:"
        echo "$running_containers"
        echo ""
        print_info "These containers need to be stopped before setting up a clean environment."
        echo -n "Do you want to stop and clean existing containers? (y/N): "
        read -r response
        
        case "$response" in
            [yY]|[yY][eE][sS])
                print_info "Stopping and cleaning existing containers..."
                clean_nebula_cluster
                print_success "Existing containers cleaned"
                ;;
            *)
                print_info "Setup cancelled by user. Please stop containers manually or run with 'clean' option."
                exit 0
                ;;
        esac
    elif [ -n "$all_containers" ] && [ "$all_containers" != "NAMES	STATUS" ]; then
        print_warning "Found stopped containers:"
        echo "$all_containers"
        echo ""
        echo -n "Do you want to clean existing containers before setup? (y/N): "
        read -r response
        
        case "$response" in
            [yY]|[yY][eE][sS])
                print_info "Cleaning existing containers..."
                clean_nebula_cluster
                print_success "Existing containers cleaned"
                ;;
            *)
                print_info "Continuing with existing containers..."
                ;;
        esac
    else
        print_success "No existing NebulaGraph or Dapr containers found"
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
        print_success "Dapr runtime is available: $(dapr --version | head -n1)"
    else
        print_error "Dapr runtime is not installed or not in PATH"
        print_info "Install Dapr: wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash"
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
        print_error "Prerequisites not met. Please install the missing components using the commands shown above."
        print_info "Or run: ./environment_setup.sh install-prereqs"
        exit 1
    fi
    
    # 2. Setup Docker network
    print_header "2. Docker Network Setup"
    setup_docker_network
    
    # 3. Start NebulaGraph cluster
    print_header "3. NebulaGraph Cluster Setup"
    start_nebula_cluster
    
    # 4. Initialize NebulaGraph
    print_header "4. NebulaGraph Initialization"
    initialize_nebula
    
    # 5. Wait for NebulaGraph to be ready
    print_header "5. NebulaGraph Readiness Check"
    wait_for_nebula_ready
    
    # 6. Final summary
    print_header "NebulaGraph Environment Ready"
    
    print_success "🎉 NebulaGraph environment setup completed successfully!"
    echo -e "\n${GREEN}Your NebulaGraph infrastructure is ready!${NC}"
    echo -e "\n${BLUE}Available services:${NC}"
    echo -e "  • NebulaGraph Cluster: nebula-graphd:9669"
    echo -e "  • NebulaGraph Studio: http://localhost:7001 (if enabled)"
    echo -e "  • NebulaGraph Console: Available via docker exec nebula-console"
    
    echo -e "\n${BLUE}Next steps:${NC}"
    echo -e "  • Start applications that use NebulaGraph"
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
        stop_nebula_cluster
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
    "help"|"-h"|"--help")
        echo "Usage: $0 [COMMAND]"
        echo ""
        echo "NebulaGraph Environment Management"
        echo ""
        echo "Commands:"
        echo "  setup, start      Set up the complete NebulaGraph environment (default)"
        echo "  install-prereqs   Install missing prerequisites (Go, Dapr, grpcurl)"
        echo "  stop, down        Stop NebulaGraph dependencies"
        echo "  status            Show dependency status"
        echo "  logs              Show dependency logs"
        echo "  init              Initialize NebulaGraph cluster"
        echo "  test              Test NebulaGraph services connectivity"
        echo "  clean             Clean up dependencies (volumes and networks)"
        echo "  help              Show this help message"
        echo ""
        echo "Setup will:"
        echo "  1. Check prerequisites (Docker, Docker Compose, Dapr, Go 1.24.5+, curl, grpcurl, jq)"
        echo "  2. Create Docker network"
        echo "  3. Start NebulaGraph cluster"
        echo "  4. Initialize NebulaGraph with required spaces/schemas"
        echo "  5. Wait for NebulaGraph to be ready"
        echo ""
        echo "Access Points:"
        echo "  • NebulaGraph Studio: http://localhost:7001"
        echo "  • NebulaGraph Graph Service: localhost:9669"
        echo "  • NebulaGraph Meta Service: localhost:9559"
        echo "  • NebulaGraph Storage Service: localhost:9779"
        echo ""
        echo "After running setup, you can start applications that use NebulaGraph."
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
