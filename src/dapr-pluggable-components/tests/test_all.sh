#!/bin/bash

# Load environment configuration if available
if [ -f "../../.env" ]; then
    source ../../.env
fi

# Set default values for ports and network if not already set
NEBULA_HTTP_PORT=${NEBULA_HTTP_PORT:-3501}
NEBULA_GRPC_PORT=${NEBULA_GRPC_PORT:-50001}
NEBULA_NETWORK_NAME=${NEBULA_NETWORK_NAME:-nebula-net}

echo "NebulaGraph Dapr Component - State Store Test Suite"
echo "==================================================="
echo "Testing NebulaGraph State Store (HTTP/gRPC Interfaces)"
echo "Configuration:"
echo "  • HTTP Port: $NEBULA_HTTP_PORT"
echo "  • gRPC Port: $NEBULA_GRPC_PORT"
echo "  • Network: $NEBULA_NETWORK_NAME"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
HTTP_RESULT=0
GRPC_RESULT=0

print_section() {
    echo -e "\n${BLUE}$1${NC}"
    echo "==========================================================="
}

# Check if we're in the tests directory
if [ ! -f "test_component.sh" ] || [ ! -f "test_component_grpc.sh" ]; then
    echo -e "${RED}❌ Error: Test scripts not found in current directory${NC}"
    echo "Please run this script from the tests/ directory"
    echo "Expected files: test_component.sh, test_component_grpc.sh"
    exit 1
fi

print_section "🌐 PHASE 1: HTTP Interface Testing (port $NEBULA_HTTP_PORT)"
echo "Running HTTP API tests for NebulaGraph state store..."
echo ""

./test_component.sh
HTTP_RESULT=$?

print_section "🔌 PHASE 2: gRPC Interface Testing (port $NEBULA_GRPC_PORT)"
echo "Running gRPC API tests for NebulaGraph state store..."
echo ""

./test_component_grpc.sh
GRPC_RESULT=$?

print_section " FINAL RESULTS"

echo -e "HTTP Interface Tests: $([ $HTTP_RESULT -eq 0 ] && echo -e "${GREEN}✅ PASSED${NC}" || echo -e "${RED}❌ FAILED${NC}")"
echo -e "gRPC Interface Tests: $([ $GRPC_RESULT -eq 0 ] && echo -e "${GREEN}✅ PASSED${NC}" || echo -e "${RED}❌ FAILED${NC}")"
echo ""

if [ $HTTP_RESULT -eq 0 ] && [ $GRPC_RESULT -eq 0 ]; then
    echo -e "${GREEN}🎉 COMPLETE SUCCESS!${NC}"
    echo "✅ HTTP and gRPC state store interfaces are working correctly"
    echo "✅ NebulaGraph Dapr state store component is fully operational"
    echo ""
    echo "Production-ready features verified:"
    echo "  • NebulaGraph state store (HTTP & gRPC)"
    echo "  • Data persistence and retrieval"
    echo "  • Component registration and initialization"
    echo ""
    echo "Next steps:"
    echo "  • Component is ready for production deployment"
    echo "  • Both Dapr HTTP and gRPC clients can connect"
    echo "  • NebulaGraph state operations are functional"
    exit 0
elif [ $HTTP_RESULT -eq 0 ] && [ $GRPC_RESULT -ne 0 ]; then
    echo -e "${YELLOW}⚠️  PARTIAL SUCCESS${NC}"
    echo "✅ HTTP interface is working"
    echo "❌ gRPC interface has issues"
    echo ""
    echo "Troubleshooting gRPC:"
    echo "  • Check if grpcurl is installed: apt-get install grpcurl"
    echo "  • Verify Dapr gRPC port $NEBULA_GRPC_PORT is accessible"
    echo "  • Check Dapr sidecar logs: docker logs daprd-nebulagraph"
    exit 1
elif [ $HTTP_RESULT -ne 0 ] && [ $GRPC_RESULT -eq 0 ]; then
    echo -e "${YELLOW}⚠️  PARTIAL SUCCESS${NC}"
    echo "❌ HTTP interface has issues"
    echo "✅ gRPC interface is working"
    echo ""
    echo "Troubleshooting HTTP:"
    echo "  • Check if Dapr HTTP port $NEBULA_HTTP_PORT is accessible"
    echo "  • Check component logs: docker logs nebulagraph-dapr-component"
    echo "  • Verify curl is available and working"
    exit 1
else
    echo -e "${RED}❌ COMPLETE FAILURE${NC}"
    echo "❌ HTTP state store interface has issues"
    echo "❌ gRPC state store interface has issues"
    echo ""
    echo "Troubleshooting:"
    echo "  • Check if Dapr component is running: ./run_docker_pluggable.sh status"
    echo "  • Verify NebulaGraph dependencies: cd ../dependencies && ./environment_setup.sh status"
    echo "  • Check all logs: ./run_docker_pluggable.sh logs"
    echo "  • Verify network connectivity: docker network ls | grep $NEBULA_NETWORK_NAME"
    exit 1
fi
