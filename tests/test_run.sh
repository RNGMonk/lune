#!/bin/bash
# Tests for the run command

LUNE=$(get_lune)

echo "Testing: run command"

# Test 1: Run simple script
run_test_output "run simple script" "Hello from lune!" \
    "$LUNE" "$FIXTURES_DIR/simple_script.lua"

# Test 2: Run with explicit run command
run_test_output "run with explicit command" "Hello from lune!" \
    "$LUNE" run "$FIXTURES_DIR/simple_script.lua"

# Test 3: Exit code handling
run_test_exit "exit code 0" 0 "$LUNE" "$FIXTURES_DIR/exit_code.lua" 0
run_test_exit "exit code 1" 1 "$LUNE" "$FIXTURES_DIR/exit_code.lua" 1
run_test_exit "exit code 42" 42 "$LUNE" "$FIXTURES_DIR/exit_code.lua" 42

# Test 4: Error handling - script with error exits non-zero
run_test_fail "error script exits non-zero" "$LUNE" "$FIXTURES_DIR/error_script.lua"

# Test 5: Non-existent file
run_test_fail "non-existent file fails" "$LUNE" "/nonexistent/file.lua"

# Test 6: Help output
run_test_output "help flag shows usage" "Usage:" "$LUNE" --help
run_test_output "help command shows usage" "Usage:" "$LUNE" help

# Test 7: Version output
run_test_output "version flag shows lune" "lune" "$LUNE" --version
run_test_output "version shows LuaJIT" "LuaJIT" "$LUNE" --version

# Test 8: Run script with arguments
setup_test_dir
cat > test_args.lua << 'EOF'
print("arg0: " .. (arg[0] or "nil"))
print("arg1: " .. (arg[1] or "nil"))
print("arg2: " .. (arg[2] or "nil"))
EOF
run_test_output "script receives arg1" "arg1: hello" "$LUNE" test_args.lua hello world
run_test_output "script receives arg2" "arg2: world" "$LUNE" test_args.lua hello world
cleanup_test_dir

# Test 9: Script can access standard library
setup_test_dir
cat > test_stdlib.lua << 'EOF'
print("math.pi: " .. math.pi)
print("table.concat: " .. table.concat({"a", "b"}, ","))
print("string.upper: " .. string.upper("hello"))
EOF
run_test_output "script can use math" "math.pi:" "$LUNE" test_stdlib.lua
run_test_output "script can use table" "table.concat: a,b" "$LUNE" test_stdlib.lua
run_test_output "script can use string" "string.upper: HELLO" "$LUNE" test_stdlib.lua
cleanup_test_dir

# Test 10: Script can use LuaJIT FFI
setup_test_dir
cat > test_ffi.lua << 'EOF'
local ffi = require("ffi")
print("FFI OS: " .. ffi.os)
print("FFI arch: " .. ffi.arch)
EOF
run_test_output "script can use FFI" "FFI OS:" "$LUNE" test_ffi.lua
cleanup_test_dir
