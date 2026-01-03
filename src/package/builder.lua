-- Lune package builder
-- Builds packages from source according to rockspec build instructions

local M = {}

local fs = require("core.fs")
local paths = require("core.paths")
local ffi = require("ffi")

--- Detect LuaJIT include and library paths
local function get_luajit_paths()
    local is_macos = ffi.os == "OSX"

    local search_paths = {}

    if is_macos then
        -- Homebrew Apple Silicon
        table.insert(search_paths, {inc = "/opt/homebrew/include/luajit-2.1", lib = "/opt/homebrew/lib"})
        -- Homebrew Intel Mac
        table.insert(search_paths, {inc = "/usr/local/include/luajit-2.1", lib = "/usr/local/lib"})
    else
        -- Linux standard paths
        table.insert(search_paths, {inc = "/usr/include/luajit-2.1", lib = "/usr/lib"})
        table.insert(search_paths, {inc = "/usr/local/include/luajit-2.1", lib = "/usr/local/lib"})
        table.insert(search_paths, {inc = "/usr/include/luajit-2.0", lib = "/usr/lib/x86_64-linux-gnu"})
    end

    -- Find first path where lua.h exists
    for _, p in ipairs(search_paths) do
        local lua_h = p.inc .. "/lua.h"
        local f = io.open(lua_h, "r")
        if f then
            f:close()
            return p.inc, p.lib
        end
    end

    return nil, nil
end

--- Install a builtin-type package
-- This is the most common type - just copy Lua files
function M.build_builtin(spec, source_dir, install_dir)
    local build = spec.build
    local lua_dir = paths.join(install_dir, "share/lua/5.1")
    local lib_dir = paths.join(install_dir, "lib/lua/5.1")

    fs.mkdir_p(lua_dir)
    fs.mkdir_p(lib_dir)

    -- Install Lua modules
    if build.modules then
        for modname, moddef in pairs(build.modules) do
            local ok, err = M.install_module(modname, moddef, source_dir, lua_dir, lib_dir)
            if not ok then
                return false, err
            end
        end
    end

    -- Copy additional files if specified
    if build.copy_directories then
        for _, dir in ipairs(build.copy_directories) do
            local src = paths.join(source_dir, dir)
            local dst = paths.join(lua_dir, dir)
            if fs.exists(src) then
                M.copy_tree(src, dst)
            end
        end
    end

    return true
end

--- Install a single module
function M.install_module(modname, moddef, source_dir, lua_dir, lib_dir)
    -- moddef can be a string (path) or a table (complex definition)
    if type(moddef) == "string" then
        -- Simple case: just a path to a Lua file
        if moddef:match("%.lua$") then
            return M.install_lua_file(modname, moddef, source_dir, lua_dir)
        elseif moddef:match("%.c$") then
            return M.install_c_module(modname, {moddef}, source_dir, lib_dir)
        end
    elseif type(moddef) == "table" then
        -- Complex case: table with sources, libraries, etc.
        if moddef[1] and moddef[1]:match("%.lua$") then
            return M.install_lua_file(modname, moddef[1], source_dir, lua_dir)
        elseif moddef.sources then
            return M.install_c_module(modname, moddef.sources, source_dir, lib_dir, moddef)
        end
    end

    return true  -- Skip unknown module types
end

--- Install a Lua file as a module
function M.install_lua_file(modname, source_path, source_dir, lua_dir)
    local src = paths.join(source_dir, source_path)
    if not fs.exists(src) then
        return false, "Source file not found: " .. src
    end

    -- Convert module name to path
    local dest_path = modname:gsub("%.", "/") .. ".lua"
    local dst = paths.join(lua_dir, dest_path)

    -- Create parent directories
    fs.mkdir_p(paths.dirname(dst))

    -- Copy file
    local ok, err = fs.copy_file(src, dst)
    if not ok then
        return false, "Failed to copy " .. src .. " to " .. dst .. ": " .. tostring(err)
    end

    return true
end

