-- Lune package registry client
-- Interfaces with luarocks.org to find and download packages

local M = {}

local http = require("package.http")
local rockspec = require("package.rockspec")

-- Default registry URL
M.registry_url = "https://luarocks.org"

--- Search for a package using the luarocks.org API
function M.search(package_name)
    -- Use the JSON API to search for packages
    local url = M.registry_url .. "/search?q=" .. package_name
    local body, err = http.get(url)
    if not body then
        return nil, "Search failed: " .. tostring(err)
    end

    -- Very simple parsing - look for version patterns in the page
    -- The actual page lists versions in the format: package-version
    local versions = {}
    for version in body:gmatch(package_name .. "%-([%d%.%-]+)") do
        -- Clean up version (remove trailing dashes, etc)
        version = version:gsub("%-$", "")
        if version:match("^%d") then
            versions[version] = true
        end
    end

    local result = {}
    for v, _ in pairs(versions) do
        table.insert(result, v)
    end

    -- Sort versions (newest first based on version numbers)
    table.sort(result, function(a, b)
        return a > b
    end)

    return result
end

--- Get the latest version of a package by trying common version patterns
function M.get_latest_version(package_name)
    -- Try to find the package - need to search first since we don't know the uploader
    local search_url = M.registry_url .. "/search?q=" .. package_name
    local search_body, err = http.get(search_url)

    if not search_body then
        return nil, "Search failed: " .. tostring(err)
    end

    -- Find the module page URL from search results
    -- Pattern: /modules/uploader/package_name
    local uploader = search_body:match('/modules/([^/"]+)/' .. package_name .. '["/]')
    if not uploader then
        return nil, "Package not found: " .. package_name
    end

    -- Now get the actual module page
    local url = M.registry_url .. "/modules/" .. uploader .. "/" .. package_name
    local body = http.get(url)

    if body then
        -- Look for version links in the page
        -- Format: <a href="/modules/uploader/package/version">version</a>
        local versions = {}

        -- Match version patterns like "0.7.1-1" from href links
        for version in body:gmatch('/' .. package_name .. '/([%d%.]+%-?%d*)"') do
            -- Skip development versions
            if not version:match("^scm") and not version:match("^dev") then
                versions[version] = true
            end
        end

        -- Convert to array and sort
        local sorted = {}
        for v, _ in pairs(versions) do
            table.insert(sorted, v)
        end

        table.sort(sorted, function(a, b)
            -- Compare version strings
            local function parse_version(v)
                local parts = {}
                for p in v:gmatch("([%d]+)") do
                    table.insert(parts, tonumber(p))
                end
                return parts
            end

            local pa, pb = parse_version(a), parse_version(b)
            for i = 1, math.max(#pa, #pb) do
                local na, nb = pa[i] or 0, pb[i] or 0
                if na ~= nb then
                    return na > nb
                end
            end
            return false
        end)

        if #sorted > 0 then
            -- Store uploader for later use
            M._package_uploaders = M._package_uploaders or {}
            M._package_uploaders[package_name] = uploader
            return sorted[1]
        end
    end

    return nil, "Could not find versions for: " .. package_name
end

--- Fetch a rockspec for a specific package version
function M.fetch_rockspec(package_name, version)
    -- Get uploader if we know it
    local uploader = (M._package_uploaders or {})[package_name]

    -- Build list of URLs to try
    local urls = {}

    if uploader then
        -- Try uploader-specific manifests first
        table.insert(urls, string.format("%s/manifests/%s/%s-%s.rockspec",
            M.registry_url, uploader, package_name, version))
    end

    -- Also try package name as manifest (some packages use this)
    table.insert(urls, string.format("%s/manifests/%s/%s-%s.rockspec",
        M.registry_url, package_name, package_name, version))

    for _, url in ipairs(urls) do
        local body, code = http.get(url)
        if body and code and code < 400 then
            local spec, parse_err = rockspec.parse(body)
            if spec then
                spec._source_url = url
                spec._uploader = uploader
                return spec
            end
        end
    end

    return nil, "Could not fetch rockspec for " .. package_name .. "-" .. version
end

return M
