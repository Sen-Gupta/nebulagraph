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

# Setup Docker network
setup_docker_network() {
    print_info "Setting up Docker network..."
    local network_name="nebula-net"
    
    if docker network ls | grep -q "$network_name"; then
        print_success "Docker network '$network_name' already exists"
        
        # Check if network needs to be recreated due to configuration changes
        if ! docker network inspect $network_name > /dev/null 2>&1; then
            print_warning "Network inspection failed, may need recreation"
        fi
    else
        print_info "Creating Docker network '$network_name'..."
        docker network create "$network_name"
        print_success "Docker network '$network_name' created"
    fi
}

# Start NebulaGraph cluster
start_nebula_cluster() {
    print_info "Starting NebulaGraph cluster..."
    
    if [ -f "docker-compose.yml" ]; then
        # Try to start the cluster
        if docker-compose up -d; then
            print_success "NebulaGraph cluster started"
            print_info "Waiting for services to initialize..."
            sleep 15
        else
            print_warning "Initial startup failed, trying to recreate..."
            # If startup fails due to network issues, try to recreate
            docker-compose down
            sleep 2
            
            # Remove and recreate network if needed
            if docker network ls | grep -q "nebula-net"; then
                print_info "Recreating Docker network..."
                docker network rm nebula-net 2>/dev/null || true
                docker network create nebula-net
            fi
            
            # Try starting again
            if docker-compose up -d; then
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
        docker-compose down
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
        docker-compose ps
    else
        print_error "docker-compose.yml not found in current directory"
        return 1
    fi
}

# Show cluster logs
show_nebula_logs() {
    print_header "NebulaGraph Dependencies Logs"
    if [ -f "docker-compose.yml" ]; then
        docker-compose logs -f
    else
        print_error "docker-compose.yml not found in current directory"
        return 1
    fi
}

# Clean cluster (remove volumes and networks)
clean_nebula_cluster() {
    print_header "Cleaning NebulaGraph Dependencies"
    if [ -f "docker-compose.yml" ]; then
        docker-compose down -v --remove-orphans
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

# Main setup function
main() {
    print_header "NebulaGraph Environment Setup"
    echo -e "This script sets up the NebulaGraph infrastructure environment.\n"
    
    local overall_success=0
    
    # 1. Check prerequisites
    print_header "1. Prerequisites Check"
    
    if command_exists docker; then
        print_success "Docker is available: $(docker --version)"
    else
        print_error "Docker is not installed or not in PATH"
        overall_success=1
    fi
    
    if command_exists docker-compose; then
        print_success "Docker Compose is available: $(docker-compose --version)"
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
    
    if [ $overall_success -ne 0 ]; then
        print_error "Prerequisites not met. Please install the missing components using the commands shown above."
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
        echo "  setup, start  Set up the complete NebulaGraph environment (default)"
        echo "  stop, down    Stop NebulaGraph dependencies"
        echo "  status        Show dependency status"
        echo "  logs          Show dependency logs"
        echo "  init          Initialize NebulaGraph cluster"
        echo "  test          Test NebulaGraph services connectivity"
        echo "  clean         Clean up dependencies (volumes and networks)"
        echo "  help          Show this help message"
        echo ""
        echo "Setup will:"
        echo "  1. Check prerequisites (Docker, Docker Compose, Dapr, Go 1.24.5+)"
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
