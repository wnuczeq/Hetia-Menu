-- ===================================================================
-- HETIA MENU - Loader for Keyser/Executor
-- ===================================================================
local githubUrl = "https://raw.githubusercontent.com/wnuczeq/Hetia-Menu/main/client.lua"

PerformHttpRequest(githubUrl, function(err, text, headers)
    if err == 200 then
        local success, errorMsg = pcall(function()
            local script = load(text)
            if script then
                script()
            else
                print("^1[Hetia] Failed to compile script.^7")
            end
        end)
        if success then
            print("^2[Hetia] Client script loaded successfully.^7")
        else
            print("^1[Hetia] Error: " .. tostring(errorMsg) .. "^7")
        end
    else
        print("^1[Hetia] Failed to download script. HTTP: " .. tostring(err) .. "^7")
    end
end, "GET", "", {})