#!/bin/bash

# NebulaGraph Dapr Component - Development Setup Validation Script
# Validates that all components are properly configured and running

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

# Check if port is available
check_port() {
    local port=$1
    local service=$2
    if command_exists nc; then
        if nc -z localhost $port 2>/dev/null; then
            print_success "$service is responding on port $port"
            return 0
        else
            print_error "$service is not responding on port $port"
            return 1
        fi
    else
        print_warning "netcat not available, skipping port check for $service"
        return 0
    fi
}

# Check Docker container status
check_container() {
    local container_name=$1
    local expected_status=$2
    
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "$container_name"; then
        local status=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep "$container_name" | awk '{for(i=2;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/[[:space:]]*$//')
        if [[ $status == *"Up"* ]]; then
            print_success "Container '$container_name' is running"
            return 0
        else
            print_error "Container '$container_name' status: $status"
            return 1
        fi
    else
        print_error "Container '$container_name' not found or not running"
        return 1
    fi
}

# Test NebulaGraph connectivity
test_nebula_connection() {
    print_info "Testing NebulaGraph connectivity..."
    
    # Test using Docker exec with correct path
    if docker exec nebula-console sh -c '/usr/local/bin/nebula-console -addr nebula-graphd -port 9669 -u root -p nebula -e "SHOW HOSTS;" > /dev/null 2>&1'; then
        print_success "NebulaGraph cluster is accessible and responsive"
        return 0
    else
        print_error "NebulaGraph cluster connectivity test failed"
        return 1
    fi
}

# Test Dapr component connectivity
test_dapr_component() {
    print_info "Testing Dapr component connectivity..."
    
    # Test if Dapr sidecar is responding
    if check_port 3500 "Dapr sidecar"; then
        # Test a simple GET operation (should return 204 if key doesn't exist)
        local response=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:3500/v1.0/state/nebulagraph-state/validation-test-key 2>/dev/null || echo "000")
        if [[ "$response" == "204" ]] || [[ "$response" == "200" ]]; then
            print_success "Dapr component is responding to state requests"
            return 0
        else
            print_error "Dapr component returned unexpected response code: $response"
            return 1
        fi
    else
        return 1
    fi
}

