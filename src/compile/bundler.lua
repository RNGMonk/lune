-- Lune ZIP bundler
-- Creates ZIP archives containing Lua files for compilation

local M = {}

local fs = require("core.fs")
local paths = require("core.paths")

-- CRC32 lookup table
local crc_table = nil

local function init_crc_table()
    if crc_table then return end
    crc_table = {}
    for i = 0, 255 do
        local crc = i
        for _ = 1, 8 do
            if crc % 2 == 1 then
                crc = bit.bxor(bit.rshift(crc, 1), 0xEDB88320)
            else
                crc = bit.rshift(crc, 1)
            end
        end
        crc_table[i] = crc
    end
end

local function crc32(data)
    init_crc_table()
    local crc = 0xFFFFFFFF
    for i = 1, #data do
        local byte = data:byte(i)
        crc = bit.bxor(bit.rshift(crc, 8), crc_table[bit.band(bit.bxor(crc, byte), 0xFF)])
    end
    return bit.bxor(crc, 0xFFFFFFFF)
end

-- Write little-endian integers
local function write_u16(n)
    return string.char(n % 256, math.floor(n / 256) % 256)
end

local function write_u32(n)
    return string.char(
        n % 256,
        math.floor(n / 256) % 256,
        math.floor(n / 65536) % 256,
        math.floor(n / 16777216) % 256
    )
end

--- Create a ZIP file containing files
-- files is a table of {name = "path/in/zip", content = "file contents"}
function M.create_zip(files)
    local local_headers = {}
    local central_directory = {}
    local offset = 0

    for _, file in ipairs(files) do
        local name = file.name
        local content = file.content
        local crc = crc32(content)

        -- Local file header
        local header = table.concat({
            "PK\x03\x04",           -- Local file header signature
            write_u16(20),          -- Version needed (2.0)
            write_u16(0),           -- General purpose bit flag
            write_u16(0),           -- Compression method (store)
            write_u16(0),           -- File time
            write_u16(0),           -- File date
            write_u32(crc),         -- CRC-32
            write_u32(#content),    -- Compressed size
            write_u32(#content),    -- Uncompressed size
            write_u16(#name),       -- File name length
            write_u16(0),           -- Extra field length
            name,                   -- File name
            content,                -- File content
        })

        table.insert(local_headers, header)

        -- Central directory entry
        local cd_entry = table.concat({
            "PK\x01\x02",           -- Central directory signature
            write_u16(20),          -- Version made by
            write_u16(20),          -- Version needed
            write_u16(0),           -- General purpose bit flag
            write_u16(0),           -- Compression method
            write_u16(0),           -- File time
            write_u16(0),           -- File date
            write_u32(crc),         -- CRC-32
            write_u32(#content),    -- Compressed size
            write_u32(#content),    -- Uncompressed size
            write_u16(#name),       -- File name length
            write_u16(0),           -- Extra field length
            write_u16(0),           -- File comment length
            write_u16(0),           -- Disk number start
            write_u16(0),           -- Internal file attributes
            write_u32(0),           -- External file attributes
            write_u32(offset),      -- Relative offset of local header
            name,                   -- File name
        })

        table.insert(central_directory, cd_entry)
        offset = offset + #header
    end

    local local_data = table.concat(local_headers)
    local cd_data = table.concat(central_directory)
    local cd_offset = #local_data

    -- End of central directory
    local eocd = table.concat({
        "PK\x05\x06",               -- EOCD signature
        write_u16(0),               -- Disk number
        write_u16(0),               -- Disk with central directory
        write_u16(#files),          -- Number of entries on disk
        write_u16(#files),          -- Total number of entries
        write_u32(#cd_data),        -- Size of central directory
        write_u32(cd_offset),       -- Offset to central directory
        write_u16(0),               -- Comment length
    })

    return local_data .. cd_data .. eocd
end

--- Collect all Lua files from a directory
function M.collect_lua_files(dir, prefix)
    prefix = prefix or ""
    local files = {}

    for root, dirs, filenames in fs.walk(dir) do
        local rel_root = root:sub(#dir + 2)  -- Remove dir prefix
        if rel_root ~= "" then
            rel_root = rel_root .. "/"
        end

        for _, filename in ipairs(filenames) do
            if filename:match("%.lua$") then
                local full_path = paths.join(root, filename)
                local content = fs.read_file(full_path)
                if content then
                    table.insert(files, {
                        name = prefix .. rel_root .. filename,
                        content = content,
                    })
                end
            end
        end
    end

    return files
end

--- Collect native libraries (.so, .dylib) from lua_deps
function M.collect_native_libs(lua_deps_dir)
    local libs = {}
    local lib_dir = paths.join(lua_deps_dir, "lib/lua/5.1")

    if not fs.exists(lib_dir) then
        return libs
    end

    for root, dirs, filenames in fs.walk(lib_dir) do
        for _, filename in ipairs(filenames) do
            if filename:match("%.so$") or filename:match("%.dylib$") then
                local full_path = paths.join(root, filename)
                -- Get relative path from lib_dir
                local rel_path = full_path:sub(#lib_dir + 2)
                table.insert(libs, {
                    path = full_path,
                    name = rel_path,
                })
            end
        end
    end

    return libs
end

--- Bundle a Lua project into a ZIP
function M.bundle(entry_point, options)
    options = options or {}
    local files = {}

    -- Read entry point
    local main_content = fs.read_file(entry_point)
    if not main_content then
        return nil, "Cannot read entry point: " .. entry_point
    end

    -- Add entry point as main.lua
    table.insert(files, {
        name = "main.lua",
        content = main_content,
    })

    -- Collect local Lua files (if entry is in a directory with others)
    local entry_dir = paths.dirname(entry_point)
    if entry_dir ~= "." then
        local local_files = M.collect_lua_files(entry_dir)
        for _, f in ipairs(local_files) do
            -- Don't duplicate main.lua
            if f.name ~= paths.basename(entry_point) then
                table.insert(files, f)
            end
        end
    end

    -- Collect lua_deps if exists
    local lua_deps = paths.get_lua_deps()
    local share_dir = paths.join(lua_deps, "share/lua/5.1")

    if fs.exists(share_dir) then
        local dep_files = M.collect_lua_files(share_dir, "lua_deps/share/lua/5.1/")
        for _, f in ipairs(dep_files) do
            table.insert(files, f)
        end
    end

    -- Collect native libraries
    local native_libs = M.collect_native_libs(lua_deps)

    -- Create ZIP
    local zip_data = M.create_zip(files)
    return zip_data, native_libs
end

return M
