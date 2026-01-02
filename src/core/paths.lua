-- Lune path utilities

local M = {}

--- Join path components
function M.join(...)
    local parts = {...}
    local result = table.concat(parts, "/")
    -- Clean up multiple slashes
    result = result:gsub("//+", "/")
    return result
end

--- Get directory name from path
function M.dirname(path)
    local dir = path:match("^(.*/)[^/]+/?$")
    if dir then
        -- Remove trailing slash unless it's root
        if dir ~= "/" then
            dir = dir:gsub("/$", "")
        end
        return dir
    end
    return "."
end

--- Get base name from path
function M.basename(path, suffix)
    -- Remove trailing slashes
    path = path:gsub("/+$", "")
    local base = path:match("([^/]+)$") or path

    -- Remove suffix if provided
    if suffix and base:sub(-#suffix) == suffix then
        base = base:sub(1, -#suffix - 1)
    end

    return base
end

--- Get file extension
function M.extname(path)
    local base = M.basename(path)
    local ext = base:match("%.([^%.]+)$")
    return ext and ("." .. ext) or ""
end

--- Check if path is absolute
function M.is_absolute(path)
    return path:sub(1, 1) == "/"
end

--- Normalize path (resolve . and ..)
function M.normalize(path)
    local is_absolute = M.is_absolute(path)
    local parts = {}

    for part in path:gmatch("[^/]+") do
        if part == ".." then
            if #parts > 0 and parts[#parts] ~= ".." then
                table.remove(parts)
            elseif not is_absolute then
                table.insert(parts, "..")
            end
        elseif part ~= "." then
            table.insert(parts, part)
        end
    end

    local result = table.concat(parts, "/")
    if is_absolute then
        result = "/" .. result
    end

    return result == "" and "." or result
end

--- Get relative path from one path to another
function M.relative(from, to)
    from = M.normalize(from)
    to = M.normalize(to)

    -- Split into parts
    local from_parts = {}
    local to_parts = {}

    for part in from:gmatch("[^/]+") do
        table.insert(from_parts, part)
    end
    for part in to:gmatch("[^/]+") do
        table.insert(to_parts, part)
    end

    -- Find common prefix
    local common = 0
    for i = 1, math.min(#from_parts, #to_parts) do
        if from_parts[i] == to_parts[i] then
            common = i
        else
            break
        end
    end

    -- Build relative path
    local result = {}

    -- Go up from 'from'
    for _ = common + 1, #from_parts do
        table.insert(result, "..")
    end

    -- Go down to 'to'
    for i = common + 1, #to_parts do
        table.insert(result, to_parts[i])
    end

    return #result > 0 and table.concat(result, "/") or "."
end

--- Find project root by looking for markers
function M.find_project_root(start_path)
    local fs = require("core.fs")
    start_path = start_path or fs.cwd()

    -- Markers that indicate a project root
    local markers = {
        "lune.rockspec",
        "lua_deps",
        ".lune",
        ".git",
    }

    local current = start_path

    while current and current ~= "" do
        for _, marker in ipairs(markers) do
            -- Check for rockspec with any name pattern
            if marker == "lune.rockspec" then
                local entries = fs.listdir(current)
                if entries then
                    for _, entry in ipairs(entries) do
                        if entry:match("%.rockspec$") then
                            return current
                        end
                    end
                end
            elseif fs.exists(M.join(current, marker)) then
                return current
            end
        end

        -- Go up one directory
        local parent = M.dirname(current)
        if parent == current then
            break  -- Reached root
        end
        current = parent
    end

    return start_path  -- Default to start path
end

--- Get lua_deps path for current project
function M.get_lua_deps()
    local fs = require("core.fs")
    local root = M.find_project_root()
    return M.join(root, "lua_deps")
end

--- Get lune config directory
function M.get_lune_config_dir()
    local fs = require("core.fs")
    local root = M.find_project_root()
    return M.join(root, ".lune")
end

return M
