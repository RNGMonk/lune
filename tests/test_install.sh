#!/bin/bash
# Tests for the install command

LUNE=$(get_lune)

echo "Testing: install command"

# Test 1: Install help
run_test_output "install help" "Usage:" "$LUNE" install --help

# Test 2: Install pure Lua package (argparse)
setup_test_dir
run_test "install argparse succeeds" "$LUNE" install argparse
run_test_file_exists "argparse.lua installed" "lua_deps/share/lua/5.1/argparse.lua"
cleanup_test_dir

# Test 3: Use installed package
setup_test_dir
"$LUNE" install argparse > /dev/null 2>&1
cp "$FIXTURES_DIR/argparse_script.lua" .
run_test_output "script uses argparse" "Hello, World!" "$LUNE" argparse_script.lua
run_test_output "argparse parses args" "Hello, Test!" "$LUNE" argparse_script.lua -n Test
cleanup_test_dir

# Test 4: Install native package (luafilesystem) - only if CC available
if command -v cc &> /dev/null; then
    setup_test_dir
    if "$LUNE" install luafilesystem > /dev/null 2>&1; then
        run_test_file_exists "lfs.so installed" "lua_deps/lib/lua/5.1/lfs.so"

        # Test using native module
        cp "$FIXTURES_DIR/lfs_script.lua" .
        run_test_output "script uses lfs" "Current directory:" "$LUNE" lfs_script.lua
    else
        skip_test "install luafilesystem" "compilation failed"
    fi
    cleanup_test_dir
else
    skip_test "native package tests" "no C compiler available"
fi

# Test 5: Install from rockspec (no package specified)
setup_test_dir
"$LUNE" init testproject > /dev/null 2>&1
# Add argparse as dependency
cat > testproject-0.1.0-1.rockspec << 'EOF'
package = "testproject"
version = "0.1.0-1"
source = { url = "git://github.com/user/testproject" }
description = { summary = "Test", license = "MIT" }
dependencies = { "lua >= 5.1", "argparse >= 0.7.0" }
build = { type = "builtin", modules = { testproject = "main.lua" } }
EOF
run_test_output "install from rockspec" "Installing dependencies" "$LUNE" install
run_test_file_exists "argparse from rockspec" "lua_deps/share/lua/5.1/argparse.lua"
cleanup_test_dir

# Test 6: Install with --save flag adds to rockspec
setup_test_dir
"$LUNE" init savetest > /dev/null 2>&1
run_test "install with --save" "$LUNE" install inspect --save
run_test_output "rockspec updated with inspect" "inspect" cat savetest-0.1.0-1.rockspec
cleanup_test_dir

# Test 7: Already installed package shows message
setup_test_dir
"$LUNE" install argparse > /dev/null 2>&1
run_test_output "already installed message" "already installed" "$LUNE" install argparse
cleanup_test_dir

# Test 8: Force reinstall
setup_test_dir
"$LUNE" install argparse > /dev/null 2>&1
run_test_output "force reinstall" "Installing" "$LUNE" install argparse --force
cleanup_test_dir

# Test 9: Install non-existent package fails gracefully
setup_test_dir
run_test_fail "non-existent package fails" "$LUNE" install nonexistent-package-that-does-not-exist-12345
cleanup_test_dir

# Test 10: Install creates lua_deps structure
setup_test_dir
"$LUNE" install argparse > /dev/null 2>&1
run_test_dir_exists "lua_deps exists" "lua_deps"
run_test_dir_exists "share/lua/5.1 exists" "lua_deps/share/lua/5.1"
run_test_dir_exists "rocks manifest exists" "lua_deps/lib/luarocks/rocks-5.1"
cleanup_test_dir

# Test 11: Multiple packages can be installed
setup_test_dir
"$LUNE" install argparse > /dev/null 2>&1
"$LUNE" install inspect > /dev/null 2>&1
run_test_file_exists "argparse installed" "lua_deps/share/lua/5.1/argparse.lua"
run_test_file_exists "inspect installed" "lua_deps/share/lua/5.1/inspect.lua"
cleanup_test_dir
