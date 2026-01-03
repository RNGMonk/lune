#!/bin/bash
# Test helper functions for lune integration tests

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters (exported for use across sourced files)
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get the directory where this script lives
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$TESTS_DIR")"
FIXTURES_DIR="$TESTS_DIR/fixtures"

# Temporary directory for test artifacts
TEST_TMPDIR=""

# Setup temporary directory for a test
setup_test_dir() {
    TEST_TMPDIR=$(mktemp -d)
    cd "$TEST_TMPDIR"
}

# Cleanup temporary directory
cleanup_test_dir() {
    if [ -n "$TEST_TMPDIR" ] && [ -d "$TEST_TMPDIR" ]; then
        rm -rf "$TEST_TMPDIR"
    fi
    TEST_TMPDIR=""
    cd "$TESTS_DIR"
}

# Get the lune binary to test (set by run_tests.sh)
get_lune() {
    echo "${LUNE_BINARY:-$PROJECT_ROOT/bin/lune}"
}

# Run a test and check the result
# Usage: run_test "test name" command args...
run_test() {
    local name="$1"
    shift

    TESTS_RUN=$((TESTS_RUN + 1))

    if "$@" > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}: $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}: $name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Run a test expecting failure
# Usage: run_test_fail "test name" command args...
run_test_fail() {
    local name="$1"
    shift

    TESTS_RUN=$((TESTS_RUN + 1))

    if ! "$@" > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}: $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}: $name (expected failure)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Run a test and check output contains expected string
# Usage: run_test_output "test name" "expected" command args...
run_test_output() {
    local name="$1"
    local expected="$2"
    shift 2

    TESTS_RUN=$((TESTS_RUN + 1))

    local output
    output=$("$@" 2>&1)
    local exit_code=$?

    if echo "$output" | grep -q "$expected"; then
        echo -e "${GREEN}PASS${NC}: $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}: $name"
        echo "  Expected to contain: $expected"
        echo "  Got: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Run a test checking exit code
# Usage: run_test_exit "test name" expected_code command args...
run_test_exit() {
    local name="$1"
    local expected_code="$2"
    shift 2

    TESTS_RUN=$((TESTS_RUN + 1))

    "$@" > /dev/null 2>&1
    local actual_code=$?

    if [ "$actual_code" -eq "$expected_code" ]; then
        echo -e "${GREEN}PASS${NC}: $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}: $name"
        echo "  Expected exit code: $expected_code"
        echo "  Got: $actual_code"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Check if a file exists
# Usage: run_test_file_exists "test name" filepath
run_test_file_exists() {
    local name="$1"
    local filepath="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ -f "$filepath" ]; then
        echo -e "${GREEN}PASS${NC}: $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}: $name (file not found: $filepath)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Check if a directory exists
# Usage: run_test_dir_exists "test name" dirpath
run_test_dir_exists() {
    local name="$1"
    local dirpath="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ -d "$dirpath" ]; then
        echo -e "${GREEN}PASS${NC}: $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}: $name (directory not found: $dirpath)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Check if a file is executable
# Usage: run_test_file_executable "test name" filepath
run_test_file_executable() {
    local name="$1"
    local filepath="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ -x "$filepath" ]; then
        echo -e "${GREEN}PASS${NC}: $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}: $name (file not executable: $filepath)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Skip a test with a message
# Usage: skip_test "test name" "reason"
skip_test() {
    local name="$1"
    local reason="$2"

    echo -e "${YELLOW}SKIP${NC}: $name ($reason)"
}

# Print test summary
print_summary() {
    echo ""
    echo "================================"
    echo "Test Results: $TESTS_PASSED/$TESTS_RUN passed"
    if [ "$TESTS_FAILED" -gt 0 ]; then
        echo -e "${RED}$TESTS_FAILED tests failed${NC}"
        return 1
    else
        echo -e "${GREEN}All tests passed${NC}"
        return 0
    fi
}
