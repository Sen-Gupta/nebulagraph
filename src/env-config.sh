#!/bin/bash

# Environment Configuration Script
# Helps switch between local and docker development environments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

print_header() {
    echo -e "\n${BLUE}======================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}======================================${NC}"
}

# Check if we're in the src directory
check_directory() {
    if [ ! -f ".env.local" ] || [ ! -f ".env.docker" ]; then
        print_error "Environment files not found. Please run this script from the src/ directory."
        print_info "Expected files: .env.local, .env.docker"
        exit 1
    fi
    
    if [ ! -d "components" ] || [ ! -f "components/nebulagraph-state.yaml" ] || [ ! -f "components/redis-pubsub.yaml" ] || [ ! -f "components/local-secret-store.yaml" ]; then
        print_error "Components directory or files not found."
        print_info "Expected directory: components/"
        print_info "Expected files: components/nebulagraph-state.yaml, components/redis-pubsub.yaml, components/local-secret-store.yaml"
        exit 1
    fi
}

# Show current environment
show_current_env() {
    print_header "Current Environment Configuration"
    
    if [ -f ".env" ]; then
        local env_type="unknown"
        
        if grep -q "NEBULA_HOST=localhost" .env 2>/dev/null; then
            env_type="local"
        elif grep -q "NEBULA_HOST=nebula-graphd" .env 2>/dev/null; then
            env_type="docker"
        fi
        
        print_info "Active environment: $env_type"
        echo ""
        echo "Current configuration:"
        cat .env | grep -E "^[^#]" | head -10
        if [ $(cat .env | grep -E "^[^#]" | wc -l) -gt 10 ]; then
            echo "... ($(cat .env | grep -E "^[^#]" | wc -l) total variables)"
        fi
    else
        print_warning "No active environment configuration found (.env file missing)"
        print_info "Use 'set-local' or 'set-docker' to configure an environment"
    fi
}

# Generate secrets file directly from environment variables
generate_secrets_file() {
    local env_file="$1"
    
    if [ ! -f "$env_file" ]; then
        print_error "Environment file $env_file not found"
        return 1
    fi
    
    print_info "Generating secrets file from environment variables"
    
    # Create secrets directory if it doesn't exist
    mkdir -p secrets
    
    # Source environment variables
    source "$env_file"
    
    # Generate secrets.json directly
    cat > secrets/secrets.json << EOF
{
  "nebulagraph": {
    "host": "$NEBULA_HOST",
    "port": "$NEBULA_PORT",
    "username": "$NEBULA_USERNAME",
    "password": "$NEBULA_PASSWORD",
    "space": "$NEBULA_SPACE",
    "connectionTimeout": "$NEBULA_CONNECTION_TIMEOUT",
    "executionTimeout": "$NEBULA_EXECUTION_TIMEOUT"
  },
  "redis": {
    "host": "$REDIS_HOST",
    "password": "$REDIS_PASSWORD",
    "db": "$REDIS_DB",
    "maxRetries": "$REDIS_MAX_RETRIES",
    "maxRetryBackoff": "$REDIS_MAX_RETRY_BACKOFF",
    "dialTimeout": "$REDIS_DIAL_TIMEOUT",
    "readTimeout": "$REDIS_READ_TIMEOUT",
    "writeTimeout": "$REDIS_WRITE_TIMEOUT",
    "poolSize": "$REDIS_POOL_SIZE",
    "poolTimeout": "$REDIS_POOL_TIMEOUT",
    "maxConnAge": "$REDIS_MAX_CONN_AGE",
    "idleTimeout": "$REDIS_IDLE_TIMEOUT",
    "idleCheckFrequency": "$REDIS_IDLE_CHECK_FREQUENCY",
    "redeliverInterval": "$REDIS_REDELIVER_INTERVAL",
    "processingTimeout": "$REDIS_PROCESSING_TIMEOUT",
    "type": "$REDIS_TYPE",
    "enableTLS": "$REDIS_ENABLE_TLS"
  }
}
EOF
    
    print_success "Generated secrets/secrets.json"
    print_success "Secrets file generation completed"
}

# Set local environment
set_local_env() {
    print_header "Setting Local Development Environment"
    
    if cp .env.local .env; then
        print_success "Local environment file activated"
        
        # Generate secrets file from environment variables
        generate_secrets_file ".env.local"
        
        print_info "Components will connect to services running on localhost"
        echo ""
        echo "Key settings:"
        echo "  • NebulaGraph: localhost:9669"
        echo "  • Redis: localhost:6379"
        echo "  • Connection pool: 5 connections (local optimized)"
        echo ""
        print_info "Usage: dapr run --components-path ./components ..."
    else
        print_error "Failed to activate local environment"
        exit 1
    fi
}

# Set docker environment
set_docker_env() {
    print_header "Setting Docker Development Environment"
    
    if cp .env.docker .env; then
        print_success "Docker environment file activated"
        
        # Generate secrets file from environment variables
        generate_secrets_file ".env.docker"
        
        print_info "Components will connect to services running in Docker containers"
        echo ""
        echo "Key settings:"
        echo "  • NebulaGraph: nebula-graphd:9669"
        echo "  • Redis: redis:6379"
        echo "  • Connection pool: 20 connections (container optimized)"
        echo ""
        print_info "Usage: docker-compose up"
    else
        print_error "Failed to activate docker environment"
        exit 1
    fi
}

# Show environment differences
compare_environments() {
    print_header "Environment Configuration Comparison"
    
    echo -e "${BLUE}Local Development (.env.local):${NC}"
    echo "  • Target: Services running on localhost"
    echo "  • NebulaGraph: localhost:9669"
    echo "  • Redis: localhost:6379"
    echo "  • Pool size: 5 (optimized for local development)"
    echo "  • Timeouts: Shorter (faster local connections)"
    echo ""
    
    echo -e "${BLUE}Docker Development (.env.docker):${NC}"
    echo "  • Target: Services running in Docker containers"
    echo "  • NebulaGraph: nebula-graphd:9669"
    echo "  • Redis: redis:6379"
    echo "  • Pool size: 20 (optimized for container networking)"
    echo "  • Timeouts: Standard (container network latency)"
    echo ""
    
    print_info "Both environments use the same static component YAML files"
    print_info "Only the generated secrets file changes between environments"
}

# Test current configuration
test_configuration() {
    print_header "Testing Current Environment Configuration"
    
    if [ ! -f ".env" ]; then
        print_error "No active environment found. Please set an environment first."
        exit 1
    fi
    
    # Source the environment file to test variable expansion
    source .env
    
    print_info "Testing environment variable expansion..."
    
    # Test key variables
    echo "NebulaGraph Host: ${NEBULA_HOST:-NOT_SET}"
    echo "NebulaGraph Port: ${NEBULA_PORT:-NOT_SET}"
    echo "Redis Host: ${REDIS_HOST:-NOT_SET}"
    echo "Redis Pool Size: ${REDIS_POOL_SIZE:-NOT_SET}"
    
    # Check if this looks like local or docker config
    if [ "$NEBULA_HOST" = "localhost" ]; then
        print_success "Configuration appears to be set for local development"
    elif [ "$NEBULA_HOST" = "nebula-graphd" ]; then
        print_success "Configuration appears to be set for Docker development"
    else
        print_warning "Configuration doesn't match expected local or Docker patterns"
    fi
}

# Clean environment
clean_env() {
    print_header "Cleaning Environment Configuration"
    
    if [ -f ".env" ]; then
        rm .env
        print_success "Active environment configuration removed"
        print_info "Use 'set-local' or 'set-docker' to configure a new environment"
    else
        print_info "No active environment configuration to clean"
    fi
}

# Show usage help
show_help() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Environment Configuration Management for Dapr Components"
    echo ""
    echo "Commands:"
    echo "  show, status      Show current environment configuration"
    echo "  set-local         Set local development environment"
    echo "  set-docker        Set Docker development environment"
    echo "  compare           Compare local vs Docker configurations"
    echo "  test              Test current environment variable expansion"
    echo "  clean             Remove active environment configuration"
    echo "  help              Show this help message"
    echo ""
    echo "Environment Files:"
    echo "  .env.local        Local development configuration"
    echo "  .env.docker       Docker development configuration"
    echo "  .env              Active configuration (symlink/copy)"
    echo ""
    echo "Usage Patterns:"
    echo "  # Local development"
    echo "  ./env-config.sh set-local"
    echo "  dapr run --components-path ./components ..."
    echo ""
    echo "  # Docker development"
    echo "  ./env-config.sh set-docker"
    echo "  docker-compose up"
    echo ""
    echo "Component Files:"
    echo "  components/nebulagraph-state.yaml    Static component using secret store"
    echo "  components/redis-pubsub.yaml         Static component using secret store"
    echo "  components/local-secret-store.yaml   Secret store component"
    echo "  secrets/secrets.json                 Generated secrets file from environment variables"
}

# Main function
main() {
    check_directory
    
    case "${1:-show}" in
        "show"|"status")
            show_current_env
            ;;
        "set-local"|"local")
            set_local_env
            ;;
        "set-docker"|"docker")
            set_docker_env
            ;;
        "compare"|"diff")
            compare_environments
            ;;
        "test"|"validate")
            test_configuration
            ;;
        "clean"|"reset")
            clean_env
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

main "$@"
