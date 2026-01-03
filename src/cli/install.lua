-- Lune install command
-- Install packages to lua_deps

local M = {}

local fs = require("core.fs")
local installer = require("package.installer")
local rockspec = require("package.rockspec")

--- Install all dependencies from rockspec
local function install_from_rockspec(options)
    local rockspec_path = rockspec.find_rockspec()
    if not rockspec_path then
        io.stderr:write("Error: No rockspec found. Use 'lune init' to create one,\n")
        io.stderr:write("       or specify a package: lune install <package>\n")
        return 1
    end

    local content, err = fs.read_file(rockspec_path)
    if not content then
        io.stderr:write("Error: Cannot read rockspec: " .. tostring(err) .. "\n")
        return 1
    end

    local spec, parse_err = rockspec.parse(content)
    if not spec then
        io.stderr:write("Error: Cannot parse rockspec: " .. tostring(parse_err) .. "\n")
        return 1
    end

    local deps = rockspec.filter_dependencies(spec.dependencies)
    if #deps == 0 then
        print("No dependencies to install")
        return 0
    end

    print("Installing dependencies from " .. rockspec_path:match("([^/]+)$") .. "...")

    local failed = {}
    for _, dep in ipairs(deps) do
        local ok, install_err = installer.install(dep.name, nil, options)
        if not ok then
            table.insert(failed, {name = dep.name, err = install_err})
        end
    end

    if #failed > 0 then
        io.stderr:write("\nFailed to install:\n")
        for _, f in ipairs(failed) do
            io.stderr:write("  " .. f.name .. ": " .. tostring(f.err) .. "\n")
        end
        return 1
    end

    print("\nAll dependencies installed successfully")
    return 0
end

function M.execute(args)
    -- Parse arguments
    local package_name = nil
    local version = nil
    local force = false
    local save = false

    for _, arg in ipairs(args) do
        if arg == "--force" or arg == "-f" then
            force = true
        elseif arg == "--save" or arg == "-S" then
            save = true
        elseif arg == "--no-save" then
            save = false
        elseif arg == "-h" or arg == "--help" then
            io.stderr:write("Usage: lune install [package] [version]\n")
            io.stderr:write("\nIf no package is specified, installs dependencies from rockspec.\n")
            io.stderr:write("\nOptions:\n")
            io.stderr:write("  --save, -S         Add to rockspec dependencies\n")
            io.stderr:write("  --no-save          Don't add to rockspec (default)\n")
            io.stderr:write("  --force, -f        Reinstall even if already installed\n")
            io.stderr:write("\nExamples:\n")
            io.stderr:write("  lune install                   Install deps from rockspec\n")
            io.stderr:write("  lune install argparse          Install a package\n")
            io.stderr:write("  lune install argparse --save   Install and add to rockspec\n")
            return 0
        elseif not arg:match("^%-") then
            if not package_name then
                package_name = arg
            elseif not version then
                version = arg
            end
        end
    end

    -- If no package specified, install from rockspec
    if not package_name then
        return install_from_rockspec({force = force})
    end

    local ok, err = installer.install(package_name, version, {force = force})
    if not ok then
        io.stderr:write("Error: " .. tostring(err) .. "\n")
        return 1
    end

    -- Add to rockspec if --save was specified
    if save then
        local rockspec_path = rockspec.find_rockspec()
        if rockspec_path then
            local add_ok, add_result = rockspec.add_dependency(rockspec_path, package_name, version)
            if add_ok then
                if add_result == "already present" then
                    print("  " .. package_name .. " already in rockspec")
                else
                    print("  Added " .. package_name .. " to rockspec")
                end
            else
                io.stderr:write("Warning: Could not update rockspec: " .. tostring(add_result) .. "\n")
            end
        else
            io.stderr:write("Warning: No rockspec found, use 'lune init' to create one\n")
        end
    end

    return 0
end

return M
