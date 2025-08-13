#!/bin/bash

# .NET Examples Test Suite
# Runs comprehensive tests for all .NET Dapr examples including NebulaGraph and ScyllaDB

set -e

# Load environment configuration if available
if [ -f "../../.env" ]; then
    source ../../.env
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$SCRIPT_DIR"
TEST_RESULTS=()

print_header() {
    echo -e "\n${CYAN}${BOLD}========================================${NC}"
    echo -e "${CYAN}${BOLD}$1${NC}"
    echo -e "${CYAN}${BOLD}========================================${NC}"
}

print_subheader() {
    echo -e "\n${BLUE}${BOLD}--- $1 ---${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_separator() {
    echo -e "${CYAN}----------------------------------------${NC}"
}

# Function to run a test script and capture results
run_test_script() {
    local script_name="$1"
    local script_path="$2"
    local test_args="${3:-}"
    
    print_subheader "Running $script_name Test Suite"
    
    if [[ ! -f "$script_path" ]]; then
        print_error "$script_name test script not found: $script_path"
        TEST_RESULTS+=("$script_name:FAILED:Script not found")
        return 1
    fi
    
    if [[ ! -x "$script_path" ]]; then
        print_info "Making $script_name test script executable..."
        chmod +x "$script_path"
    fi
    
    print_info "Starting $script_name tests..."
    local start_time=$(date +%s)
    
    # Run the test script
    if bash "$script_path" $test_args; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        print_success "$script_name test suite completed successfully (${duration}s)"
        TEST_RESULTS+=("$script_name:PASSED:${duration}s")
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        print_error "$script_name test suite failed (${duration}s)"
        TEST_RESULTS+=("$script_name:FAILED:${duration}s")
        return 1
    fi
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if test scripts exist
    local nebula_test_script="$TESTS_DIR/test_nebula_net.sh"
    local scylladb_test_script="$TESTS_DIR/test_scylladb_net.sh"
    
    if [[ -f "$nebula_test_script" ]]; then
        print_success "NebulaGraph test script found"
    else
        print_error "NebulaGraph test script not found: $nebula_test_script"
        return 1
    fi
    
    if [[ -f "$scylladb_test_script" ]]; then
        print_success "ScyllaDB test script found"
    else
        print_error "ScyllaDB test script not found: $scylladb_test_script"
        return 1
    fi
    
    # Check if Dapr pluggables runner exists
    local dapr_runner="$SCRIPT_DIR/../run_dotnet_examples.sh"
    if [[ -f "$dapr_runner" ]]; then
        print_success "Dapr pluggables runner found"
    else
        print_error "Dapr pluggables runner not found: $dapr_runner"
        return 1
    fi
    
    # Check basic tools
    if command -v curl >/dev/null 2>&1; then
        print_success "curl is available"
    else
        print_error "curl is required but not installed"
        return 1
    fi
    
    if command -v docker >/dev/null 2>&1; then
        print_success "Docker is available"
    else
        print_error "Docker is required but not installed"
        return 1
    fi
    
    print_success "All prerequisites check passed"
}

# Function to start services
start_services() {
    print_header "Starting Dapr Pluggable Services"
    
    local dapr_runner="$SCRIPT_DIR/../run_dotnet_examples.sh"
    local examples_dir="$SCRIPT_DIR/.."
    
    print_info "Starting all Dapr pluggable components..."
    if (cd "$examples_dir" && bash "./run_dotnet_examples.sh" start); then
        print_success "Dapr pluggable services started successfully"
        
        # Give services time to fully initialize
        print_info "Waiting for services to fully initialize..."
        sleep 20
        
        return 0
    else
        print_error "Failed to start Dapr pluggable services"
        return 1
    fi
}

# Function to stop services
stop_services() {
    print_header "Stopping Dapr Pluggable Services"
    
    local dapr_runner="$SCRIPT_DIR/../run_dotnet_examples.sh"
    local examples_dir="$SCRIPT_DIR/.."
    
    print_info "Stopping all Dapr pluggable components..."
    if (cd "$examples_dir" && bash "./run_dotnet_examples.sh" stop); then
        print_success "Dapr pluggable services stopped successfully"
        return 0
    else
        print_warning "Failed to stop some Dapr pluggable services (this may be normal)"
        return 0  # Don't fail the entire test suite for cleanup issues
    fi
}

