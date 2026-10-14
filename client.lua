-- ===================================================================
-- HETIA MENU - Client-Side Logic (NUI Controller)
-- ===================================================================

local isMenuOpen = false
local isResourceReady = false

RegisterNetEvent('hetia:resourceStarted', function()
    isResourceReady = true
    print("^2[Hetia] NUI resource is ready. Press F5 to open the menu.^7")
end)

Citizen.CreateThread(function()
    Citizen.Wait(2000)
    TriggerServerEvent('hetia:requestResourceStart')
end)

RegisterCommand('hetia', function()
    if not isResourceReady then
        print("^1[Hetia] Menu is still loading. Please wait...^7")
        return
    end

    isMenuOpen = not isMenuOpen
    SetNuiFocus(isMenuOpen, isMenuOpen)
    SendNUIMessage({
        action = 'toggle',
        show = isMenuOpen
    })
end, false)

RegisterKeyMapping('hetia', 'Open Hetia Menu', 'keyboard', 'F5')

RegisterNUICallback('hetiaAction', function(data, cb)
    local action = data.action
    local value = data.value

    if action == 'godmode' then
        SetEntityInvincible(PlayerPedId(), value)
        SetPlayerInvincible(PlayerId(), value)
    elseif action == 'spawnVehicle' then
        SpawnVehicle(value)
    elseif action == 'spawnWeapon' then
        SpawnWeapon(value)
    elseif action == 'heal' then
        SetEntityHealth(PlayerPedId(), 200)
    elseif action == 'armor' then
        SetPedArmour(PlayerPedId(), 100)
    elseif action == 'close' then
        isMenuOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'toggle', show = false })
    end

    cb('ok')
end)

function SpawnVehicle(model)
    local modelHash = GetHashKey(model)
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end
    if not HasModelLoaded(modelHash) then
        print("^1[Hetia] Failed to load vehicle model: " .. model .. "^7")
        return
    end

    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    local vehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading, true, false)

    if DoesEntityExist(vehicle) then
        SetPedIntoVehicle(playerPed, vehicle, -1)
        SetVehicleOnGroundProperly(vehicle)
        SetModelAsNoLongerNeeded(modelHash)
        print("^2[Hetia] Spawned vehicle: " .. model .. "^7")
    else
        print("^1[Hetia] Failed to create vehicle: " .. model .. "^7")
    end
end

function SpawnWeapon(weaponName)
    local weaponHash = GetHashKey(weaponName)
    GiveWeaponToPed(PlayerPedId(), weaponHash, 9999, false, true)
    SetCurrentPedWeapon(PlayerPedId(), weaponHash, true)
    print("^2[Hetia] Given weapon: " .. weaponName .. "^7")
end