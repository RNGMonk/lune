-- Lune install command
-- Install packages to lua_deps

local M = {}

local installer = require("package.installer")

function M.execute(args)
    if #args == 0 then
        io.stderr:write("Usage: lune install <package> [version]\n")
        io.stderr:write("\nExamples:\n")
        io.stderr:write("  lune install argparse\n")
        io.stderr:write("  lune install luasocket 3.1.0-1\n")
        return 1
    end

    local package_name = args[1]
    local version = args[2]  -- Optional

    -- Handle flags
    local force = false
    for i, arg in ipairs(args) do
        if arg == "--force" or arg == "-f" then
            force = true
            if i == 1 then
                package_name = args[2]
                version = args[3]
            end
        end
    end

    local ok, err = installer.install(package_name, version, {force = force})
    if not ok then
        io.stderr:write("Error: " .. tostring(err) .. "\n")
        return 1
    end

    return 0
end

return M
