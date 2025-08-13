#!/bin/bash

# Load environment configuration if available
if [ -f "../../.env" ]; then
    source ../../.env
fi

# Set default values for ports and network if not already set
PLUGGABLE_COMPONENTS_HTTP_PORT=${PLUGGABLE_COMPONENTS_HTTP_PORT}
PLUGGABLE_COMPONENTS_GRPC_PORT=${PLUGGABLE_COMPONENTS_GRPC_PORT}
DAPR_PLUGABBLE_NETWORK_NAME=${DAPR_PLUGABBLE_NETWORK_NAME:-dapr-pluggable-net}

echo "Dapr State Store Components - Comprehensive Test Suite"
echo "======================================================"
echo "Testing Multiple State Store Implementations (HTTP & gRPC Interfaces)"
echo "Includes: CRUD + Bulk Operations + Query API + Cross-Protocol Testing"
echo "Configuration:"
echo "  • Pluggable Components HTTP Port: $PLUGGABLE_COMPONENTS_HTTP_PORT"
echo "  • Pluggable Components gRPC Port: $PLUGGABLE_COMPONENTS_GRPC_PORT"
echo "  • Shared Network: $DAPR_PLUGABBLE_NETWORK_NAME"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test results tracking
NEBULA_RESULT=0
SCYLLADB_RESULT=0

print_section() {
    echo -e "\n${BLUE}$1${NC}"
    echo "==========================================================="
}

print_store_section() {
    echo -e "\n${PURPLE}$1${NC}"
    echo "==========================================================="
}

# Check for NebulaGraph test availability
if [ -f "../stores/nebulagraph/tests/test_nebula.sh" ]; then
    NEBULA_TEST_AVAILABLE=true
    chmod +x ../stores/nebulagraph/tests/test_nebula.sh
fi

# Check for ScyllaDB test availability
if [ -f "../stores/scylladb/tests/test_scylladb.sh" ]; then
    SCYLLADB_TEST_AVAILABLE=true
    chmod +x ../stores/scylladb/tests/test_scylladb.sh
fi

# Verify at least one test suite is available
if [ "$NEBULA_TEST_AVAILABLE" = false ] && [ "$SCYLLADB_TEST_AVAILABLE" = false ]; then
    echo -e "${RED}❌ Error: No state store test suites found${NC}"
    echo "Expected files:"
    echo "  • ../stores/nebulagraph/tests/test_nebula.sh"
    echo "  • ../stores/scylladb/tests/test_scylladb.sh"
    echo "At least one test suite must be available to run tests"
    exit 1
fi

print_section "🚀 COMPREHENSIVE STATE STORE TESTING SUITE"
echo "Available test suites:"
[ "$NEBULA_TEST_AVAILABLE" = true ] && echo -e "  ${GREEN}✅ NebulaGraph State Store${NC} (test_nebula.sh)"
[ "$SCYLLADB_TEST_AVAILABLE" = true ] && echo -e "  ${GREEN}✅ ScyllaDB State Store${NC} (test_scylladb.sh)"
echo ""

# NebulaGraph State Store Testing
if [ "$NEBULA_TEST_AVAILABLE" = true ]; then
    print_store_section "🌐 TESTING NEBULAGRAPH STATE STORE"
    
    # Export environment variables for both test scripts
    export PLUGGABLE_COMPONENTS_HTTP_PORT=$PLUGGABLE_COMPONENTS_HTTP_PORT
    export PLUGGABLE_COMPONENTS_GRPC_PORT=$PLUGGABLE_COMPONENTS_GRPC_PORT
    
    cd ../stores/nebulagraph/tests/
    ./test_nebula.sh
    NEBULA_RESULT=$?
    cd - > /dev/null
else
    echo -e "${YELLOW}⚠️  Skipping NebulaGraph tests - test suite not found${NC}"
fi

# ScyllaDB State Store Testing
if [ "$SCYLLADB_TEST_AVAILABLE" = true ]; then
    print_store_section "🗃️  TESTING SCYLLADB STATE STORE"
    
    # Export environment variables for ScyllaDB tests
    export PLUGGABLE_COMPONENTS_HTTP_PORT=$PLUGGABLE_COMPONENTS_HTTP_PORT
    export PLUGGABLE_COMPONENTS_GRPC_PORT=$PLUGGABLE_COMPONENTS_GRPC_PORT
    
    cd ../stores/scylladb/tests/
    ./test_scylladb.sh
    SCYLLADB_RESULT=$?
    cd - > /dev/null
else
    echo -e "${YELLOW}⚠️  Skipping ScyllaDB tests - test suite not found${NC}"
fi

