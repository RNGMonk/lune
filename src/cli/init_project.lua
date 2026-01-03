-- Lune init command
-- Initialize a new Lune project

local M = {}

local fs = require("core.fs")
local paths = require("core.paths")

local ROCKSPEC_TEMPLATE = [[
package = "%s"
version = "%s-1"

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
    modules = {
        %s = "main.lua"
    }
}
]]

local MAIN_TEMPLATE = [[
-- %s
-- A Lune project

local function main()
    print("Hello from %s!")
end

main()
]]

local GITIGNORE_TEMPLATE = [[
# Lune
lua_deps/
.lune/

# Compiled binaries
*.exe
%s

# Editor
*.swp
*~
.vscode/
.idea/
]]

function M.execute(args)
    local name = args[1]

    -- If no name provided or ".", use current directory name
    if not name or name == "." then
        local cwd = fs.cwd()
        name = paths.basename(cwd)
    end

    -- Clean up name for use as module name
    local module_name = name:gsub("[^%w_]", "_"):lower()

    print("Initializing Lune project: " .. name)

    -- Check if already initialized
    local entries = fs.listdir(".") or {}
    for _, entry in ipairs(entries) do
        if entry:match("%.rockspec$") then
            io.stderr:write("Error: Project already initialized (found " .. entry .. ")\n")
            return 1
        end
    end

    -- Create directories
    fs.mkdir_p("lua_deps")
    fs.mkdir_p(".lune")

    -- Create rockspec
    local rockspec_name = name .. "-0.1.0-1.rockspec"
    local rockspec = string.format(ROCKSPEC_TEMPLATE, name, "0.1.0", name, module_name)
    fs.write_file(rockspec_name, rockspec)

    -- Create main.lua if it doesn't exist
    if not fs.exists("main.lua") then
        local main = string.format(MAIN_TEMPLATE, name, name)
        fs.write_file("main.lua", main)
    end

    -- Create .gitignore if it doesn't exist
    if not fs.exists(".gitignore") then
        local gitignore = string.format(GITIGNORE_TEMPLATE, name)
        fs.write_file(".gitignore", gitignore)
    end

    print("")
    print("Created:")
    print("  " .. rockspec_name)
    if not fs.exists("main.lua") then
        print("  main.lua")
    end
    print("  lua_deps/")
    print("  .lune/")
    print("  .gitignore")
    print("")
    print("Next steps:")
    print("  lune main.lua           # Run your project")
    print("  lune install <package>  # Add dependencies")
    print("  lune compile main.lua   # Build standalone executable")

    return 0
end

return M
