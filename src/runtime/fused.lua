-- Lune fused executable detection and loading
-- Handles running from compiled standalone binaries

local M = {}

local ffi = require("ffi")

-- ZIP end-of-central-directory signature
local EOCD_SIGNATURE = "PK\x05\x06"
local EOCD_SIZE = 22  -- Minimum EOCD size
local MAX_COMMENT_SIZE = 65535

--- Get the path to the current executable
function M.get_executable_path()
    -- Check if we already have it from lunert
    if _G._LUNERT_EXE_PATH then
        return _G._LUNERT_EXE_PATH
    end

    -- Try to detect on macOS
    if ffi.os == "OSX" then
        ffi.cdef[[
            int _NSGetExecutablePath(char *buf, uint32_t *bufsize);
        ]]
        local buf = ffi.new("char[4096]")
        local size = ffi.new("uint32_t[1]", 4096)
        if ffi.C._NSGetExecutablePath(buf, size) == 0 then
            return ffi.string(buf)
        end
    else
        -- Linux: read /proc/self/exe symlink
        local f = io.open("/proc/self/exe", "r")
        if f then
            f:close()
            -- Use realpath to resolve the symlink
            ffi.cdef[[
                char *realpath(const char *path, char *resolved_path);
            ]]
            local buf = ffi.new("char[4096]")
            local result = ffi.C.realpath("/proc/self/exe", buf)
            if result ~= nil then
                return ffi.string(buf)
            end
        end
    end

    return nil
end

--- Check if the current executable is a fused binary
function M.is_fused()
    -- Check flag set by lunert
    if _G._LUNERT_IS_FUSED ~= nil then
        return _G._LUNERT_IS_FUSED
    end

    local exe_path = M.get_executable_path()
    if not exe_path then
        return false
    end

    local f = io.open(exe_path, "rb")
    if not f then
        return false
    end

    -- Seek to potential EOCD location
    local file_size = f:seek("end")
    local search_start = math.max(0, file_size - EOCD_SIZE - MAX_COMMENT_SIZE)
    f:seek("set", search_start)

    local tail = f:read("*a")
    f:close()

    -- Search backwards for EOCD signature
    for i = #tail - EOCD_SIZE + 1, 1, -1 do
        if tail:sub(i, i + 3) == EOCD_SIGNATURE then
            return true
        end
    end

    return false
end

--- Read the embedded ZIP content from the executable
function M.read_zip_content()
    local exe_path = M.get_executable_path()
    if not exe_path then
        return nil, "Cannot determine executable path"
    end

    local f = io.open(exe_path, "rb")
    if not f then
        return nil, "Cannot open executable"
    end

    local content = f:read("*a")
    f:close()

    return content
end

--- Find the start of the ZIP archive within the executable
function M.find_zip_start(content)
    -- Search for first PK signature (local file header)
    local pk_sig = "PK\x03\x04"
    local start = content:find(pk_sig, 1, true)
    return start
end

return M
