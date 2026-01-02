-- Lune runtime loader
-- Custom package loader for lua_deps

local M = {}

local paths = require("core.paths")
local fs = require("core.fs")

--- Set up package paths for the current project
function M.setup_project_paths()
    local lua_deps = paths.get_lua_deps()
    local version = "5.1"  -- LuaJIT is Lua 5.1 compatible

    -- Only add paths if lua_deps exists
    if fs.exists(lua_deps) then
        -- Prepend lua_deps paths to package.path
        package.path = table.concat({
            lua_deps .. "/share/lua/" .. version .. "/?.lua",
            lua_deps .. "/share/lua/" .. version .. "/?/init.lua",
            package.path
        }, ";")

        -- Prepend lua_deps paths to package.cpath
        package.cpath = table.concat({
            lua_deps .. "/lib/lua/" .. version .. "/?.so",
            lua_deps .. "/lib/lua/" .. version .. "/?.dylib",
            package.cpath
        }, ";")
    end
end

--- Create a custom searcher for fused executables
-- This will be used when running compiled binaries
function M.create_fused_searcher(zip_reader)
    return function(modname)
        -- Convert module name to path
        local mod_path = modname:gsub("%.", "/")

        -- Try different path patterns
        local patterns = {
            mod_path .. ".lua",
            mod_path .. "/init.lua",
            "lua_deps/share/lua/5.1/" .. mod_path .. ".lua",
            "lua_deps/share/lua/5.1/" .. mod_path .. "/init.lua",
        }

        for _, path in ipairs(patterns) do
            local content = zip_reader:read(path)
            if content then
                local fn, err = loadstring(content, "@" .. path)
                if fn then
                    return fn
                else
                    return nil, err
                end
            end
        end

        return nil, "module '" .. modname .. "' not found in fused archive"
    end
end

--- Get the list of standard library modules (should not be overridden)
function M.get_stdlib_modules()
    return {
        "string", "table", "math", "io", "os", "debug",
        "coroutine", "package", "bit", "ffi", "jit"
    }
end

--- Check if a module is part of the standard library
function M.is_stdlib(modname)
    local root = modname:match("^([^%.]+)")
    for _, stdlib in ipairs(M.get_stdlib_modules()) do
        if root == stdlib then
            return true
        end
    end
    return false
end

return M
