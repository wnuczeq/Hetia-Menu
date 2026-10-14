-- ===================================================================
-- HETIA MENU - Executor API probe
-- Run this FIRST in Keyser and send the output back.
-- It only reads globals. It changes nothing, downloads nothing.
-- ===================================================================

local candidates = {
    -- http / download
    "PerformHttpRequest", "HttpRequest", "httpGet", "httpget", "http_request",
    "fetch", "eachFrame", "HttpGet", "Async",
    -- loaders
    "load", "loadstring", "loadString", "runString", "RunString",
    -- roblox-style (expect missing outside Roblox)
    "game", "workspace", "Instance",
    -- fiveM runtime
    "Citizen", "TriggerServerEvent", "TriggerEvent", "RegisterNetEvent",
    "SetNuiFocus", "SendNUIMessage", "RegisterNUICallback", "RegisterKeyMapping",
    "RegisterCommand", "GetCurrentResourceName",
    -- native / ped
    "PlayerPedId", "PlayerId", "SetEntityInvincible", "SetPlayerInvincible",
    "GiveWeaponToPed", "CreateVehicle", "RequestModel", "GetHashKey",
    -- render / overlay
    "imgui", "ImGui", "ImGUI", "drawText", "DrawText", "drawRect", "DrawRect",
    "drawLine", "DrawLine", "renderText", "ui", "menu", "GUI",
    -- executor root tables
    "keyser", "Keyser", "cheat", "Cheat", "client", "utility", "Utils",
}

print("========== HETIA PROBE ==========")
print(string.format("%-24s %s", "NAME", "TYPE"))
for _, name in ipairs(candidates) do
    print(string.format("%-24s %s", name, type(_G[name])))
end
print("========== END PROBE ==========")