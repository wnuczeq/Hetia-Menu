-- ===================================================================
--  HETIA MENU  ·  loader
--  Tries every HTTP entry point the executor might expose, then runs
--  the native menu. If none exist, it says so plainly instead of
--  failing with a cryptic error.
--
--  Keyser has NO http function -- verified by probe.lua. On that
--  executor, paste hetia_menu.lua directly; this loader is for other
--  runtimes (a real FiveM client with the httprequest export, etc).
-- ===================================================================

local MENU_URL = "https://raw.githubusercontent.com/wnuczeq/Hetia-Menu/main/hetia_menu.lua"

local G = _G

-- every candidate normalises to: fn(url, callback(ok, body, code))
local candidates = {}

-- FiveM canonical
if type(G.PerformHttpRequest) == 'function' then
    candidates[#candidates + 1] = {
        name = 'PerformHttpRequest',
        fn = function(url, cb)
            PerformHttpRequest(url, function(code, body)
                cb(code == 200, body, code)
            end, 'GET', '', {})
        end,
    }
end

-- httprequest-client export
if type(G.exports) == 'table' then
    local ok, export = pcall(function() return exports['httprequest-client'] end)
    if ok and export and type(export.PerformHttpRequest) == 'function' then
        candidates[#candidates + 1] = {
            name = 'exports[httprequest-client]',
            fn = function(url, cb)
                export:PerformHttpRequest(url, function(code, body)
                    cb(code == 200, body, code)
                end, 'GET', '', {})
            end,
        }
    end
end

-- simple blocking getters: function(url) -> body
for _, name in ipairs({ 'httpGet', 'HttpGet', 'http_request', 'fetch' }) do
    if type(G[name]) == 'function' then
        candidates[#candidates + 1] = {
            name = name,
            fn = function(url, cb)
                local ok, body = pcall(G[name], url)
                cb(ok and type(body) == 'string' and #body > 0, body,
                    ok and 200 or 'call failed')
            end,
        }
    end
end

print('^3[HETIA] loader: probing HTTP entry points...^7')
for _, c in ipairs(candidates) do
    print('^2[HETIA]   found: ' .. c.name .. '^7')
end

if #candidates == 0 then
    print('^1=====================================================^7')
    print('^1[HETIA] No HTTP function in this executor.^7')
    print('^1[HETIA] The menu cannot be downloaded. Instead:^7')
    print('^1[HETIA]   1. open hetia_menu.lua from the repo^7')
    print('^1[HETIA]   2. paste its full contents into the executor^7')
    print('^1[HETIA]   3. it opens automatically; F5 or /hetia toggles^7')
    print('^1=====================================================^7')
    return
end

local idx = 0

local function tryNext()
    idx = idx + 1
    local c = candidates[idx]
    if not c then
        print('^1[HETIA] every HTTP entry point failed -- paste hetia_menu.lua directly.^7')
        return
    end

    print('^3[HETIA] trying ' .. c.name .. ' ...^7')
    local finished = false

    local function done(ok, body, code)
        if finished then return end
        finished = true

        if not ok or type(body) ~= 'string' or #body == 0 then
            print('^1[HETIA] ' .. c.name .. ' failed (HTTP ' .. tostring(code) .. ')^7')
            tryNext()
            return
        end

        print('^2[HETIA] downloaded via ' .. c.name .. ' (' .. #body .. ' bytes)^7')

        local chunk, err
        if type(load) == 'function' then
            chunk, err = load(body, 'hetia_menu')
        elseif type(loadstring) == 'function' then
            chunk, err = loadstring(body)
        end

        if not chunk then
            print('^1[HETIA] compile failed: ' .. tostring(err) .. '^7')
            return
        end

        local ok2, err2 = pcall(chunk)
        if ok2 then
            print('^2[HETIA] menu running.^7')
        else
            print('^1[HETIA] runtime error: ' .. tostring(err2) .. '^7')
        end
    end

    c.fn(MENU_URL, done)

    -- watchdog: a blocking getter may never call back
    if type(G.Citizen) == 'table' then
        Citizen.CreateThread(function()
            Citizen.Wait(8000)
            if not finished then
                finished = true
                print('^1[HETIA] ' .. c.name .. ' timed out^7')
                tryNext()
            end
        end)
    end
end

tryNext()