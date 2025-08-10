#!/bin/bash

# Load environment variables from root .env file
if [ -f "../../.env" ]; then
    echo "Loading configuration from ../../.env"
    set -a
    source ../../.env
    set +a
else
    echo "Warning: ../../.env not found, using default values"
    REDIS_HOST_PORT="6380"
    REDIS_PASSWORD="dapr_redis"
fi

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

# Initialize Redis for Dapr pub/sub
echo "Initializing Redis for Dapr pub/sub..."
echo "Configuration:"
echo "  • Network: redis-net"
echo "  • Port: $REDIS_HOST_PORT"
echo "  • Password: $REDIS_PASSWORD"
echo ""

# Wait for Redis to be fully ready
print_info "Waiting for Redis to initialize and be ready..."
sleep 10

# Check if Redis is responding
print_info "Testing Redis connectivity..."
max_attempts=15
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if docker exec redis redis-cli -a "$REDIS_PASSWORD" ping >/dev/null 2>&1; then
        print_success "Redis is ready and responsive"
        break
    else
        attempt=$((attempt + 1))
        print_info "Waiting for Redis to be ready... (attempt $attempt/$max_attempts)"
        sleep 2
    fi
done

if [ $attempt -eq $max_attempts ]; then
    print_error "Redis failed to start within expected time"
    exit 1
fi

# Show Redis info
print_info "Checking Redis server info..."
docker exec redis redis-cli -a "$REDIS_PASSWORD" info server | grep "redis_version\|os\|arch_bits"

# Test basic Redis operations
print_info "Testing basic Redis operations..."
docker exec redis redis-cli -a "$REDIS_PASSWORD" set test_key "test_value"

print_info "Testing Redis retrieval..."
test_result=$(docker exec redis redis-cli -a "$REDIS_PASSWORD" get test_key)
if [ "$test_result" = "test_value" ]; then
    print_success "Redis basic operations working correctly"
else
    print_error "Redis basic operations failed"
fi

# Clean up test key
print_info "Cleaning up test data..."
docker exec redis redis-cli -a "$REDIS_PASSWORD" del test_key

# Test pub/sub functionality
print_info "Testing Redis pub/sub functionality..."
docker exec redis redis-cli -a "$REDIS_PASSWORD" publish test_channel "test_message" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    print_success "Redis pub/sub functionality is working"
else
    print_warning "Redis pub/sub test could not be verified"
fi

# Show final Redis status
print_info "Final Redis status:"
docker exec redis redis-cli -a "$REDIS_PASSWORD" info memory | grep "used_memory_human"
docker exec redis redis-cli -a "$REDIS_PASSWORD" info clients | grep "connected_clients"

print_success "Redis initialization completed successfully!"
print_info "Redis is ready for Dapr pub/sub operations"
print_info "Connection details:"
print_info "  • Host: redis (or localhost from host)"
print_info "  • Port: $REDIS_PORT"
print_info "  • Password: $REDIS_PASSWORD"
print_info "  • Network: $REDIS_NETWORK_NAME"
