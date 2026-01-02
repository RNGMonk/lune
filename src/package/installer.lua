-- Lune package installer
-- Main interface for installing packages from luarocks

local M = {}

local fs = require("core.fs")
local paths = require("core.paths")
local http = require("package.http")
local registry = require("package.registry")
local rockspec = require("package.rockspec")
local archive = require("package.archive")
local builder = require("package.builder")

-- Track installed packages to avoid circular dependencies
local installing = {}
local installed_cache = {}

--- Get the installation directory
function M.get_install_dir()
    return paths.get_lua_deps()
end

--- Check if a package is already installed
function M.is_installed(package_name, version)
    local install_dir = M.get_install_dir()
    local manifest_path = paths.join(install_dir, "lib/luarocks/rocks-5.1", package_name)

    if not fs.exists(manifest_path) then
        return false
    end

    if version then
        return fs.exists(paths.join(manifest_path, version))
    end

    return true
end

--- Record that a package was installed
function M.record_install(spec, install_dir)
    local rocks_dir = paths.join(install_dir, "lib/luarocks/rocks-5.1", spec.package, spec.version)
    fs.mkdir_p(rocks_dir)

    -- Write a simple manifest
    local manifest = string.format([[
package = %q
version = %q
installed_on = %q
]], spec.package, spec.version, os.date("%Y-%m-%d %H:%M:%S"))

    fs.write_file(paths.join(rocks_dir, "rock_manifest"), manifest)
end

--- Install a package
function M.install(package_name, version, options)
    options = options or {}

    -- Check for circular dependencies
    if installing[package_name] then
        return true  -- Already being installed
    end

    -- Check if already installed
    if M.is_installed(package_name, version) and not options.force then
        if not options.quiet then
            print("  " .. package_name .. " already installed")
        end
        return true
    end

    installing[package_name] = true

    local install_dir = M.get_install_dir()
    local temp_dir = paths.join(install_dir, ".tmp")

    -- Get version if not specified
    if not version then
        local latest, err = registry.get_latest_version(package_name)
        if not latest then
            installing[package_name] = nil
            return false, "Could not find package: " .. package_name .. " - " .. tostring(err)
        end
        version = latest
    end

    if not options.quiet then
        print("Installing " .. package_name .. "@" .. version .. "...")
    end

    -- Fetch rockspec
    local spec, err = registry.fetch_rockspec(package_name, version)
    if not spec then
        installing[package_name] = nil
        return false, "Could not fetch rockspec: " .. tostring(err)
    end

    -- Install dependencies first
    local deps = rockspec.filter_dependencies(spec.dependencies)
    for _, dep in ipairs(deps) do
        if not options.quiet then
            print("  Dependency: " .. dep.name)
        end
        local ok, dep_err = M.install(dep.name, nil, {quiet = true})
        if not ok then
            installing[package_name] = nil
            return false, "Failed to install dependency " .. dep.name .. ": " .. tostring(dep_err)
        end
    end

    -- Download and extract source
    local source_dir, download_err = M.download_source(spec, temp_dir)
    if not source_dir then
        installing[package_name] = nil
        return false, "Failed to download source: " .. tostring(download_err)
    end

    -- Build and install
    local build_ok, build_err = builder.build(spec, source_dir, install_dir)
    if not build_ok then
        -- Clean up
        fs.rmdir_r(temp_dir)
        installing[package_name] = nil
        return false, "Build failed: " .. tostring(build_err)
    end

    -- Record installation
    M.record_install(spec, install_dir)

    -- Clean up temp directory
    fs.rmdir_r(temp_dir)

    installing[package_name] = nil

    if not options.quiet then
        print("  Installed " .. package_name .. "@" .. version)
    end

    return true
end

--- Download and extract package source
function M.download_source(spec, temp_dir)
    fs.mkdir_p(temp_dir)

    local source = spec.source
    if not source or not source.url then
        return nil, "No source URL in rockspec"
    end

    local url = source.url

    -- Handle git URLs
    if url:match("^git://") or url:match("^git%+") or url:match("%.git$") then
        return M.clone_git(url, source.tag or source.branch, temp_dir)
    end

    -- Handle file URLs (http/https)
    local filename = url:match("([^/]+)$") or "source"
    local download_path = paths.join(temp_dir, filename)

    local ok, err = http.download(url, download_path)
    if not ok then
        return nil, "Download failed: " .. tostring(err)
    end

    -- Extract archive
    local extract_dir = paths.join(temp_dir, "extracted")
    ok, err = archive.extract(download_path, extract_dir)
    if not ok then
        return nil, "Extraction failed: " .. tostring(err)
    end

    -- Determine the source directory
    local source_dir
    if source.dir then
        -- If dir is specified in rockspec, use it directly from extract_dir
        source_dir = paths.join(extract_dir, source.dir)
    else
        -- Otherwise find the root directory in the archive
        source_dir = archive.find_root(extract_dir)
    end

    return source_dir
end

--- Clone a git repository
function M.clone_git(url, ref, temp_dir)
    -- Clean up git URL
    url = url:gsub("^git%+", "")
    url = url:gsub("^git://", "https://")

    local clone_dir = paths.join(temp_dir, "repo")

    local cmd
    if ref then
        cmd = string.format(
            "git clone --depth 1 --branch %q %q %q 2>&1",
            ref, url, clone_dir
        )
    else
        cmd = string.format(
            "git clone --depth 1 %q %q 2>&1",
            url, clone_dir
        )
    end

    local handle = io.popen(cmd)
    local output = handle:read("*a")
    local success = handle:close()

    if not success then
        return nil, "git clone failed: " .. output
    end

    return clone_dir
end

--- List installed packages
function M.list()
    local install_dir = M.get_install_dir()
    local rocks_dir = paths.join(install_dir, "lib/luarocks/rocks-5.1")

    if not fs.exists(rocks_dir) then
        return {}
    end

    local packages = {}
    local pkg_dirs = fs.listdir(rocks_dir)

    if pkg_dirs then
        for _, pkg in ipairs(pkg_dirs) do
            local pkg_path = paths.join(rocks_dir, pkg)
            if fs.is_dir(pkg_path) then
                local versions = fs.listdir(pkg_path)
                if versions and #versions > 0 then
                    packages[pkg] = versions[1]  -- First version found
                end
            end
        end
    end

    return packages
end

return M
