-- Lune archive handling
-- Extracts tar.gz and zip archives

local M = {}

local fs = require("core.fs")
local paths = require("core.paths")

--- Extract a tar.gz archive using system tar
function M.extract_targz(archive_path, dest_dir)
    fs.mkdir_p(dest_dir)

    local cmd = string.format(
        "tar -xzf %q -C %q 2>&1",
        archive_path,
        dest_dir
    )

    local handle = io.popen(cmd)
    local output = handle:read("*a")
    local success = handle:close()

    if not success then
        return false, "tar extraction failed: " .. output
    end

    return true
end

--- Extract a zip archive using system unzip
function M.extract_zip(archive_path, dest_dir)
    fs.mkdir_p(dest_dir)

    local cmd = string.format(
        "unzip -q -o %q -d %q 2>&1",
        archive_path,
        dest_dir
    )

    local handle = io.popen(cmd)
    local output = handle:read("*a")
    local success = handle:close()

    if not success then
        return false, "unzip extraction failed: " .. output
    end

    return true
end

--- Extract archive based on file extension
function M.extract(archive_path, dest_dir)
    if archive_path:match("%.tar%.gz$") or archive_path:match("%.tgz$") then
        return M.extract_targz(archive_path, dest_dir)
    elseif archive_path:match("%.zip$") then
        return M.extract_zip(archive_path, dest_dir)
    else
        return false, "Unknown archive format: " .. archive_path
    end
end

--- Find the root directory inside an extracted archive
-- Many archives have a single top-level directory
function M.find_root(extracted_dir)
    local entries = fs.listdir(extracted_dir)
    if not entries then
        return extracted_dir
    end

    -- If there's exactly one directory, that's likely the root
    if #entries == 1 then
        local entry_path = paths.join(extracted_dir, entries[1])
        if fs.is_dir(entry_path) then
            return entry_path
        end
    end

    return extracted_dir
end

return M
