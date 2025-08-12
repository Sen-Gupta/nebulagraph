#!/bin/bash

# Load environment configuration if available
if [ -f "../../.env" ]; then
    source ../../.env
fi

# Set default values for ports and network if not already set
NEBULA_HTTP_PORT=${NEBULA_HTTP_PORT:-3501}
NEBULA_GRPC_PORT=${NEBULA_GRPC_PORT:-50001}
NEBULA_NETWORK_NAME=${NEBULA_NETWORK_NAME:-nebula-net}

echo "NebulaGraph Dapr Component - Comprehensive Test Suite"
echo "===================================================="
echo "Testing NebulaGraph State Store (HTTP & gRPC Interfaces)"
echo "Includes: CRUD + Bulk Operations + Query API + Cross-Protocol Testing"
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

# Check if we're in the tests directory and NebulaGraph test files exist
if [ ! -f "../stores/nebulagraph/tests/test_http.sh" ] || [ ! -f "../stores/nebulagraph/tests/test_grpc.sh" ]; then
    echo -e "${RED}❌ Error: NebulaGraph test scripts not found${NC}"
    echo "Expected files: ../stores/nebulagraph/tests/test_http.sh, ../stores/nebulagraph/tests/test_grpc.sh"
    exit 1
fi

# Make test scripts executable
chmod +x ../stores/nebulagraph/tests/test_http.sh ../stores/nebulagraph/tests/test_grpc.sh

print_section "🌐 PHASE 1: HTTP Interface Testing (port $NEBULA_HTTP_PORT)"
echo "Running comprehensive HTTP API tests..."
echo "• Basic CRUD operations"
echo "• Bulk operations (BulkGet/BulkSet/BulkDelete)"
echo "• Query API functionality"
echo "• Performance validation"
echo ""

../stores/nebulagraph/tests/test_http.sh
HTTP_RESULT=$?

print_section "🔌 PHASE 2: gRPC Interface Testing (port $NEBULA_GRPC_PORT)"
echo "Running comprehensive gRPC API tests..."
echo "• Basic CRUD operations"
echo "• Bulk operations (BulkGet/BulkSet/BulkDelete)"
echo "• Query API functionality"
echo "• Cross-protocol compatibility"
echo "• Performance validation"
echo ""

../stores/nebulagraph/tests/test_grpc.sh
GRPC_RESULT=$?

print_section " COMPREHENSIVE TEST RESULTS"

echo -e "HTTP Interface Tests: $([ $HTTP_RESULT -eq 0 ] && echo -e "${GREEN}✅ PASSED${NC}" || echo -e "${RED}❌ FAILED${NC}")"
echo -e "gRPC Interface Tests: $([ $GRPC_RESULT -eq 0 ] && echo -e "${GREEN}✅ PASSED${NC}" || echo -e "${RED}❌ FAILED${NC}")"
echo ""

if [ $HTTP_RESULT -eq 0 ] && [ $GRPC_RESULT -eq 0 ]; then
    echo -e "${GREEN}🎉 COMPLETE SUCCESS!${NC}"
    echo "✅ ALL state store interfaces and features are working correctly"
    echo "✅ NebulaGraph Dapr state store component is fully operational"
    echo ""
    echo "Production-ready features verified:"
    echo "  • NebulaGraph state store (HTTP & gRPC)"
    echo "  • Data persistence and retrieval (GET/SET/DELETE)"
    echo "  • Bulk operations (BulkGet/BulkSet/BulkDelete)"
    echo "  • Query API with filtering and pagination"
    echo "  • Component registration and initialization"
    echo "  • Cross-protocol compatibility (HTTP ↔ gRPC)"
    echo "  • Performance validation and benchmarking"
    echo ""
    echo "Next steps:"
    echo "  • Component is ready for production deployment"
    echo "  • Both Dapr HTTP and gRPC clients can connect"
    echo "  • All NebulaGraph state operations are functional"
    echo "  • Advanced features like bulk operations and queries are supported"
    exit 0
else
    # Calculate success rate
    passed_tests=0
    total_tests=2
    
    [ $HTTP_RESULT -eq 0 ] && ((passed_tests++))
    [ $GRPC_RESULT -eq 0 ] && ((passed_tests++))
    
    if [ $passed_tests -gt 0 ]; then
        echo -e "${YELLOW}⚠️  PARTIAL SUCCESS ($passed_tests/$total_tests)${NC}"
        echo "Some features are working, but there are issues to address"
    else
        echo -e "${RED}❌ SIGNIFICANT FAILURES ($passed_tests/$total_tests)${NC}"
        echo "Multiple core features have issues"
    fi
    
    echo ""
    echo "Troubleshooting:"
    
    if [ $HTTP_RESULT -ne 0 ]; then
        echo "  • HTTP Interface: Check Dapr HTTP port $NEBULA_HTTP_PORT accessibility"
        echo "    - Verify component configuration and NebulaGraph connectivity"
    fi
    
    if [ $GRPC_RESULT -ne 0 ]; then
        echo "  • gRPC Interface: Verify grpcurl installation and Dapr gRPC port $NEBULA_GRPC_PORT"
        echo "    - Check Dapr sidecar and component registration"
    fi
    
    echo ""
    echo "General troubleshooting:"
    echo "  • Component status: ./run_nebula.sh status"
    echo "  • NebulaGraph deps: cd ../dependencies && ./environment_setup.sh status"
    echo "  • Component logs: ./run_nebula.sh logs"
    echo "  • Network check: docker network ls | grep $NEBULA_NETWORK_NAME"
    
    exit 1
fi
