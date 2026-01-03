-- Lune CLI Framework
-- Handles argument parsing and command dispatch

local M = {}

local VERSION = "0.1.0"

-- Command name mapping (for commands with different module names)
local command_modules = {
    init = "init_project",  -- init command is in init_project.lua
}

-- Lazy-load commands to avoid circular dependencies
local function get_command(name)
    local module_name = command_modules[name] or name
    local ok, cmd = pcall(require, "cli." .. module_name)
    if ok then return cmd end
    return nil
end

local function show_help()
    print([[
Lune - LuaJIT Interpreter and Package Manager

Usage:
    lune <script.lua> [args...]     Run a Lua script
    lune run <script.lua> [args...] Run a Lua script (explicit)
    lune install                    Install dependencies from rockspec
    lune install <package> [--save] Install a package to ./lua_deps
    lune compile <script> -o <out>  Compile to standalone executable
    lune init [name]                Initialize a new project

Options:
    -h, --help                      Show this help message
    -v, --version                   Show version information

Examples:
    lune main.lua                   Run main.lua
    lune install                    Install all rockspec dependencies
    lune install argparse --save    Install and add to rockspec
    lune compile main.lua -o app    Create standalone executable
]])
    return 0
end

local function show_version()
    print("lune " .. VERSION)
    print("LuaJIT " .. (jit and jit.version or "unknown"))
    return 0
end

function M.run(args)
    -- Handle global flags
    if not args[1] or args[1] == "-h" or args[1] == "--help" or args[1] == "help" then
        return show_help()
    end

    if args[1] == "-v" or args[1] == "--version" or args[1] == "version" then
        return show_version()
    end

    -- If first arg is a .lua file, implicit "run" command
    if args[1]:match("%.lua$") then
        local run_cmd = get_command("run")
        if run_cmd then
            return run_cmd.execute(args)
        end
        io.stderr:write("Error: run command not available\n")
        return 1
    end

    -- Look up explicit command
    local cmd_name = args[1]
    local cmd = get_command(cmd_name)

    if not cmd then
        -- Check if it might be a file without .lua extension
        local f = io.open(args[1], "r")
        if f then
            f:close()
            local run_cmd = get_command("run")
            if run_cmd then
                return run_cmd.execute(args)
            end
        end

        io.stderr:write("Unknown command: " .. cmd_name .. "\n")
        io.stderr:write("Run 'lune --help' for usage.\n")
        return 1
    end

    -- Remove command name and pass rest to handler
    local cmd_args = {}
    for i = 2, #args do
        cmd_args[i - 1] = args[i]
    end

    return cmd.execute(cmd_args)
end

return M
