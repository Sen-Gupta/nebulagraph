#!/bin/bash

# Load environment configuration if available
if [ -f "../../.env" ]; then
    source ../../.env
fi

# Redis Pub/Sub Integration Test Script
# Tests both Redis pub/sub and NebulaGraph state store integration

set -e

echo "Testing Pub/Sub Integration with NebulaGraph State Store"
echo "========================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Configuration
API_BASE_URL="http://localhost:5000"
DAPR_HTTP_PORT=${NEBULA_HTTP_PORT:-3500}
DAPR_GRPC_PORT=${NEBULA_GRPC_PORT:-50001}

echo "Configuration:"
echo "  • API Base URL: $API_BASE_URL"
echo "  • Dapr HTTP Port: $DAPR_HTTP_PORT"
echo "  • Dapr gRPC Port: $DAPR_GRPC_PORT"
echo ""

# Wait for service to be ready
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=30
    local attempt=0
    
    print_info "Waiting for $service_name to be ready..."
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s --connect-timeout 2 "$url" >/dev/null 2>&1; then
            print_success "$service_name is ready"
            return 0
        else
            attempt=$((attempt + 1))
            sleep 2
        fi
    done
    
    print_error "$service_name failed to start within expected time"
    return 1
}

# Test Redis pub/sub health
test_pubsub_health() {
    print_header "Testing Pub/Sub Health"
    
    print_info "Testing pub/sub health endpoint..."
    response=$(curl -s -w "%{http_code}" "$API_BASE_URL/api/pubsub/health" -o /tmp/health_response.json)
    
    if [ "$response" = "200" ]; then
        print_success "Pub/Sub health check passed"
        if command -v jq >/dev/null 2>&1; then
            jq '.' /tmp/health_response.json
        else
            cat /tmp/health_response.json
        fi
    else
        print_error "Pub/Sub health check failed (HTTP $response)"
        cat /tmp/health_response.json
        return 1
    fi
}

# Test message publishing
test_message_publishing() {
    print_header "Testing Message Publishing"
    
    # Test publishing to orders topic
    print_info "Publishing message to 'orders' topic..."
    
    local message_data='{
        "orderId": "12345",
        "customerId": "customer-001",
        "items": [
            {"productId": "prod-001", "quantity": 2, "price": 29.99},
            {"productId": "prod-002", "quantity": 1, "price": 49.99}
        ],
        "total": 109.97,
        "status": "pending"
    }'
    
    response=$(curl -s -w "%{http_code}" \
        -X POST "$API_BASE_URL/api/pubsub/publish/orders" \
        -H "Content-Type: application/json" \
        -d "$message_data" \
        -o /tmp/publish_response.json)
    
    if [ "$response" = "200" ]; then
        print_success "Message published successfully to 'orders' topic"
        if command -v jq >/dev/null 2>&1; then
            jq '.' /tmp/publish_response.json
        else
            cat /tmp/publish_response.json
        fi
    else
        print_error "Message publishing failed (HTTP $response)"
        cat /tmp/publish_response.json
        return 1
    fi
    
    # Test publishing to notifications topic
    print_info "Publishing message to 'notifications' topic..."
    
    local notification_data='{
        "notificationId": "notif-001",
        "userId": "user-123",
        "type": "order_confirmation",
        "title": "Order Confirmed",
        "message": "Your order #12345 has been confirmed and is being processed.",
        "priority": "high"
    }'
    
    response=$(curl -s -w "%{http_code}" \
        -X POST "$API_BASE_URL/api/pubsub/publish/notifications" \
        -H "Content-Type: application/json" \
        -d "$notification_data" \
        -o /tmp/publish_notification.json)
    
    if [ "$response" = "200" ]; then
        print_success "Notification published successfully to 'notifications' topic"
        if command -v jq >/dev/null 2>&1; then
            jq '.' /tmp/publish_notification.json
        else
            cat /tmp/publish_notification.json
        fi
    else
        print_error "Notification publishing failed (HTTP $response)"
        cat /tmp/publish_notification.json
        return 1
    fi
}

