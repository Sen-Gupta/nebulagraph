#!/bin/bash

# NebulaGraph Dapr Component - Environment Validation Script
# Validates that all components are properly configured and running
# NOTE: This script only validates - use ../dependencies/environment_setup.sh to set up the environment

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
    if curl -s http://localhost:3500/v1.0/healthz > /dev/null 2>&1; then
        print_success "Dapr sidecar is responding on port 3500"
        
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
        print_error "Dapr sidecar is not responding on port 3500"
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
    print_header "NebulaGraph Dapr Component - Environment Validation"
    echo -e "This script validates your development environment to ensure everything is working correctly."
    echo -e "To set up the environment, run: ../dependencies/environment_setup.sh\n"
    
    local overall_success=0
    
    # 1. Test NebulaGraph Cluster
    print_header "1. NebulaGraph Cluster Validation"
    
    if ! test_nebula_connection; then
        overall_success=1
    fi
    
    # Check if space exists
    print_info "Checking if 'dapr_state' space exists..."
    if docker exec nebula-console sh -c '/usr/local/bin/nebula-console -addr nebula-graphd -port 9669 -u root -p nebula -e "USE dapr_state; SHOW TAGS;" > /dev/null 2>&1'; then
        print_success "NebulaGraph 'dapr_state' space exists and is accessible"
    else
        print_error "NebulaGraph 'dapr_state' space not found or not accessible"
        print_info "Run: cd ../dependencies && ./init_nebula.sh"
        overall_success=1
    fi
    
    # 2. Test Dapr Component
    print_header "2. Dapr Component Validation"
    
    if ! test_dapr_component; then
        overall_success=1
    fi
    
    # 3. Test CRUD Operations
    print_header "3. CRUD Operations Test"
    
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
        echo -e "\n${YELLOW}Solutions:${NC}"
        echo -e "  • Set up environment: ../dependencies/environment_setup.sh"
        echo -e "  • Check container logs: docker logs <container-name>"
        echo -e "  • Restart services: cd ../dependencies && ./deps.sh restart"
        echo -e "  • Manual initialization: cd ../dependencies && ./init_nebula.sh"
        echo -e "  • Check README_DEV.md for detailed troubleshooting"
        exit 1
    fi
    
    echo ""
}

# Run main function
main "$@"
