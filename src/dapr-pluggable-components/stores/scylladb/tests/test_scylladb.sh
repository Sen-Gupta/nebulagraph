#!/bin/bash

# Load environment configuration if available
if [ -f "../../../../.env" ]; then
    source ../../../../.env
fi

# Set default values for ports and network if not already set
SCYLLADB_HTTP_PORT=${SCYLLADB_HTTP_PORT:-${NEBULA_HTTP_PORT:-3502}}
SCYLLADB_GRPC_PORT=${SCYLLADB_GRPC_PORT:-${NEBULA_GRPC_PORT:-50002}}
DAPR_PLUGABBLE_NETWORK_NAME=${DAPR_PLUGABBLE_NETWORK_NAME:-dapr-pluggable-net}

echo "ScyllaDB Dapr Component - Comprehensive Test Suite"
echo "=================================================="
echo "Testing ScyllaDB State Store (HTTP & gRPC Interfaces)"
echo "Includes: CRUD + Bulk Operations + Query API + Cross-Protocol Testing + ETag Support"
echo "Configuration:"
echo "  • HTTP Port: $SCYLLADB_HTTP_PORT"
echo "  • gRPC Port: $SCYLLADB_GRPC_PORT"
echo "  • Network: $DAPR_PLUGABBLE_NETWORK_NAME"
echo "  • Component: scylladb-state"
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

# Check if we're in the correct directory and ScyllaDB test files exist
if [ ! -f "test_http.sh" ] || [ ! -f "test_grpc.sh" ]; then
    echo -e "${RED}❌ Error: ScyllaDB test scripts not found${NC}"
    echo "Expected files: test_http.sh, test_grpc.sh"
    echo "Current directory: $(pwd)"
    echo "Please run this script from the stores/scylladb/tests/ directory"
    exit 1
fi

# Make test scripts executable
chmod +x test_http.sh test_grpc.sh

print_section "🗃️  PHASE 1: HTTP Interface Testing (port $SCYLLADB_HTTP_PORT)"
echo "Running comprehensive ScyllaDB HTTP API tests..."
echo "• Basic CRUD operations (GET/SET/DELETE)"
echo "• ETag support for optimistic concurrency"
echo "• Bulk operations (BulkGet/BulkSet/BulkDelete)"
echo "• Query API functionality"
echo "• ScyllaDB-specific performance testing"
echo "• ScyllaDB consistency and persistence validation"
echo ""

./test_http.sh
HTTP_RESULT=$?

print_section "🔌 PHASE 2: gRPC Interface Testing (port $SCYLLADB_GRPC_PORT)"
echo "Running comprehensive ScyllaDB gRPC API tests..."
echo "• Basic CRUD operations (GET/SET/DELETE)"
echo "• Base64 encoding/decoding for gRPC protocol"
echo "• Bulk operations (BulkGet/BulkSet/BulkDelete)"
echo "• Query API functionality"
echo "• Cross-protocol compatibility (gRPC ↔ HTTP)"
echo "• ETag and consistency level testing"
echo "• ScyllaDB-optimized performance validation"
echo ""

./test_grpc.sh
GRPC_RESULT=$?

print_section "📊 SCYLLADB COMPREHENSIVE TEST RESULTS"

echo -e "ScyllaDB HTTP Interface Tests: $([ $HTTP_RESULT -eq 0 ] && echo -e "${GREEN}✅ PASSED${NC}" || echo -e "${RED}❌ FAILED${NC}")"
echo -e "ScyllaDB gRPC Interface Tests: $([ $GRPC_RESULT -eq 0 ] && echo -e "${GREEN}✅ PASSED${NC}" || echo -e "${RED}❌ FAILED${NC}")"
echo ""