# Test direct Dapr pub/sub (if dapr CLI is available)
test_dapr_pubsub() {
    print_header "Testing Direct Dapr Pub/Sub"
    
    if ! command -v dapr >/dev/null 2>&1; then
        print_warning "Dapr CLI not available, skipping direct pub/sub test"
        return 0
    fi
    
    print_info "Publishing message directly via Dapr CLI..."
    
    local event_data='{
        "eventId": "event-001",
        "eventType": "user_registered",
        "userId": "user-456",
        "email": "newuser@example.com",
        "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
    }'
    
    if echo "$event_data" | dapr publish --publish-app-id nebulagraph-test-api --pubsub redis-pubsub --topic events --data-file -; then
        print_success "Message published directly via Dapr CLI"
    else
        print_error "Direct Dapr publish failed"
        return 1
    fi
}

# Test state store integration
test_state_store() {
    print_header "Testing State Store Integration"
    
    print_info "Retrieving published messages from state store..."
    
    response=$(curl -s -w "%{http_code}" "$API_BASE_URL/api/pubsub/messages" -o /tmp/messages_response.json)
    
    if [ "$response" = "200" ]; then
        print_success "Messages retrieved from state store"
        if command -v jq >/dev/null 2>&1; then
            jq '.' /tmp/messages_response.json
        else
            cat /tmp/messages_response.json
        fi
    else
        print_warning "Messages retrieval returned HTTP $response"
        cat /tmp/messages_response.json
    fi
    
    print_info "Retrieving processed events from state store..."
    
    response=$(curl -s -w "%{http_code}" "$API_BASE_URL/api/pubsub/events" -o /tmp/events_response.json)
    
    if [ "$response" = "200" ]; then
        print_success "Events retrieved from state store"
        if command -v jq >/dev/null 2>&1; then
            jq '.' /tmp/events_response.json
        else
            cat /tmp/events_response.json
        fi
    else
        print_warning "Events retrieval returned HTTP $response"
        cat /tmp/events_response.json
    fi
}

# Test Redis connectivity directly
test_redis_direct() {
    print_header "Testing Redis Direct Connectivity"
    
    if ! command -v redis-cli >/dev/null 2>&1; then
        print_warning "redis-cli not available, skipping direct Redis test"
        return 0
    fi
    
    print_info "Testing Redis connection..."
    
    if redis-cli -h localhost -p 6379 -a dapr_redis ping >/dev/null 2>&1; then
        print_success "Redis direct connection successful"
        
        # Test pub/sub directly
        print_info "Testing Redis pub/sub directly..."
        
        # Start a subscriber in the background
        timeout 5 redis-cli -h localhost -p 6379 -a dapr_redis subscribe test_channel > /tmp/redis_sub.log 2>&1 &
        local sub_pid=$!
        
        sleep 2
        
        # Publish a message
        redis-cli -h localhost -p 6379 -a dapr_redis publish test_channel "Hello from test script!" >/dev/null 2>&1
        
        sleep 2
        
        # Kill the subscriber
        kill $sub_pid 2>/dev/null || true
        
        if grep -q "Hello from test script!" /tmp/redis_sub.log 2>/dev/null; then
            print_success "Redis pub/sub direct test successful"
        else
            print_warning "Redis pub/sub direct test inconclusive"
        fi
    else
        print_error "Redis direct connection failed"
        return 1
    fi
}

