#!/bin/bash
# Tests for the init command

LUNE=$(get_lune)

echo "Testing: init command"

# Test 1: Init new project with name
setup_test_dir
run_test "init creates project" "$LUNE" init myproject
run_test_file_exists "rockspec created" "myproject-0.1.0-1.rockspec"
run_test_file_exists "main.lua created" "main.lua"
run_test_dir_exists "lua_deps created" "lua_deps"
run_test_dir_exists ".lune created" ".lune"
run_test_file_exists ".gitignore created" ".gitignore"
cleanup_test_dir

# Test 2: Init with "." uses directory name
setup_test_dir
mkdir testproj && cd testproj
run_test "init with dot" "$LUNE" init .
run_test_file_exists "rockspec uses dir name" "testproj-0.1.0-1.rockspec"
cd ..
cleanup_test_dir

# Test 3: Init without argument uses cwd name
setup_test_dir
mkdir another && cd another
run_test "init without argument" "$LUNE" init
run_test_file_exists "rockspec from cwd name" "another-0.1.0-1.rockspec"
cd ..
cleanup_test_dir

# Test 4: Init does not overwrite existing main.lua
setup_test_dir
echo 'print("existing content")' > main.lua
run_test "init with existing main.lua" "$LUNE" init testproject
run_test_output "main.lua preserved" "existing content" cat main.lua
cleanup_test_dir

# Test 5: Init fails if already initialized (rockspec exists)
setup_test_dir
"$LUNE" init firstproject > /dev/null 2>&1
run_test_fail "init fails if rockspec exists" "$LUNE" init secondproject
cleanup_test_dir

# Test 6: Generated project can be run
setup_test_dir
"$LUNE" init myapp > /dev/null 2>&1
run_test_output "generated project runs" "Hello from myapp!" "$LUNE" main.lua
cleanup_test_dir

# Test 7: Generated rockspec has required fields
setup_test_dir
"$LUNE" init validproject > /dev/null 2>&1
run_test_output "rockspec has package field" 'package = "validproject"' cat validproject-0.1.0-1.rockspec
run_test_output "rockspec has version field" 'version = "0.1.0-1"' cat validproject-0.1.0-1.rockspec
run_test_output "rockspec has dependencies" "dependencies" cat validproject-0.1.0-1.rockspec
run_test_output "rockspec has build section" "build" cat validproject-0.1.0-1.rockspec
cleanup_test_dir

# Test 8: Generated .gitignore has expected content
setup_test_dir
"$LUNE" init gitproject > /dev/null 2>&1
run_test_output "gitignore has lua_deps" "lua_deps" cat .gitignore
run_test_output "gitignore has .lune" ".lune" cat .gitignore
cleanup_test_dir

# Test 9: Project name with special characters
setup_test_dir
"$LUNE" init "my-cool-project" > /dev/null 2>&1
run_test_file_exists "rockspec with dashes" "my-cool-project-0.1.0-1.rockspec"
run_test_output "module name sanitized" "my_cool_project" cat my-cool-project-0.1.0-1.rockspec
cleanup_test_dir
