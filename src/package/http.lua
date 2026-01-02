-- Lune HTTP client
-- Uses curl as fallback since we can't rely on LuaSocket being installed

local M = {}

--- Perform HTTP GET request
-- Returns body, status_code or nil, error_message
function M.get(url)
    -- Try LuaSocket first if available
    local ok, http = pcall(require, "socket.http")
    if ok then
        local ltn12 = require("ltn12")
        local body = {}
        local result, code, headers = http.request{
            url = url,
            sink = ltn12.sink.table(body),
            redirect = true,
        }
        if result then
            return table.concat(body), code
        else
            return nil, code
        end
    end

    -- Fall back to curl
    local escaped_url = url:gsub("'", "'\\''")
    local handle = io.popen("curl -sL -w '\\n%{http_code}' '" .. escaped_url .. "' 2>/dev/null")
    if not handle then
        return nil, "Failed to execute curl"
    end

    local output = handle:read("*a")
    handle:close()

    -- Split body and status code
    local body, code = output:match("^(.-)%s*(%d+)%s*$")
    if not code then
        return nil, "Failed to parse curl response"
    end

    code = tonumber(code)
    if code >= 400 then
        return nil, "HTTP " .. code
    end

    return body, code
end

--- Download file to path
function M.download(url, path)
    local body, err = M.get(url)
    if not body then
        return false, err
    end

    local f = io.open(path, "wb")
    if not f then
        return false, "Cannot open file for writing: " .. path
    end

    f:write(body)
    f:close()
    return true
end

return M