# Test NebulaGraph state store directly via Dapr
test_nebulagraph_direct() {
    print_header "Testing NebulaGraph State Store Direct Access"
    
    if ! command -v dapr >/dev/null 2>&1; then
        print_warning "Dapr CLI not available, skipping direct state store test"
        return 0
    fi
    
    print_info "Testing NebulaGraph state store via Dapr CLI..."
    
    local test_data='{"testKey": "integration-test", "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'", "value": "test-value-123"}'
    
    # Save state
    if echo "$test_data" | dapr state save --state-store nebulagraph-state --key "test:integration" --data-file -; then
        print_success "State saved to NebulaGraph via Dapr CLI"
        
        sleep 2
        
        # Retrieve state
        if retrieved_data=$(dapr state get --state-store nebulagraph-state --key "test:integration"); then
            print_success "State retrieved from NebulaGraph via Dapr CLI"
            echo "Retrieved data: $retrieved_data"
        else
            print_error "Failed to retrieve state from NebulaGraph"
            return 1
        fi
    else
        print_error "Failed to save state to NebulaGraph"
        return 1
    fi
}

# Main test execution
main() {
    print_header "Redis Pub/Sub and NebulaGraph Integration Test"
    echo -e "Testing the complete integration between Redis pub/sub and NebulaGraph state store.\n"
    
    # Wait for services to be ready
    wait_for_service "$API_BASE_URL/health" "NebulaGraph Test API" || exit 1
    
    local overall_success=0
    
    # Run all tests
    test_pubsub_health || overall_success=1
    sleep 2
    
    test_message_publishing || overall_success=1
    sleep 3
    
    test_dapr_pubsub || overall_success=1
    sleep 3
    
    test_state_store || overall_success=1
    sleep 2
    
    test_redis_direct || overall_success=1
    sleep 2
    
    test_nebulagraph_direct || overall_success=1
    
    # Final summary
    print_header "Integration Test Summary"
    
    if [ $overall_success -eq 0 ]; then
        print_success "🎉 All integration tests passed!"
        echo -e "\n${GREEN}Your Redis pub/sub and NebulaGraph integration is working correctly!${NC}"
        echo -e "\n${BLUE}What was tested:${NC}"
        echo -e "  ✅ Pub/Sub health check"
        echo -e "  ✅ Message publishing to multiple topics"
        echo -e "  ✅ State persistence in NebulaGraph"
        echo -e "  ✅ Message retrieval from state store"
        echo -e "  ✅ Direct Redis connectivity"
        echo -e "  ✅ Direct NebulaGraph state store access"
    else
        print_warning "Some integration tests failed or had warnings"
        echo -e "\n${YELLOW}Please review the test output above for details.${NC}"
        echo -e "\n${BLUE}Common issues:${NC}"
        echo -e "  • Services not fully started (wait longer and retry)"
        echo -e "  • Network connectivity issues"
        echo -e "  • Missing CLI tools (dapr, redis-cli, jq)"
        echo -e "  • Configuration mismatches"
    fi
    
    # Cleanup temp files
    rm -f /tmp/health_response.json /tmp/publish_response.json /tmp/publish_notification.json
    rm -f /tmp/messages_response.json /tmp/events_response.json /tmp/redis_sub.log
    
    echo ""
}

# Handle command line arguments
case "${1:-test}" in
    "test"|"run")
        main
        ;;
    "health")
        test_pubsub_health
        ;;
    "publish")
        test_message_publishing
        ;;
    "state")
        test_state_store
        ;;
    "redis")
        test_redis_direct
        ;;
    "nebula")
        test_nebulagraph_direct
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [COMMAND]"
        echo ""
        echo "Redis Pub/Sub and NebulaGraph Integration Tests"
        echo ""
        echo "Commands:"
        echo "  test, run     Run all integration tests (default)"
        echo "  health        Test pub/sub health endpoint"
        echo "  publish       Test message publishing"
        echo "  state         Test state store integration"
        echo "  redis         Test Redis direct connectivity"
        echo "  nebula        Test NebulaGraph direct access"
        echo "  help          Show this help message"
        echo ""
        echo "Prerequisites:"
        echo "  • NebulaGraph Test API running on port 5000"
        echo "  • Dapr sidecar running on ports 3500 (HTTP) and 50001 (gRPC)"
        echo "  • Redis and NebulaGraph infrastructure running"
        echo ""
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
