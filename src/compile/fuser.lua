-- Lune ZIP fuser
-- Fuses a ZIP archive with the lunert runtime

local M = {}

local fs = require("core.fs")
local paths = require("core.paths")

--- Find the start of the ZIP data in a fused executable
local function find_zip_start(data)
    -- Search for first local file header (PK\x03\x04)
    local pos = 1
    while pos < #data - 4 do
        if data:sub(pos, pos + 3) == "PK\x03\x04" then
            return pos
        end
        pos = pos + 1
    end
    return nil
end

--- Extract the runtime portion from a fused lune executable
local function extract_runtime_from_self()
    local exe_path = _G._LUNERT_EXE_PATH
    if not exe_path then
        return nil
    end

    local content = fs.read_file(exe_path)
    if not content then
        return nil
    end

    -- Find where the ZIP starts
    local zip_start = find_zip_start(content)
    if not zip_start then
        return nil
    end

    -- Return just the runtime portion (before the ZIP)
    return content:sub(1, zip_start - 1)
end

--- Get path to the lunert runtime
function M.get_runtime_path()
    -- Check various locations
    local candidates = {
        -- Relative to lune source
        paths.join(_G.LUNE_ROOT or ".", "runtime/lunert"),
        -- Installed location
        "/usr/local/lib/lune/lunert",
        -- User installation
        paths.join(os.getenv("HOME") or "", ".lune/runtime/lunert"),
    }

    for _, path in ipairs(candidates) do
        if fs.exists(path) and fs.is_file(path) then
            return path
        end
    end

    return nil
end

--- Get the runtime binary data
function M.get_runtime_data()
    -- If running embedded, extract from self
    if _G.LUNE_EMBEDDED then
        local data = extract_runtime_from_self()
        if data then
            return data
        end
    end

    -- Otherwise, try to read from file
    local runtime_path = M.get_runtime_path()
    if runtime_path then
        return fs.read_file(runtime_path)
    end

    return nil
end

--- Fuse a ZIP archive with the runtime to create an executable
function M.fuse(zip_data, output_path)
    local runtime_data = M.get_runtime_data()
    if not runtime_data then
        return false, "Cannot find lunert runtime. Build it with: make -C runtime"
    end

    -- Concatenate: runtime + ZIP
    local fused_data = runtime_data .. zip_data

    -- Write output
    local ok, err = fs.write_file(output_path, fused_data)
    if not ok then
        return false, "Cannot write output: " .. tostring(err)
    end

    -- Make executable
    os.execute("chmod +x " .. output_path)

    return true
end

return M
