-- ===================================================================
-- HETIA MENU - Server-Side Dynamic Resource Creator
-- ===================================================================

local resourceName = "hetia_nui_temp"
local repoUrl = "https://raw.githubusercontent.com/wnuczeq/Hetia-Menu/main/"

local function downloadAndSave(filePath, url, callback)
    PerformHttpRequest(url, function(err, text, headers)
        if err == 200 then
            SaveResourceFile(resourceName, filePath, text, -1)
            print("^2[Hetia] Downloaded: " .. filePath .. "^7")
        else
            print("^1[Hetia] Failed to download: " .. filePath .. " (HTTP " .. tostring(err) .. ")^7")
        end
        if callback then callback() end
    end, "GET", "", {})
end

local function createAndStartResource()
    print("^3[Hetia] Creating temporary NUI resource...^7")

    if GetResourceState(resourceName) ~= 'missing' then
        StopResource(resourceName)
    end

    local filesToDownload = {
        { path = "fxmanifest.lua", url = repoUrl .. "fxmanifest.lua" },
        { path = "html/index.html", url = repoUrl .. "html/index.html" },
        { path = "html/style.css", url = repoUrl .. "html/style.css" },
        { path = "html/script.js", url = repoUrl .. "html/script.js" }
    }

    local downloadsDone = 0
    local totalDownloads = #filesToDownload

    for _, file in ipairs(filesToDownload) do
        downloadAndSave(file.path, file.url, function()
            downloadsDone = downloadsDone + 1
            if downloadsDone == totalDownloads then
                print("^3[Hetia] All files downloaded. Starting resource...^7")
                StartResource(resourceName)
                Citizen.Wait(500)
                TriggerClientEvent('hetia:resourceStarted', -1)
            end
        end)
    end
end

RegisterNetEvent('hetia:requestResourceStart', function()
    createAndStartResource()
end)

AddEventHandler('onResourceStart', function(resName)
    if resName == GetCurrentResourceName() then
        print("^2[Hetia] Server-side resource creator is ready.^7")
    end
end)