# Test component CRUD operations
test_crud_operations() {
    print_info "Testing basic CRUD operations..."
    
    local test_key="validation-test-$(date +%s)"
    local test_value="validation-data-$(date +%s)"
    local success=0
    
    # Test SET operation
    print_info "Testing SET operation..."
    local set_response=$(curl -s -w "%{http_code}" -o /dev/null -X POST http://localhost:3500/v1.0/state/nebulagraph-state \
        -H "Content-Type: application/json" \
        -d "[{\"key\": \"$test_key\", \"value\": \"$test_value\"}]" 2>/dev/null || echo "000")
    
    if [[ "$set_response" == "204" ]]; then
        print_success "SET operation successful"
    else
        print_error "SET operation failed with response code: $set_response"
        success=1
    fi
    
    # Test GET operation
    print_info "Testing GET operation..."
    local get_response=$(curl -s http://localhost:3500/v1.0/state/nebulagraph-state/$test_key 2>/dev/null || echo "")
    
    if [[ "$get_response" == "\"$test_value\"" ]]; then
        print_success "GET operation successful - data retrieved correctly"
    else
        print_error "GET operation failed - expected \"$test_value\", got: $get_response"
        success=1
    fi
    
    # Test DELETE operation
    print_info "Testing DELETE operation..."
    local delete_response=$(curl -s -w "%{http_code}" -o /dev/null -X DELETE http://localhost:3500/v1.0/state/nebulagraph-state/$test_key 2>/dev/null || echo "000")
    
    if [[ "$delete_response" == "204" ]]; then
        print_success "DELETE operation successful"
    else
        print_error "DELETE operation failed with response code: $delete_response"
        success=1
    fi
    
    # Verify deletion
    print_info "Verifying deletion..."
    local verify_response=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:3500/v1.0/state/nebulagraph-state/$test_key 2>/dev/null || echo "000")
    
    if [[ "$verify_response" == "204" ]]; then
        print_success "Deletion verified - key no longer exists"
    else
        print_error "Deletion verification failed - key may still exist (response: $verify_response)"
        success=1
    fi
    
    return $success
}

# Main validation function
main() {
    print_header "NebulaGraph Dapr Component - Setup Validation"
    echo -e "This script validates your development setup to ensure everything is working correctly.\n"
    
    local overall_success=0
    
    # 1. Check prerequisites
    print_header "1. Prerequisites Check"
    
    if command_exists docker; then
        print_success "Docker is installed: $(docker --version)"
    else
        print_error "Docker is not installed or not in PATH"
        overall_success=1
    fi
    
    if command_exists docker-compose; then
        print_success "Docker Compose is installed: $(docker-compose --version)"
    else
        print_error "Docker Compose is not installed or not in PATH"
        overall_success=1
    fi
    
    if command_exists curl; then
        print_success "curl is installed: $(curl --version | head -n1)"
    else
        print_error "curl is not installed or not in PATH"
        overall_success=1
    fi
    
    # 2. Check Docker containers
    print_header "2. Docker Containers Status"
    
    local containers=(
        "nebula-metad"
        "nebula-storaged"
        "nebula-graphd"
        "nebula-console"
        "nebulagraph-dapr-component"
        "daprd-nebulagraph"
    )
    
    for container in "${containers[@]}"; do
        if ! check_container "$container" "Up"; then
            overall_success=1
        fi
    done
    
    # 3. Check network connectivity
    print_header "3. Network Connectivity"
    
    # Check if containers are on the same network
    print_info "Checking Docker network configuration..."
    local network_name="nebula-net"
    if docker network ls | grep -q "$network_name"; then
        print_success "Docker network '$network_name' exists"
        
        # Check if key containers are on the network
        local containers_on_network=$(docker network inspect $network_name --format='{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null || echo "")
        if [[ "$containers_on_network" == *"nebula-graphd"* ]] && [[ "$containers_on_network" == *"nebulagraph-dapr-component"* ]]; then
            print_success "Key containers are connected to the network"
        else
            print_error "Some containers may not be connected to the network"
            overall_success=1
        fi
    else
        print_error "Docker network '$network_name' not found"
        overall_success=1
    fi
    
    # 4. Test NebulaGraph
    print_header "4. NebulaGraph Cluster Validation"
    
    if ! test_nebula_connection; then
        overall_success=1
    fi
    
    # Check if space exists
    print_info "Checking if 'dapr_state' space exists..."
    if docker exec nebula-console sh -c '/usr/local/bin/nebula-console -addr nebula-graphd -port 9669 -u root -p nebula -e "USE dapr_state; SHOW TAGS;" > /dev/null 2>&1'; then
        print_success "NebulaGraph 'dapr_state' space exists and is accessible"
    else
        print_warning "NebulaGraph 'dapr_state' space may not exist - run './init_nebula.sh' to initialize"
        print_info "This is normal for a fresh setup"
    fi
    
    # 5. Test Dapr component
    print_header "5. Dapr Component Validation"
    
    if ! test_dapr_component; then
        overall_success=1
    fi
    
    # 6. Test CRUD operations
    print_header "6. CRUD Operations Test"
    
    if ! test_crud_operations; then
        overall_success=1
    fi
    
    # 7. Final summary
    print_header "Validation Summary"
    
    if [ $overall_success -eq 0 ]; then
        print_success "🎉 All validation checks passed! Your development setup is working correctly."
        echo -e "\n${GREEN}Your NebulaGraph Dapr component is ready for development!${NC}"
        echo -e "\n${BLUE}Next steps:${NC}"
        echo -e "  • Start developing with your Dapr component"
        echo -e "  • Run './test_component.sh' for comprehensive testing"
        echo -e "  • Check logs with: docker logs nebulagraph-dapr-component"
        echo -e "  • Access NebulaGraph Studio at: http://localhost:7001 (if Studio profile is running)"
    else
        print_error "Some validation checks failed. Please review the errors above."
        echo -e "\n${YELLOW}Common solutions:${NC}"
        echo -e "  • Run './setup_dev.sh' to set up the complete environment"
        echo -e "  • Run './init_nebula.sh' if NebulaGraph space is missing"
        echo -e "  • Check container logs: docker logs <container-name>"
        echo -e "  • Restart services: docker-compose down && docker-compose up -d"
        echo -e "  • Check README_DEV.md for detailed troubleshooting"
        exit 1
    fi
    
    echo ""
}

# Run main function
main "$@"
