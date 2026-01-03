#!/bin/bash
# Tests for the compile command

LUNE=$(get_lune)

echo "Testing: compile command"

# Check if runtime/lunert exists (needed for compilation)
if [ ! -f "$PROJECT_ROOT/runtime/lunert" ]; then
    echo "SKIP: compile tests require runtime/lunert"
    echo "      Run 'make' to build the runtime first."
    return 0 2>/dev/null || exit 0
fi

# Test 1: Compile simple script
setup_test_dir
cp "$FIXTURES_DIR/simple_script.lua" main.lua
run_test "compile simple script" "$LUNE" compile main.lua -o app
run_test_file_exists "executable created" "app"
run_test_file_executable "executable is executable" "app"
run_test_output "compiled app runs correctly" "Hello from lune!" ./app
cleanup_test_dir

# Test 2: Compile with default output name (strips .lua)
setup_test_dir
cp "$FIXTURES_DIR/simple_script.lua" myscript.lua
run_test "compile with default name" "$LUNE" compile myscript.lua
run_test_file_exists "default name executable" "myscript"
run_test_output "default name app runs" "Hello from lune!" ./myscript
cleanup_test_dir

# Test 3: Compile with pure Lua dependency (argparse)
setup_test_dir
"$LUNE" install argparse > /dev/null 2>&1
cp "$FIXTURES_DIR/argparse_script.lua" main.lua
run_test "compile with lua dep" "$LUNE" compile main.lua -o app
run_test_output "compiled with dep runs" "Hello, World!" ./app
run_test_output "compiled accepts args" "Hello, Test!" ./app -n Test
cleanup_test_dir

# Test 4: Compile with native dependency (luafilesystem)
if command -v cc &> /dev/null; then
    setup_test_dir
    if "$LUNE" install luafilesystem > /dev/null 2>&1; then
        cp "$FIXTURES_DIR/lfs_script.lua" main.lua
        run_test "compile with native dep" "$LUNE" compile main.lua -o app
        run_test_dir_exists "lib folder created" "lib"

        # Check for .so file in lib/
        if ls lib/*.so 1> /dev/null 2>&1; then
            TESTS_RUN=$((TESTS_RUN + 1))
            echo -e "${GREEN}PASS${NC}: native lib copied to lib/"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            TESTS_RUN=$((TESTS_RUN + 1))
            echo -e "${RED}FAIL${NC}: native lib not found in lib/"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi

        run_test_output "compiled with native runs" "Current directory:" ./app
    else
        skip_test "compile with native dep" "luafilesystem installation failed"
    fi
    cleanup_test_dir
else
    skip_test "native compile tests" "no C compiler available"
fi

# Test 5: Compile non-existent file fails
setup_test_dir
run_test_fail "compile non-existent fails" "$LUNE" compile nonexistent.lua -o app
cleanup_test_dir

# Test 6: Compile to nested output path
setup_test_dir
cp "$FIXTURES_DIR/simple_script.lua" main.lua
mkdir -p build/bin
run_test "compile to nested path" "$LUNE" compile main.lua -o build/bin/app
run_test_file_exists "nested executable created" "build/bin/app"
run_test_output "nested executable runs" "Hello from lune!" ./build/bin/app
cleanup_test_dir

# Test 7: Compiled executable is self-contained (doesn't need lua_deps)
setup_test_dir
"$LUNE" install argparse > /dev/null 2>&1
cp "$FIXTURES_DIR/argparse_script.lua" main.lua
"$LUNE" compile main.lua -o app > /dev/null 2>&1

# Move executable to new directory without lua_deps
mkdir isolated
mv app isolated/
cd isolated
run_test_output "compiled is self-contained" "Hello, World!" ./app
cd ..
cleanup_test_dir

# Test 8: Compiled executable handles exit codes
setup_test_dir
cp "$FIXTURES_DIR/exit_code.lua" main.lua
"$LUNE" compile main.lua -o app > /dev/null 2>&1
run_test_exit "compiled exit code 0" 0 ./app 0
run_test_exit "compiled exit code 1" 1 ./app 1
run_test_exit "compiled exit code 42" 42 ./app 42
cleanup_test_dir

# Test 9: Compiled executable receives arguments
setup_test_dir
cat > main.lua << 'EOF'
print("arg1: " .. (arg[1] or "nil"))
print("arg2: " .. (arg[2] or "nil"))
EOF
"$LUNE" compile main.lua -o app > /dev/null 2>&1
run_test_output "compiled receives arg1" "arg1: hello" ./app hello world
run_test_output "compiled receives arg2" "arg2: world" ./app hello world
cleanup_test_dir

# Test 10: Compile shows file size
setup_test_dir
cp "$FIXTURES_DIR/simple_script.lua" main.lua
run_test_output "compile shows size" "Created:" "$LUNE" compile main.lua -o app
cleanup_test_dir