# Function to run all tests
run_all_tests() {
    print_header ".NET Examples Comprehensive Test Suite"
    
    local total_start_time=$(date +%s)
    local tests_passed=0
    local tests_failed=0
    
    # Test 1: NebulaGraph .NET Example
    print_separator
    if run_test_script "NebulaGraph" "$TESTS_DIR/test_nebula_net.sh" "test"; then
        tests_passed=$((tests_passed + 1))
    else
        tests_failed=$((tests_failed + 1))
    fi
    
    print_separator
    print_info "Waiting 10 seconds between test suites..."
    sleep 10
    
    # Test 2: ScyllaDB .NET Example  
    print_separator
    if run_test_script "ScyllaDB" "$TESTS_DIR/test_scylladb_net.sh"; then
        tests_passed=$((tests_passed + 1))
    else
        tests_failed=$((tests_failed + 1))
    fi
    
    # Calculate total duration
    local total_end_time=$(date +%s)
    local total_duration=$((total_end_time - total_start_time))
    
    # Print final results
    print_header "Test Suite Results"
    
    print_info "Individual Test Results:"
    for result in "${TEST_RESULTS[@]}"; do
        IFS=':' read -r test_name status duration <<< "$result"
        if [[ "$status" == "PASSED" ]]; then
            print_success "$test_name: $status ($duration)"
        else
            print_error "$test_name: $status ($duration)"
        fi
    done
    
    echo ""
    print_info "Summary:"
    echo "  • Tests Passed: $tests_passed"
    echo "  • Tests Failed: $tests_failed"
    echo "  • Total Duration: ${total_duration}s"
    
    if [[ $tests_failed -eq 0 ]]; then
        print_success "🎉 All .NET example tests passed!"
        return 0
    else
        print_error "💥 Some .NET example tests failed"
        return 1
    fi
}

# Function to run individual test
run_individual_test() {
    local test_type="$1"
    
    case "$test_type" in
        "nebula"|"nebulagraph")
            print_header "Running NebulaGraph .NET Test Only"
            run_test_script "NebulaGraph" "$TESTS_DIR/test_nebula_net.sh" "test"
            ;;
        "scylla"|"scylladb")
            print_header "Running ScyllaDB .NET Test Only"
            run_test_script "ScyllaDB" "$TESTS_DIR/test_scylladb_net.sh"
            ;;
        *)
            print_error "Unknown test type: $test_type"
            print_info "Available tests: nebula, scylla"
            return 1
            ;;
    esac
}

# Function to check service status
check_service_status() {
    print_header "Checking Service Status"
    
    local dapr_runner="$SCRIPT_DIR/../run_dotnet_examples.sh"
    local examples_dir="$SCRIPT_DIR/.."
    
    (cd "$examples_dir" && bash "./run_dotnet_examples.sh" status)
}

# Cleanup function
cleanup() {
    print_info "Performing cleanup..."
    stop_services || true
}

# Trap cleanup on exit
trap cleanup EXIT

# Main execution logic
case "${1:-test}" in
    "start")
        check_prerequisites
        start_services
        run_all_tests
        ;;
    "test"|"run")
        run_all_tests
        ;;
    "check"|"status")
        check_service_status
        ;;
    "nebula"|"nebulagraph")
        run_individual_test "nebula"
        ;;
    "scylla"|"scylladb")
        run_individual_test "scylla"
        ;;
    "stop")
        stop_services
        ;;
    "clean")
        stop_services
        print_success "Cleanup completed"
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [COMMAND]"
        echo ""
        echo ".NET Examples Test Suite - Comprehensive testing for all .NET Dapr examples"
        echo ""
        echo "Commands:"
        echo "  test          Run all .NET integration tests (default)"
        echo "  run           Same as test"
        echo "  start         Start services and run all tests"
        echo "  check         Check service status"
        echo "  status        Same as check"
        echo "  nebula        Run only NebulaGraph tests"
        echo "  scylla        Run only ScyllaDB tests"
        echo "  stop          Stop all services"
        echo "  clean         Stop services and cleanup"
        echo "  help          Show this help"
        echo ""
        echo "Test Components:"
        echo "  • NebulaGraph .NET Example - Full integration testing"
        echo "  • ScyllaDB .NET Example - Comprehensive functionality testing"
        echo ""
        echo "Prerequisites:"
        echo "  • Dependencies must be running (../../dependencies/environment_setup.sh start)"
        echo "  • Docker and Docker Compose must be installed"
        echo "  • dapr-pluggable-net Docker network must exist"
        echo ""
        echo "Features:"
        echo "  • Automated service startup and shutdown"
        echo "  • Comprehensive test coverage for all .NET examples"
        echo "  • Individual test execution support"
        echo "  • Detailed test results and timing"
        echo "  • Automatic cleanup on exit"
        echo ""
        echo "Examples:"
        echo "  $0 test           # Run tests on already running services"
        echo "  $0 start          # Start services and run all tests"
        echo "  $0 nebula         # Test only NebulaGraph functionality"
        echo "  $0 scylla         # Test only ScyllaDB functionality"
        echo ""
        echo "Note: This script coordinates testing across multiple .NET examples."
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac

exit $?
