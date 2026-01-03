#!/bin/bash
# Main test runner for lune integration tests
#
# Usage:
#   ./run_tests.sh              # Run all tests with bin/lune
#   ./run_tests.sh --compiled   # Run all tests with runtime/lune
#   ./run_tests.sh test_run.sh  # Run specific test file

# Don't use set -e as tests intentionally run commands that fail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source helpers
source "$SCRIPT_DIR/test_helpers.sh"

# Parse arguments
COMPILED_MODE=false
TEST_FILES=()

for arg in "$@"; do
    case $arg in
        --compiled)
            COMPILED_MODE=true
            ;;
        --help|-h)
            echo "Usage: $0 [options] [test_files...]"
            echo ""
            echo "Options:"
            echo "  --compiled    Test with compiled runtime/lune instead of bin/lune"
            echo "  --help, -h    Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                      # Run all tests with bin/lune"
            echo "  $0 --compiled           # Run all tests with runtime/lune"
            echo "  $0 test_run.sh          # Run specific test file"
            echo "  $0 --compiled test_run.sh test_init.sh"
            exit 0
            ;;
        *.sh)
            TEST_FILES+=("$arg")
            ;;
        *)
            echo "Unknown argument: $arg"
            echo "Run '$0 --help' for usage."
            exit 1
            ;;
    esac
done

# Set the lune binary to use
if [ "$COMPILED_MODE" = true ]; then
    if [ ! -f "$PROJECT_ROOT/runtime/lune" ]; then
        echo "Error: runtime/lune not found. Run 'make' first."
        exit 1
    fi
    export LUNE_BINARY="$PROJECT_ROOT/runtime/lune"
    echo "========================================"
    echo "Testing COMPILED lune: $LUNE_BINARY"
    echo "========================================"
else
    export LUNE_BINARY="$PROJECT_ROOT/bin/lune"
    echo "========================================"
    echo "Testing UNCOMPILED lune: $LUNE_BINARY"
    echo "========================================"
fi

# Verify lune exists and is executable
if [ ! -f "$LUNE_BINARY" ]; then
    echo "Error: lune binary not found at $LUNE_BINARY"
    exit 1
fi

if [ ! -x "$LUNE_BINARY" ]; then
    chmod +x "$LUNE_BINARY"
fi

# Verify lune works
if ! "$LUNE_BINARY" --version > /dev/null 2>&1; then
    echo "Error: lune binary at $LUNE_BINARY is not functional"
    exit 1
fi

echo ""
echo "lune version: $("$LUNE_BINARY" --version 2>&1 | head -1)"
echo ""

# If no specific test files, run all
if [ ${#TEST_FILES[@]} -eq 0 ]; then
    TEST_FILES=(
        "test_run.sh"
        "test_init.sh"
        "test_install.sh"
        "test_compile.sh"
    )
fi

# Run each test file
TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_RUN=0

for test_file in "${TEST_FILES[@]}"; do
    test_path="$SCRIPT_DIR/$test_file"

    if [ ! -f "$test_path" ]; then
        echo "Warning: Test file not found: $test_path"
        continue
    fi

    echo ""
    echo "========================================"
    echo "Running: $test_file"
    echo "========================================"

    # Reset counters for this test file
    TESTS_RUN=0
    TESTS_PASSED=0
    TESTS_FAILED=0

    # Source and run the test file
    source "$test_path"

    # Accumulate totals
    TOTAL_RUN=$((TOTAL_RUN + TESTS_RUN))
    TOTAL_PASSED=$((TOTAL_PASSED + TESTS_PASSED))
    TOTAL_FAILED=$((TOTAL_FAILED + TESTS_FAILED))

    echo ""
    echo "Subtotal: $TESTS_PASSED/$TESTS_RUN passed"
done

# Print final summary
echo ""
echo "========================================"
echo "FINAL RESULTS"
echo "========================================"
echo "Total: $TOTAL_PASSED/$TOTAL_RUN passed"

if [ "$TOTAL_FAILED" -gt 0 ]; then
    echo -e "${RED}$TOTAL_FAILED tests failed${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
