-- Lune configuration management

local M = {}

local paths = require("core.paths")

-- Default configuration values
M.defaults = {
    -- Lua version compatibility
    lua_version = "5.1",

    -- Package registry
    registry_url = "https://luarocks.org",

    -- Local dependencies directory
    deps_dir = "lua_deps",

    -- Compile options
    compile = {
        bytecode = true,        -- Compile to LuaJIT bytecode
        strip_debug = true,     -- Strip debug info from bytecode
    },
}

local config_cache = nil

--- Load configuration
function M.load(force)
    if config_cache and not force then
        return config_cache
    end

    local fs = require("core.fs")

    -- Start with defaults
    config_cache = {}
    for k, v in pairs(M.defaults) do
        if type(v) == "table" then
            config_cache[k] = {}
            for k2, v2 in pairs(v) do
                config_cache[k][k2] = v2
            end
        else
            config_cache[k] = v
        end
    end

    -- Load project config if exists
    local config_path = paths.join(paths.get_lune_config_dir(), "config.lua")

    if fs.exists(config_path) then
        local content, err = fs.read_file(config_path)
        if content then
            -- Load in sandbox
            local chunk, load_err = load("return " .. content, "config", "t", {})
            if not chunk then
                chunk = loadfile(config_path)
            end

            if chunk then
                local ok, project_config = pcall(chunk)
                if ok and type(project_config) == "table" then
                    M.merge(config_cache, project_config)
                end
            end
        end
    end

    return config_cache
end

--- Deep merge tables
function M.merge(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" and type(target[k]) == "table" then
            M.merge(target[k], v)
        else
            target[k] = v
        end
    end
    return target
end

--- Get a config value
function M.get(key)
    local cfg = M.load()

    -- Support dotted keys like "compile.bytecode"
    local value = cfg
    for part in key:gmatch("[^%.]+") do
        if type(value) ~= "table" then
            return nil
        end
        value = value[part]
    end

    return value
end

--- Set a config value (in memory only)
function M.set(key, value)
    local cfg = M.load()

    -- Support dotted keys
    local parts = {}
    for part in key:gmatch("[^%.]+") do
        table.insert(parts, part)
    end

    local target = cfg
    for i = 1, #parts - 1 do
        if type(target[parts[i]]) ~= "table" then
            target[parts[i]] = {}
        end
        target = target[parts[i]]
    end

    target[parts[#parts]] = value
end

--- Save configuration to file
function M.save()
    local fs = require("core.fs")
    local cfg = M.load()

    -- Ensure config directory exists
    local config_dir = paths.get_lune_config_dir()
    fs.mkdir_p(config_dir)

    -- Serialize config
    local function serialize(tbl, indent)
        indent = indent or ""
        local lines = {}
        table.insert(lines, "{")

        for k, v in pairs(tbl) do
            local key_str
            if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                key_str = k
            else
                key_str = string.format("[%q]", k)
            end

            local value_str
            if type(v) == "string" then
                value_str = string.format("%q", v)
            elseif type(v) == "table" then
                value_str = serialize(v, indent .. "    ")
            else
                value_str = tostring(v)
            end

            table.insert(lines, indent .. "    " .. key_str .. " = " .. value_str .. ",")
        end

        table.insert(lines, indent .. "}")
        return table.concat(lines, "\n")
    end

    local content = serialize(cfg)
    local config_path = paths.join(config_dir, "config.lua")

    return fs.write_file(config_path, "return " .. content .. "\n")
end

return M
