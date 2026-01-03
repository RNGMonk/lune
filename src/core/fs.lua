-- Lune filesystem utilities
-- Uses LuaJIT FFI for operations without requiring lfs

local ffi = require("ffi")
local M = {}

-- Detect platform
local is_macos = (ffi.os == "OSX")

-- FFI declarations for POSIX filesystem operations
-- Note: struct dirent layout differs between macOS and Linux
if is_macos then
    ffi.cdef[[
        typedef unsigned int mode_t;
        typedef struct DIR DIR;
        struct dirent {
            unsigned long long d_ino;
            unsigned long long d_seekoff;
            unsigned short d_reclen;
            unsigned short d_namlen;
            unsigned char  d_type;
            char           d_name[1024];
        };
        DIR *opendir(const char *name);
        struct dirent *readdir(DIR *dirp);
        int closedir(DIR *dirp);
        int mkdir(const char *path, mode_t mode);
        int access(const char *path, int mode);
        char *getcwd(char *buf, size_t size);
        int unlink(const char *path);
        int rmdir(const char *path);
        int rename(const char *oldpath, const char *newpath);
        char *realpath(const char *path, char *resolved_path);
    ]]
else
    -- Linux struct dirent
    ffi.cdef[[
        typedef unsigned int mode_t;
        typedef struct DIR DIR;
        struct dirent {
            unsigned long  d_ino;
            unsigned long  d_off;
            unsigned short d_reclen;
            unsigned char  d_type;
            char           d_name[256];
        };
        DIR *opendir(const char *name);
        struct dirent *readdir(DIR *dirp);
        int closedir(DIR *dirp);
        int mkdir(const char *path, mode_t mode);
        int access(const char *path, int mode);
        char *getcwd(char *buf, size_t size);
        int unlink(const char *path);
        int rmdir(const char *path);
        int rename(const char *oldpath, const char *newpath);
        char *realpath(const char *path, char *resolved_path);
    ]]
end

local C = ffi.C

-- dirent d_type constants
local DT_DIR = 4   -- directory
local DT_REG = 8   -- regular file
local DT_LNK = 10  -- symbolic link

local F_OK = 0  -- existence
local R_OK = 4  -- read permission
local W_OK = 2  -- write permission
local X_OK = 1  -- execute permission

--- Check if a path exists
function M.exists(path)
    return C.access(path, F_OK) == 0
end

-- Helper to get file type via directory listing
local function get_file_type(path)
    -- Get parent directory and filename
    local parent = path:match("^(.*/)[^/]+/?$") or "./"
    local name = path:match("([^/]+)/?$")
    if not name then return nil end

    -- Remove trailing slash from name
    name = name:gsub("/$", "")

    local dir = C.opendir(parent)
    if dir == nil then return nil end

    local file_type = nil
    while true do
        local entry = C.readdir(dir)
        if entry == nil then break end
        local entry_name = ffi.string(entry.d_name)
        if entry_name == name then
            file_type = entry.d_type
            break
        end
    end
    C.closedir(dir)

    return file_type
end

--- Check if path is a directory
function M.is_dir(path)
    if not M.exists(path) then return false end
    local dtype = get_file_type(path)
    return dtype == DT_DIR
end

--- Check if path is a regular file
function M.is_file(path)
    if not M.exists(path) then return false end
    local dtype = get_file_type(path)
    return dtype == DT_REG
end

--- Get file size (uses Lua io)
function M.size(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local size = f:seek("end")
    f:close()
    return size
end

--- Create a directory
function M.mkdir(path, mode)
    mode = mode or tonumber("755", 8)
    return C.mkdir(path, mode) == 0
end

--- Create directory and all parent directories
function M.mkdir_p(path)
    -- Handle absolute vs relative paths
    local is_absolute = path:sub(1, 1) == "/"
    local parts = {}

    for part in path:gmatch("[^/]+") do
        table.insert(parts, part)
    end

    local current = is_absolute and "/" or ""

    for _, part in ipairs(parts) do
        if current == "" or current == "/" then
            current = current .. part
        else
            current = current .. "/" .. part
        end

        if not M.exists(current) then
            if not M.mkdir(current) then
                return false, "Failed to create directory: " .. current
            end
        elseif not M.is_dir(current) then
            return false, "Path exists but is not a directory: " .. current
        end
    end

    return true
end

--- Read entire file contents
function M.read_file(path)
    local f = io.open(path, "rb")
    if not f then
        return nil, "Cannot open file: " .. path
    end
    local content = f:read("*a")
    f:close()
    return content
end

--- Write content to file
function M.write_file(path, content)
    local f = io.open(path, "wb")
    if not f then
        return false, "Cannot open file for writing: " .. path
    end
    f:write(content)
    f:close()
    return true
end

--- Append content to file
function M.append_file(path, content)
    local f = io.open(path, "ab")
    if not f then
        return false, "Cannot open file for appending: " .. path
    end
    f:write(content)
    f:close()
    return true
end

--- Get current working directory
function M.cwd()
    local buf = ffi.new("char[4096]")
    if C.getcwd(buf, 4096) == nil then
        return nil
    end
    return ffi.string(buf)
end

--- Get absolute path
function M.realpath(path)
    local buf = ffi.new("char[4096]")
    local result = C.realpath(path, buf)
    if result == nil then
        return nil
    end
    return ffi.string(buf)
end

--- List directory contents
function M.listdir(path)
    local entries = {}
    local dir = C.opendir(path)
    if dir == nil then
        return nil, "Cannot open directory: " .. path
    end

    while true do
        local entry = C.readdir(dir)
        if entry == nil then
            break
        end
        local name = ffi.string(entry.d_name)
        if name ~= "." and name ~= ".." then
            table.insert(entries, name)
        end
    end

    C.closedir(dir)
    return entries
end

--- Delete a file
function M.unlink(path)
    return C.unlink(path) == 0
end

--- Delete an empty directory
function M.rmdir(path)
    return C.rmdir(path) == 0
end

--- Delete file or directory (non-recursive)
function M.remove(path)
    if M.is_dir(path) then
        return M.rmdir(path)
    else
        return M.unlink(path)
    end
end

--- Rename/move a file
function M.rename(oldpath, newpath)
    return C.rename(oldpath, newpath) == 0
end

--- Copy a file
function M.copy_file(src, dst)
    local content, err = M.read_file(src)
    if not content then
        return false, err
    end
    return M.write_file(dst, content)
end

--- Recursively delete a directory and its contents
function M.rmdir_r(path)
    if not M.is_dir(path) then
        return M.unlink(path)
    end

    local entries = M.listdir(path)
    if entries then
        for _, entry in ipairs(entries) do
            local full_path = path .. "/" .. entry
            if M.is_dir(full_path) then
                M.rmdir_r(full_path)
            else
                M.unlink(full_path)
            end
        end
    end

    return M.rmdir(path)
end

--- Walk directory tree (returns iterator)
function M.walk(path)
    local function walk_impl(dir, results)
        local entries = M.listdir(dir)
        if not entries then return end

        local files = {}
        local dirs = {}

        for _, entry in ipairs(entries) do
            local full_path = dir .. "/" .. entry
            if M.is_dir(full_path) then
                table.insert(dirs, entry)
            else
                table.insert(files, entry)
            end
        end

        table.insert(results, {dir, dirs, files})

        for _, subdir in ipairs(dirs) do
            walk_impl(dir .. "/" .. subdir, results)
        end
    end

    local results = {}
    walk_impl(path, results)

    local i = 0
    return function()
        i = i + 1
        if results[i] then
            return results[i][1], results[i][2], results[i][3]
        end
    end
end

return M
