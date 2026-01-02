-- Lune rockspec parser
-- Rockspecs are Lua files with package metadata

local M = {}

--- Parse a rockspec string into a table
function M.parse(content)
    -- Rockspecs are Lua files, load in a sandbox
    local env = {}
    local fn, err = load(content, "rockspec", "t", env)
    if not fn then
        return nil, "Failed to parse rockspec: " .. tostring(err)
    end

    local ok, run_err = pcall(fn)
    if not ok then
        return nil, "Failed to execute rockspec: " .. tostring(run_err)
    end

    -- Validate required fields
    if not env.package then
        return nil, "Rockspec missing 'package' field"
    end
    if not env.version then
        return nil, "Rockspec missing 'version' field"
    end

    return {
        package = env.package,
        version = env.version,
        description = env.description or {},
        dependencies = env.dependencies or {},
        source = env.source or {},
        build = env.build or {},
        external_dependencies = env.external_dependencies or {},
        supported_platforms = env.supported_platforms,
    }
end

--- Parse dependency string like "lua >= 5.1, < 5.4"
function M.parse_dependency(dep_str)
    -- Extract package name (first word)
    local name = dep_str:match("^([%w_%-]+)")
    if not name then
        return nil
    end

    -- Extract version constraints
    local constraints = {}
    for op, version in dep_str:gmatch("([<>=!]+)%s*([%d%.]+)") do
        table.insert(constraints, {op = op, version = version})
    end

    return {
        name = name,
        constraints = constraints,
        raw = dep_str,
    }
end

--- Filter dependencies for LuaJIT/Lua 5.1 compatibility
function M.filter_dependencies(deps)
    local filtered = {}

    for _, dep_str in ipairs(deps) do
        local dep = M.parse_dependency(dep_str)
        if dep then
            -- Skip lua itself - we provide LuaJIT
            if dep.name ~= "lua" then
                table.insert(filtered, dep)
            end
        end
    end

    return filtered
end

--- Check if a version satisfies constraints
function M.version_satisfies(version, constraints)
    if not constraints or #constraints == 0 then
        return true
    end

    local function compare_versions(v1, v2)
        local p1 = {}
        local p2 = {}
        for n in v1:gmatch("%d+") do table.insert(p1, tonumber(n)) end
        for n in v2:gmatch("%d+") do table.insert(p2, tonumber(n)) end

        for i = 1, math.max(#p1, #p2) do
            local n1 = p1[i] or 0
            local n2 = p2[i] or 0
            if n1 < n2 then return -1 end
            if n1 > n2 then return 1 end
        end
        return 0
    end

    for _, c in ipairs(constraints) do
        local cmp = compare_versions(version, c.version)
        local satisfied = false

        if c.op == "==" or c.op == "=" then
            satisfied = cmp == 0
        elseif c.op == ">=" then
            satisfied = cmp >= 0
        elseif c.op == "<=" then
            satisfied = cmp <= 0
        elseif c.op == ">" then
            satisfied = cmp > 0
        elseif c.op == "<" then
            satisfied = cmp < 0
        elseif c.op == "~>" then
            -- Pessimistic version constraint (e.g., ~> 1.2 means >= 1.2, < 2.0)
            satisfied = cmp >= 0
            -- Also check upper bound
            local major = c.version:match("^(%d+)")
            if major then
                local upper = tostring(tonumber(major) + 1) .. ".0"
                satisfied = satisfied and compare_versions(version, upper) < 0
            end
        else
            satisfied = true  -- Unknown operator, assume satisfied
        end

        if not satisfied then
            return false
        end
    end

    return true
end

--- Generate a rockspec for a new project
function M.generate(name, version)
    version = version or "0.1.0"

    return string.format([[
package = %q
version = %q

source = {
    url = "git://github.com/user/%s"
}

description = {
    summary = "A Lune project",
    license = "MIT"
}

dependencies = {
    "lua >= 5.1"
}

build = {
    type = "builtin",
    modules = {}
}
]], name, version .. "-1", name)
end

return M