--- Install a C module (compile from source)
function M.install_c_module(modname, sources, source_dir, lib_dir, options)
    options = options or {}
    local is_macos = ffi.os == "OSX"

    -- Detect LuaJIT paths
    local lua_inc, lua_lib = get_luajit_paths()
    if not lua_inc then
        return false, "Cannot find LuaJIT headers. Please install LuaJIT development files."
    end

    -- Convert module name to output path
    local mod_path = modname:gsub("%.", "/")
    local output = paths.join(lib_dir, mod_path .. ".so")

    -- Create parent directories
    fs.mkdir_p(paths.dirname(output))

    -- Build source file list
    local src_files = {}
    for _, src in ipairs(sources) do
        table.insert(src_files, paths.join(source_dir, src))
    end

    -- Build include directories
    local incdirs = {"-I" .. lua_inc}
    if options.incdirs then
        for _, dir in ipairs(options.incdirs) do
            table.insert(incdirs, "-I" .. paths.join(source_dir, dir))
        end
    end

    -- Build library directories
    local libdirs = {}
    if lua_lib then
        table.insert(libdirs, "-L" .. lua_lib)
    end
    if options.libdirs then
        for _, dir in ipairs(options.libdirs) do
            table.insert(libdirs, "-L" .. paths.join(source_dir, dir))
        end
    end

    -- Build libraries to link
    local libs = {}
    if options.libraries then
        for _, lib in ipairs(options.libraries) do
            table.insert(libs, "-l" .. lib)
        end
    end

    -- Platform-specific flags
    local platform_flags = ""
    if is_macos then
        -- macOS: allow undefined symbols (resolved at runtime by LuaJIT)
        platform_flags = "-undefined dynamic_lookup"
    end

    -- Compile command
    local cmd = string.format(
        "cc -shared -fPIC -O2 %s %s %s %s %s -o %s 2>&1",
        platform_flags,
        table.concat(incdirs, " "),
        table.concat(src_files, " "),
        table.concat(libdirs, " "),
        table.concat(libs, " "),
        output
    )

    local handle = io.popen(cmd)
    local compile_output = handle:read("*a")
    handle:close()

    -- Validate compilation succeeded by checking output file exists
    if not fs.exists(output) then
        return false, "Compilation failed for " .. modname .. ":\n" ..
               "Command: " .. cmd .. "\n" ..
               "Output:\n" .. compile_output
    end

    return true
end

--- Copy a directory tree
function M.copy_tree(src, dst)
    fs.mkdir_p(dst)

    local entries = fs.listdir(src)
    if not entries then
        return false
    end

    for _, entry in ipairs(entries) do
        local src_path = paths.join(src, entry)
        local dst_path = paths.join(dst, entry)

        if fs.is_dir(src_path) then
            M.copy_tree(src_path, dst_path)
        else
            fs.copy_file(src_path, dst_path)
        end
    end

    return true
end

--- Build a package based on its rockspec
function M.build(spec, source_dir, install_dir)
    local build_type = spec.build.type or "builtin"

    if build_type == "builtin" then
        return M.build_builtin(spec, source_dir, install_dir)
    elseif build_type == "none" then
        -- No build required, just copy lua files if present
        return M.build_builtin(spec, source_dir, install_dir)
    elseif build_type == "make" then
        return M.build_make(spec, source_dir, install_dir)
    else
        return false, "Unsupported build type: " .. build_type
    end
end

--- Build using make
function M.build_make(spec, source_dir, install_dir)
    local build = spec.build
    local lua_dir = paths.join(install_dir, "share/lua/5.1")
    local lib_dir = paths.join(install_dir, "lib/lua/5.1")

    fs.mkdir_p(lua_dir)
    fs.mkdir_p(lib_dir)

    -- Run make
    local make_cmd = "make"
    if build.build_target then
        make_cmd = make_cmd .. " " .. build.build_target
    end

    -- Detect LuaJIT paths
    local lua_inc, lua_lib = get_luajit_paths()
    if not lua_inc then
        return false, "Cannot find LuaJIT headers. Please install LuaJIT development files."
    end

    -- Add variables
    local vars = {
        "PREFIX=" .. install_dir,
        "LUA_INCDIR=" .. lua_inc,
        "LUA_LIBDIR=" .. (lua_lib or ""),
        "LUA_DIR=" .. lua_dir,
        "INST_LIBDIR=" .. lib_dir,
        "INST_LUADIR=" .. lua_dir,
    }

    if build.build_variables then
        for k, v in pairs(build.build_variables) do
            table.insert(vars, k .. "=" .. v)
        end
    end

    local cmd = string.format(
        "cd %q && %s %s 2>&1",
        source_dir,
        make_cmd,
        table.concat(vars, " ")
    )

    local handle = io.popen(cmd)
    local output = handle:read("*a")
    local success = handle:close()

    if not success then
        return false, "make failed:\n" .. output
    end

    -- Run make install if specified
    if build.install_target then
        local install_cmd = string.format(
            "cd %q && make %s %s 2>&1",
            source_dir,
            build.install_target,
            table.concat(vars, " ")
        )

        handle = io.popen(install_cmd)
        output = handle:read("*a")
        success = handle:close()

        if not success then
            return false, "make install failed:\n" .. output
        end
    end

    return true
end

return M
