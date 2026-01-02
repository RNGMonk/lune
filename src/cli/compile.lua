-- Lune compile command
-- Compile Lua projects to standalone executables

local M = {}

local fs = require("core.fs")
local paths = require("core.paths")
local bundler = require("compile.bundler")
local fuser = require("compile.fuser")

function M.execute(args)
    if #args == 0 then
        io.stderr:write("Usage: lune compile <script.lua> [-o output]\n")
        return 1
    end

    -- Parse arguments
    local input = nil
    local output = nil

    local i = 1
    while i <= #args do
        if args[i] == "-o" or args[i] == "--output" then
            i = i + 1
            output = args[i]
        elseif not input then
            input = args[i]
        end
        i = i + 1
    end

    if not input then
        io.stderr:write("Error: No input file specified\n")
        return 1
    end

    -- Check input exists
    if not fs.exists(input) then
        io.stderr:write("Error: Input file not found: " .. input .. "\n")
        return 1
    end

    -- Default output name
    if not output then
        output = paths.basename(input, ".lua")
    end

    print("Bundling " .. input .. "...")

    -- Create ZIP bundle
    local zip_data, err = bundler.bundle(input)
    if not zip_data then
        io.stderr:write("Error bundling: " .. tostring(err) .. "\n")
        return 1
    end

    print("Creating executable...")

    -- Fuse with runtime
    local ok, fuse_err = fuser.fuse(zip_data, output)
    if not ok then
        io.stderr:write("Error: " .. tostring(fuse_err) .. "\n")
        return 1
    end

    -- Get file size
    local size = fs.size(output) or 0
    local size_str
    if size > 1024 * 1024 then
        size_str = string.format("%.1f MB", size / (1024 * 1024))
    elseif size > 1024 then
        size_str = string.format("%.1f KB", size / 1024)
    else
        size_str = size .. " bytes"
    end

    print("Created: " .. output .. " (" .. size_str .. ")")
    return 0
end

return M