if [ $HTTP_RESULT -eq 0 ] && [ $GRPC_RESULT -eq 0 ]; then
    echo -e "${GREEN}🎉 COMPLETE SCYLLADB SUCCESS!${NC}"
    echo "✅ ALL ScyllaDB state store interfaces and features are working correctly"
    echo "✅ ScyllaDB Dapr state store component is fully operational"
    echo ""
    echo "Production-ready ScyllaDB features verified:"
    echo "  • ScyllaDB state store (HTTP & gRPC)"
    echo "  • Data persistence and retrieval (GET/SET/DELETE)"
    echo "  • ETag support for optimistic concurrency control"
    echo "  • Bulk operations (BulkGet/BulkSet/BulkDelete)"
    echo "  • Query API with filtering and pagination"
    echo "  • Component registration and initialization"
    echo "  • Cross-protocol compatibility (HTTP ↔ gRPC)"
    echo "  • ScyllaDB-specific performance optimizations"
    echo "  • Consistency level handling (LOCAL_QUORUM)"
    echo "  • Token-aware connectivity and prepared statements"
    echo ""
    echo "ScyllaDB Performance Characteristics:"
    echo "  • Write performance: <2s for 10 sequential operations"
    echo "  • Read performance: <1s for 10 sequential operations"
    echo "  • Bulk operations: Efficient handling of 6+ items"
    echo "  • Query operations: Sub-5s response times"
    echo ""
    echo "Next steps:"
    echo "  • ScyllaDB component is ready for production deployment"
    echo "  • Both Dapr HTTP and gRPC clients can connect"
    echo "  • All ScyllaDB state operations are functional"
    echo "  • Advanced features like bulk operations and queries are supported"
    echo "  • ETag-based optimistic concurrency is available"
    echo "  • High-performance distributed database features are validated"
    exit 0
else
    # Calculate success rate
    passed_tests=0
    total_tests=2
    
    [ $HTTP_RESULT -eq 0 ] && ((passed_tests++))
    [ $GRPC_RESULT -eq 0 ] && ((passed_tests++))
    
    if [ $passed_tests -gt 0 ]; then
        echo -e "${YELLOW}⚠️  PARTIAL SCYLLADB SUCCESS ($passed_tests/$total_tests)${NC}"
        echo "Some ScyllaDB features are working, but there are issues to address"
    else
        echo -e "${RED}❌ SIGNIFICANT SCYLLADB FAILURES ($passed_tests/$total_tests)${NC}"
        echo "Multiple core ScyllaDB features have issues"
    fi
    
    echo ""
    echo "ScyllaDB Troubleshooting:"
    
    if [ $HTTP_RESULT -ne 0 ]; then
        echo "  • HTTP Interface: Check Dapr HTTP port $SCYLLADB_HTTP_PORT accessibility"
        echo "    - Verify ScyllaDB component configuration and connectivity"
        echo "    - Check ScyllaDB cluster status: docker ps | grep scylladb"
        echo "    - Verify keyspace and table creation"
    fi
    
    if [ $GRPC_RESULT -ne 0 ]; then
        echo "  • gRPC Interface: Verify grpcurl installation and Dapr gRPC port $SCYLLADB_GRPC_PORT"
        echo "    - Check Dapr sidecar and ScyllaDB component registration"
        echo "    - Verify gRPC service discovery and reflection"
    fi
    
    echo ""
    echo "General ScyllaDB troubleshooting:"
    echo "  • Component status: STORE_TYPE=scylladb ./run_nebula.sh status"
    echo "  • ScyllaDB cluster: docker logs scylladb-node1"
    echo "  • ScyllaDB connectivity: docker exec -it scylladb-node1 nodetool status"
    echo "  • Component logs: ./run_nebula.sh logs"
    echo "  • Network check: docker network ls | grep $DAPR_PLUGABBLE_NETWORK_NAME"
    echo "  • Keyspace check: docker exec -it scylladb-node1 cqlsh -e \"DESCRIBE KEYSPACES;\""
    echo "  • Table check: docker exec -it scylladb-node1 cqlsh -e \"USE dapr_state; DESCRIBE TABLES;\""
    echo ""
    echo "ScyllaDB Configuration verification:"
    echo "  • Check secrets: cat ../../../secrets/secrets.json | grep -A 15 scylladb"
    echo "  • Check component: cat ../../../components/scylladb-state.yaml"
    echo "  • Verify hosts: ping scylladb-node1 (from within Docker network)"
    echo "  • Check ports: netstat -tlnp | grep 9042"
    
    exit 1
fi