print_section "📊 COMPREHENSIVE MULTI-STORE TEST RESULTS"

# Calculate and display results
total_stores=0
passed_stores=0

if [ "$NEBULA_TEST_AVAILABLE" = true ]; then
    ((total_stores++))
    echo -e "NebulaGraph State Store: $([ $NEBULA_RESULT -eq 0 ] && echo -e "${GREEN}✅ PASSED${NC}" || echo -e "${RED}❌ FAILED${NC}")"
    [ $NEBULA_RESULT -eq 0 ] && ((passed_stores++))
fi

if [ "$SCYLLADB_TEST_AVAILABLE" = true ]; then
    ((total_stores++))
    echo -e "ScyllaDB State Store: $([ $SCYLLADB_RESULT -eq 0 ] && echo -e "${GREEN}✅ PASSED${NC}" || echo -e "${RED}❌ FAILED${NC}")"
    [ $SCYLLADB_RESULT -eq 0 ] && ((passed_stores++))
fi

echo ""
echo -e "${CYAN}Test Summary: $passed_stores/$total_stores state stores passed${NC}"
echo ""

if [ $passed_stores -eq $total_stores ] && [ $total_stores -gt 0 ]; then
    echo -e "${GREEN}🎉 COMPLETE MULTI-STORE SUCCESS!${NC}"
    echo "✅ ALL available state store implementations are working correctly"
    echo "✅ Dapr pluggable state store components are fully operational"
    echo ""
    echo "Production-ready features verified across all stores:"
    
    if [ "$NEBULA_TEST_AVAILABLE" = true ]; then
        echo "  • NebulaGraph state store (HTTP & gRPC)"
        echo "    - Graph database state persistence"
        echo "    - Advanced graph query capabilities"
    fi
    
    if [ "$SCYLLADB_TEST_AVAILABLE" = true ]; then
        echo "  • ScyllaDB state store (HTTP & gRPC)"
        echo "    - Distributed database state persistence"
        echo "    - ETag support for optimistic concurrency"
        echo "    - ScyllaDB-specific performance optimizations"
    fi
    
    echo "  • Data persistence and retrieval (GET/SET/DELETE)"
    echo "  • Bulk operations (BulkGet/BulkSet/BulkDelete)"
    echo "  • Query API with filtering and pagination"
    echo "  • Component registration and initialization"
    echo "  • Cross-protocol compatibility (HTTP ↔ gRPC)"
    echo "  • Performance validation and benchmarking"
    echo ""
    echo "Next steps:"
    echo "  • All components are ready for production deployment"
    echo "  • Both Dapr HTTP and gRPC clients can connect to all stores"
    echo "  • Multiple backend options available for different use cases"
    echo "  • Advanced features like bulk operations and queries are supported"
    exit 0
else
    # Calculate success rate
    if [ $passed_stores -gt 0 ]; then
        echo -e "${YELLOW}⚠️  PARTIAL SUCCESS ($passed_stores/$total_stores stores)${NC}"
        echo "Some state store implementations are working, but there are issues to address"
    else
        echo -e "${RED}❌ SIGNIFICANT FAILURES ($passed_stores/$total_stores stores)${NC}"
        echo "Multiple state store implementations have issues"
    fi
    
    echo ""
    echo "Store-specific troubleshooting:"
    
    if [ "$NEBULA_TEST_AVAILABLE" = true ] && [ $NEBULA_RESULT -ne 0 ]; then
        echo ""
        echo -e "${YELLOW}NebulaGraph Issues:${NC}"
        echo "  • Check NebulaGraph cluster status and connectivity"
        echo "  • Verify graph space and schema configuration"
        echo "  • Component status: ./run_nebula.sh status"
        echo "  • NebulaGraph deps: cd ../dependencies && ./environment_setup.sh status"
    fi
    
    if [ "$SCYLLADB_TEST_AVAILABLE" = true ] && [ $SCYLLADB_RESULT -ne 0 ]; then
        echo ""
        echo -e "${YELLOW}ScyllaDB Issues:${NC}"
        echo "  • Check ScyllaDB cluster status: docker ps | grep scylladb"
        echo "  • Verify keyspace and table creation"
        echo "  • ScyllaDB connectivity: docker exec -it scylladb-node1 nodetool status"
        echo "  • Component status: STORE_TYPE=scylladb ./run_nebula.sh status"
    fi
    
    echo ""
    echo "General troubleshooting:"
    echo "  • Component logs: ./run_nebula.sh logs"
    echo "  • Dapr sidecar status: dapr list"
    echo "  • Network connectivity: docker network ls"
    echo "  • Port accessibility: netstat -tlnp | grep -E '(3501|50001)'"
    
    exit 1
fi
