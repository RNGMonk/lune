-- Lune ZIP fuser
-- Fuses a ZIP archive with the lunert runtime

local M = {}

local fs = require("core.fs")
local paths = require("core.paths")

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

--- Fuse a ZIP archive with the runtime to create an executable
function M.fuse(zip_data, output_path)
    local runtime_path = M.get_runtime_path()
    if not runtime_path then
        return false, "Cannot find lunert runtime. Build it with: make -C runtime"
    end

    -- Read runtime binary
    local runtime_data = fs.read_file(runtime_path)
    if not runtime_data then
        return false, "Cannot read runtime: " .. runtime_path
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
