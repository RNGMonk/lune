-- Lune run command
-- Execute Lua scripts with LuaJIT

local M = {}

local fs = require("core.fs")
local paths = require("core.paths")
local loader = require("runtime.loader")

function M.execute(args)
    if #args == 0 then
        io.stderr:write("Usage: lune [run] <script.lua> [args...]\n")
        return 1
    end

    local script = args[1]

    -- Check if file exists
    if not fs.exists(script) then
        io.stderr:write("Error: Cannot open file: " .. script .. "\n")
        return 1
    end

    -- Set up lua_deps in package path
    loader.setup_project_paths()

    -- Set up arg table for the script
    local script_args = {[0] = script}
    for i = 2, #args do
        script_args[i - 1] = args[i]
    end

    -- Replace global arg
    _G.arg = script_args

    -- Load and run the script
    local fn, err = loadfile(script)
    if not fn then
        io.stderr:write("Error loading " .. script .. ": " .. tostring(err) .. "\n")
        return 1
    end

    -- Run with error handling
    local ok, result = xpcall(fn, function(err)
        return debug.traceback(err, 2)
    end)

    if not ok then
        io.stderr:write(tostring(result) .. "\n")
        return 1
    end

    -- Return script's return value if it's a number
    if type(result) == "number" then
        return result
    end

    return 0
end

return M
