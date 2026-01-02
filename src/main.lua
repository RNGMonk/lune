#!/usr/bin/env luajit
-- Lune - LuaJIT interpreter and package manager
-- Main entry point

local function get_lune_root()
    -- Get the directory containing this script
    local info = debug.getinfo(1, "S")
    local path = info.source:match("^@(.*/)")
    if path then
        -- Go up from src/ to project root
        return path:gsub("/src/$", "")
    end
    return "."
end

-- Set up package paths for lune's own modules
local root = get_lune_root()
package.path = table.concat({
    root .. "/src/?.lua",
    root .. "/src/?/init.lua",
    root .. "/vendor/?.lua",
    root .. "/vendor/?/init.lua",
    package.path
}, ";")

-- Store root for other modules
_G.LUNE_ROOT = root

-- Load and run CLI
local cli = require("cli")
local exit_code = cli.run(arg)
os.exit(exit_code or 0)
