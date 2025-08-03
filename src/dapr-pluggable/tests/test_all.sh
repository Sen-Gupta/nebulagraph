#!/bin/bash

echo "NebulaGraph Dapr State Store Component - Complete Test Suite"
echo "==========================================================="
echo "Testing both HTTP (port 3501) and gRPC (port 50001) interfaces"
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

print_section "🌐 PHASE 1: HTTP Interface Testing (port 3501)"
echo "Running HTTP API tests..."
echo ""

./test_component.sh
HTTP_RESULT=$?

print_section "🔌 PHASE 2: gRPC Interface Testing (port 50001)"
echo "Running gRPC API tests..."
echo ""

./test_component_grpc.sh
GRPC_RESULT=$?

print_section "📊 FINAL RESULTS"

echo -e "HTTP Interface Tests: $([ $HTTP_RESULT -eq 0 ] && echo -e "${GREEN}✅ PASSED${NC}" || echo -e "${RED}❌ FAILED${NC}")"
echo -e "gRPC Interface Tests: $([ $GRPC_RESULT -eq 0 ] && echo -e "${GREEN}✅ PASSED${NC}" || echo -e "${RED}❌ FAILED${NC}")"
echo ""

if [ $HTTP_RESULT -eq 0 ] && [ $GRPC_RESULT -eq 0 ]; then
    echo -e "${GREEN}🎉 COMPLETE SUCCESS!${NC}"
    echo "✅ Both HTTP and gRPC interfaces are working correctly"
    echo "✅ NebulaGraph Dapr State Store component is fully functional"
    echo ""
    echo "Next steps:"
    echo "  • Component is ready for production use"
    echo "  • Both Dapr HTTP and gRPC clients can connect successfully"
    echo "  • Data persistence in NebulaGraph is verified"
    exit 0
elif [ $HTTP_RESULT -eq 0 ] && [ $GRPC_RESULT -ne 0 ]; then
    echo -e "${YELLOW}⚠️  PARTIAL SUCCESS${NC}"
    echo "✅ HTTP interface is working"
    echo "❌ gRPC interface has issues"
    echo ""
    echo "Troubleshooting:"
    echo "  • Check if grpcurl is installed: apt-get install grpcurl"
    echo "  • Verify Dapr gRPC port 50001 is accessible"
    echo "  • Check Dapr sidecar logs: docker logs daprd-nebulagraph"
    exit 1
elif [ $HTTP_RESULT -ne 0 ] && [ $GRPC_RESULT -eq 0 ]; then
    echo -e "${YELLOW}⚠️  PARTIAL SUCCESS${NC}"
    echo "❌ HTTP interface has issues"
    echo "✅ gRPC interface is working"
    echo ""
    echo "Troubleshooting:"
    echo "  • Check if Dapr HTTP port 3501 is accessible"
    echo "  • Check component logs: docker logs nebulagraph-dapr-component"
    echo "  • Verify curl is available and working"
    exit 1
else
    echo -e "${RED}❌ COMPLETE FAILURE${NC}"
    echo "❌ Both HTTP and gRPC interfaces have issues"
    echo ""
    echo "Troubleshooting:"
    echo "  • Check if Dapr component is running: ./run_docker_pluggable.sh status"
    echo "  • Verify NebulaGraph infrastructure: cd ../dependencies && ./environment_setup.sh status"
    echo "  • Check all logs: ./run_docker_pluggable.sh logs"
    exit 1
fi
