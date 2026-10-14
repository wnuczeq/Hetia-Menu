-- ===================================================================
--  HETIA MENU  ·  native overlay build
--  Target: FiveM client-side executors (Keyser and similar)
--  Draws with the game's own native primitives -- no NUI page, no
--  resource, no server, no HTTP. Paste the whole file, press F5.
-- ===================================================================

-- ---------------------------- THEME -------------------------------

local C = {
    bg        = { 12,  12,  15,  246 },
    border    = { 255, 255, 255, 22  },
    divider   = { 255, 255, 255, 16  },
    text      = { 224, 224, 224, 255 },
    textDim   = { 102, 102, 102, 255 },
    textHover = { 255, 255, 255, 255 },
    hover     = { 255, 255, 255, 20  },
    accent    = { 255, 255, 255, 255 },
    trackOff  = { 51,  51,  51,  255 },
    trackOn   = { 255, 255, 255, 255 },
    knobOff   = { 136, 136, 136, 255 },
    knobOn    = { 17,  17,  17,  255 },
    footer    = { 85,  85,  85,  255 },
}

-- geometry, in 1080p-relative pixels
local LAYOUT = {
    width      = 400,
    headerH    = 74,
    tabBarH    = 34,
    rowH       = 34,
    padY       = 8,
    footerH    = 28,
    labelInset = 16,
    toggleW    = 36,
    toggleH    = 20,
    logoScale  = 0.62,
    tabScale   = 0.30,
    rowScale   = 0.32,
    footScale  = 0.22,
    -- Mouse cursor speed. If the cursor crawls, raise this (0.005 / 0.01).
    -- If it flies off screen, lower it (0.0008). Keyboard nav works regardless.
    cursorSens = 0.0015,
}

-- Open the menu the moment the script runs. Set false if you only want F5.
local OPEN_ON_LOAD = true
local TOGGLE_VK   = 0x74   -- VK_F5, used only by the raw-key fallback

-- Capture the cursor through NUI focus while the menu is open. Falls back to
-- SetCursorLocation-only if the native is missing. Set false if the cursor
-- misbehaves or the game stays mouse-locked after closing.
local USE_NUI_FOCUS = true

-- FiveM controls: 172-177 are the frontend arrow/accept/cancel group,
-- 237/238 are the cursor accept/cancel used when a cursor is active.
local KEY = {
    up    = 172,  -- FRONTEND_UP      (arrow up)
    down  = 173,  -- FRONTEND_DOWN    (arrow down)
    left  = 174,  -- FRONTEND_LEFT    (arrow left)
    right = 175,  -- FRONTEND_RIGHT   (arrow right)
    enter = 176,  -- FRONTEND_ACCEPT  (enter)
    esc   = 177,  -- FRONTEND_CANCEL  (esc / backspace)
    click = 24,   -- ATTACK           (left mouse)
    click2 = 237, -- CURSOR_ACCEPT
    cancel2 = 238,-- CURSOR_CANCEL
    scrollUp = 241,
    scrollDown = 242,
}

-- ------------------------ CAPABILITY CHECK ------------------------

local NEEDED = {
    'DrawRect', 'DrawText', 'DrawLine',
    'SetTextFont', 'SetTextScale', 'SetTextColour', 'SetTextCentre',
    'SetTextOutline', 'BeginTextCommandDisplayText',
    'AddTextComponentSubstringPlayerName', 'EndTextCommandDisplayText',
    'SetCursorLocation', 'SetMouseCursorActiveThisFrame',
    'IsControlPressed', 'IsControlJustPressed', 'IsControlJustReleased',
    'GetDisabledControlNormal', 'IsDisabledControlJustPressed',
    'IsDisabledControlJustReleased', 'DisableAllControlActions',
    'GetActiveScreenResolution', 'GetGameplayCamRot', 'GetEntityCoords',
    'GetEntityHeading', 'SetEntityCoordsNoOffset', 'SetEntityCollision',
    'FreezeEntityPosition', 'SetEntityHealth', 'ClearPedBloodDamage',
    'SetPedArmour', 'GiveWeaponToPed', 'SetPedAmmo',
    'SetPedInfiniteAmmoClip', 'SetPedInfiniteAmmo', 'GetCurrentPedWeapon',
    'SetCurrentPedWeapon', 'SetSuperJumpThisFrame', 'GetVehiclePedIsIn',
    'SetVehicleFixed', 'SetVehicleDeformationFixed', 'SetVehicleUndriveable',
    'SetVehicleEngineHealth', 'SetVehicleBodyHealth', 'SetVehicleModKit',
    'GetNumVehicleMods', 'SetVehicleMod', 'ToggleVehicleMod',
    'SetVehicleTyresCanBurst', 'SetVehicleWindowTint', 'DeleteEntity',
    'SetEntityAsMissionEntity', 'GetFirstBlipInfoId', 'DoesBlipExist',
    'GetBlipInfoIdCoord', 'GetGroundZFor_3dCoord', 'RequestCollisionAtCoord',
    'HasModelLoaded', 'SetModelAsNoLongerNeeded', 'SetPedIntoVehicle',
    'SetVehicleOnGroundProperly', 'SetVehicleEngineOn', 'SetPlayerMaxArmour',
}

local G = _G
local missing, missingSet = {}, {}
for _, name in ipairs(NEEDED) do
    if type(G[name]) ~= 'function' then
        missing[#missing + 1] = name
        missingSet[name] = true
    end
end

local HAS_TEXT_CHAIN = not (missingSet['BeginTextCommandDisplayText']
    or missingSet['AddTextComponentSubstringPlayerName']
    or missingSet['EndTextCommandDisplayText'])

print('^3[HETIA] capability check: ' .. (#NEEDED - #missing) .. '/' .. #NEEDED .. ' natives present^7')
if #missing > 0 then
    local shown = {}
    for i = 1, math.min(#missing, 20) do shown[i] = missing[i] end
    print('^1[HETIA] missing: ' .. table.concat(shown, ', ')
        .. (#missing > 20 and (' (+' .. (#missing - 20) .. ' more)') or '') .. '^7')
end
print('^2[HETIA] text path: ' .. (HAS_TEXT_CHAIN and 'native text chain OK'
    or 'DrawText fallback') .. '^7')

-- ---------------------------- STATE -------------------------------

local menuOpen   = false
local activeTab  = 1
local cursorX, cursorY = 0.5, 0.5
local screenW, screenH, scale = 1920, 1080, 1.0

local toggles = {
    godmode   = false,
    infammo   = false,
    noclip    = false,
    superjump = false,
}

-- ------------------------- MENU DEFINITION ------------------------

local TABS = {
    {
        name = 'Main',
        items = {
            { label = 'God Mode',       kind = 'toggle', key = 'godmode' },
            { label = 'Infinite Ammo',  kind = 'toggle', key = 'infammo' },
            { label = 'Heal Player',    kind = 'action', fn = 'heal' },
            { label = 'Give Armor',     kind = 'action', fn = 'armor' },
            { label = 'Repair Vehicle', kind = 'action', fn = 'repair' },
        },
    },
    {
        name = 'Weapons',
        items = {
            { label = 'Pistol',          kind = 'weapon', value = 'WEAPON_PISTOL' },
            { label = 'Carbine Rifle',   kind = 'weapon', value = 'WEAPON_CARBINERIFLE' },
            { label = 'Assault Shotgun', kind = 'weapon', value = 'WEAPON_ASSAULTSHOTGUN' },
            { label = 'RPG',             kind = 'weapon', value = 'WEAPON_RPG' },
            { label = 'Minigun',         kind = 'weapon', value = 'WEAPON_MINIGUN' },
            { label = 'Max Ammo',        kind = 'action', fn = 'maxammo' },
        },
    },
    {
        name = 'Vehicles',
        items = {
            { label = 'Adder',          kind = 'vehicle', value = 'adder' },
            { label = 'T20',            kind = 'vehicle', value = 't20' },
            { label = 'Zentorno',       kind = 'vehicle', value = 'zentorno' },
            { label = 'Oppressor Mk II', kind = 'vehicle', value = 'oppressor2' },
            { label = 'Max Mods',       kind = 'action', fn = 'maxmods' },
            { label = 'Delete Vehicle', kind = 'action', fn = 'deleteveh' },
        },
    },
    {
        name = 'Misc',
        items = {
            { label = 'Noclip',              kind = 'toggle', key = 'noclip' },
            { label = 'Super Jump',          kind = 'toggle', key = 'superjump' },
            { label = 'Teleport to Waypoint', kind = 'action', fn = 'tpwaypoint' },
            { label = 'Close Menu',          kind = 'action', fn = 'close' },
        },
    },
}

-- --------------------------- HELPERS ------------------------------

local function refreshResolution()
    local w, h = GetActiveScreenResolution()
    if not w or w == 0 or not h or h == 0 then w, h = 1920, 1080 end
    screenW, screenH = w, h
    scale = h / 1080.0
end

-- normalized x for a pixel value at 1080p baseline
local function nx(v) return v / screenW end
local function ny(v) return v / screenH end

-- pixel value from a normalized cursor coordinate
local function px(v) return v * screenW end
local function py(v) return v * screenH end

-- rect drawn from TOP-LEFT in 1080p pixels
local function rect(x, y, w, h, col)
    DrawRect(nx(x + w * 0.5), ny(y + h * 0.5), nx(w), ny(h),
        col[1], col[2], col[3], col[4])
end

local function textAt(str, x, y, s, col, align)
    local ts = s * scale
    local centre = (align == true) or (align == 'center')
    local right = (align == 'right')
    if HAS_TEXT_CHAIN then
        SetTextFont(0)
        SetTextScale(0.0, ts)
        SetTextColour(col[1], col[2], col[3], col[4])
        SetTextCentre(centre)
        if type(G.SetTextRightJustify) == 'function' then SetTextRightJustify(right) end
        if type(G.SetTextOutline) == 'function' then SetTextOutline() end
        BeginTextCommandDisplayText('STRING')
        AddTextComponentSubstringPlayerName(tostring(str))
        EndTextCommandDisplayText(nx(x), ny(y))
    elseif type(G.DrawText) == 'function' then
        G.DrawText(tostring(str), nx(x), ny(y), ts, col[1], col[2], col[3], col[4],
            centre and 2 or 0)
    end
end

-- ---- control helpers (guarded: executors vary on which exist) ----

local function ctrlPressed(ctrl)
    if type(G.IsControlPressed) == 'function' then
        return IsControlPressed(0, ctrl) and true or false
    end
    if type(G.GetDisabledControlNormal) == 'function' then
        return math.abs(GetDisabledControlNormal(0, ctrl)) > 0.1
    end
    return false
end

local function ctrlJustPressed(ctrl)
    if type(G.IsDisabledControlJustPressed) == 'function' then
        return IsDisabledControlJustPressed(0, ctrl) and true or false
    end
    if type(G.IsControlJustPressed) == 'function' then
        return IsControlJustPressed(0, ctrl) and true or false
    end
    return false
end

-- plain table vector math -- avoids depending on vector3 metamethods
local function v3(x, y, z) return { x = x or 0.0, y = y or 0.0, z = z or 0.0 } end
local function vadd(a, b) return v3(a.x + b.x, a.y + b.y, a.z + b.z) end
local function vsub(a, b) return v3(a.x - b.x, a.y - b.y, a.z - b.z) end
local function vmul(a, s) return v3(a.x * s, a.y * s, a.z * s) end

local function notify(msg)
    print('^3[HETIA] ' .. tostring(msg) .. '^7')
    if type(G.BeginTextCommandThefeedPost) == 'function'
        and type(G.AddTextComponentSubstringPlayerName) == 'function'
        and type(G.EndTextCommandThefeedPostTicker) == 'function' then
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(tostring(msg))
        EndTextCommandThefeedPostTicker(false, true)
    end
end

local function ped() return PlayerPedId() end

local function myVehicle()
    local veh = GetVehiclePedIsIn(ped(), false)
    if veh == 0 then return nil end
    return veh
end

-- --------------------------- FEATURES -----------------------------

local function godmodeLoop()
    Citizen.CreateThread(function()
        while toggles.godmode do
            Citizen.Wait(400)
            SetEntityInvincible(ped(), true)
            SetPlayerInvincible(PlayerId(), true)
        end
        SetEntityInvincible(ped(), false)
        SetPlayerInvincible(PlayerId(), false)
    end)
end

local function infammoLoop()
    Citizen.CreateThread(function()
        while toggles.infammo do
            Citizen.Wait(750)
            local p = ped()
            SetPedInfiniteAmmoClip(p, true)
            local _, wpn = GetCurrentPedWeapon(p, true)
            if wpn and wpn ~= 0 then SetPedInfiniteAmmo(p, true, wpn) end
        end
    end)
end

local function rotationToDirection(rot)
    local rz, rx = math.rad(rot.z), math.rad(rot.x)
    local cx = math.abs(math.cos(rx))
    return v3(-math.sin(rz) * cx, math.cos(rz) * cx, math.sin(rx))
end

local function noclipLoop()
    Citizen.CreateThread(function()
        Citizen.Wait(100)
        while toggles.noclip do
            Citizen.Wait(0)
            local p = ped()
            SetEntityCollision(p, false, false)
            FreezeEntityPosition(p, true)
            SetEntityInvincible(p, true)

            local spd = ctrlPressed(21) and 1.6 or 0.45     -- shift = faster
            local dir = rotationToDirection(GetGameplayCamRot(2))
            local c = GetEntityCoords(p)
            local rt = v3(dir.y, -dir.x, 0.0)
            local move = v3(0.0, 0.0, 0.0)

            if ctrlPressed(32) then move = vadd(move, dir) end
            if ctrlPressed(33) then move = vsub(move, dir) end
            if ctrlPressed(34) then move = vsub(move, rt) end
            if ctrlPressed(35) then move = vadd(move, rt) end
            if ctrlPressed(22) then move = vadd(move, v3(0, 0, 1)) end
            if ctrlPressed(36) then move = vsub(move, v3(0, 0, 1)) end

            move = vmul(move, spd)
            SetEntityCoordsNoOffset(p,
                c.x + move.x, c.y + move.y, c.z + move.z, true, true, true)
        end
        local p = ped()
        SetEntityCollision(p, true, true)
        FreezeEntityPosition(p, false)
    end)
end

local function superjumpLoop()
    Citizen.CreateThread(function()
        while toggles.superjump do
            Citizen.Wait(0)
            SetSuperJumpThisFrame(PlayerId())
        end
    end)
end

local function spawnVehicle(model)
    local hash = GetHashKey(model)
    RequestModel(hash)
    local tries = 0
    while not HasModelLoaded(hash) and tries < 200 do
        Citizen.Wait(10)
        tries = tries + 1
    end
    if not HasModelLoaded(hash) then
        notify('Model failed to load: ' .. model)
        return
    end

    local p = ped()
    local c = GetEntityCoords(p)
    local veh = CreateVehicle(hash, c.x, c.y, c.z, GetEntityHeading(p), true, false)
    if veh == 0 then
        notify('Vehicle creation failed: ' .. model)
        return
    end

    SetVehicleOnGroundProperly(veh)
    SetPedIntoVehicle(p, veh, -1)
    if type(G.SetVehicleEngineOn) == 'function' then
        SetVehicleEngineOn(veh, true, true, false)
    end
    if type(G.SetModelAsNoLongerNeeded) == 'function' then
        SetModelAsNoLongerNeeded(hash)
    end
    notify('Spawned ' .. model)
end

local function giveWeapon(name)
    local hash = GetHashKey(name)
    local p = ped()
    GiveWeaponToPed(p, hash, 9999, false, true)
    SetCurrentPedWeapon(p, hash, true)
    notify('Given ' .. name)
end

local ACTIONS = {}

ACTIONS.heal = function()
    local p = ped()
    SetEntityHealth(p, 200)
    ClearPedBloodDamage(p)
    if type(G.ClearPedWetness) == 'function' then ClearPedWetness(p) end
    notify('Healed')
end

ACTIONS.armor = function()
    SetPedArmour(ped(), 100)
    if type(G.SetPlayerMaxArmour) == 'function' then SetPlayerMaxArmour(PlayerId(), 100) end
    notify('Armor set to 100')
end

ACTIONS.maxammo = function()
    local p = ped()
    local _, wpn = GetCurrentPedWeapon(p, true)
    if not wpn or wpn == 0 then notify('No weapon in hand') return end
    SetPedAmmo(p, wpn, 9999)
    notify('Ammo refilled')
end

ACTIONS.repair = function()
    local veh = myVehicle()
    if not veh then notify('Not in a vehicle') return end
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleUndriveable(veh, false)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
    notify('Vehicle repaired')
end

ACTIONS.maxmods = function()
    local veh = myVehicle()
    if not veh then notify('Not in a vehicle') return end
    SetVehicleModKit(veh, 0)
    for slot = 0, 16 do
        local count = GetNumVehicleMods(veh, slot)
        if count and count > 0 then
            SetVehicleMod(veh, slot, count - 1, false)
        end
    end
    if type(G.SetVehicleWheelType) == 'function' then SetVehicleWheelType(veh, 0) end
    if type(G.ToggleVehicleMod) == 'function' then
        ToggleVehicleMod(veh, 18, true)   -- turbo
    end
    if type(G.SetVehicleTyresCanBurst) == 'function' then
        SetVehicleTyresCanBurst(veh, false)
    end
    if type(G.SetVehicleWindowTint) == 'function' then
        SetVehicleWindowTint(veh, 1)
    end
    notify('Max mods applied')
end

ACTIONS.deleteveh = function()
    local veh = myVehicle()
    if not veh then notify('Not in a vehicle') return end
    SetEntityAsMissionEntity(veh, true, true)
    DeleteEntity(veh)
    notify('Vehicle deleted')
end

ACTIONS.tpwaypoint = function()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then notify('No waypoint set') return end

    local c = GetBlipInfoIdCoord(blip)
    local p = ped()
    local foundZ = nil

    for z = 1000.0, 0.0, -25.0 do
        RequestCollisionAtCoord(c.x, c.y, z)
        Citizen.Wait(5)
        local hit, gz = GetGroundZFor_3dCoord(c.x, c.y, z, false)
        if hit then foundZ = gz break end
    end

    SetEntityCoordsNoOffset(p, c.x, c.y, (foundZ or 100.0) + 1.0, true, true, true)
    notify('Teleported')
end

ACTIONS.close = function() end   -- handled in the click dispatcher

-- --------------------------- RENDERING ----------------------------

local function geometry(tabIndex)
    local tab = TABS[tabIndex]
    local rows = #tab.items
    local w = LAYOUT.width
    local h = LAYOUT.headerH + LAYOUT.tabBarH + LAYOUT.padY * 2
        + rows * LAYOUT.rowH + LAYOUT.footerH
    local x = (screenW - w) * 0.5
    local y = (screenH - h) * 0.5
    return tab, rows, w, h, x, y
end

local function drawToggle(x, y, on)
    rect(x, y, LAYOUT.toggleW, LAYOUT.toggleH, on and C.trackOn or C.trackOff)
    local kx = on and (x + 19) or (x + 3)
    rect(kx, y + 3, 14, 14, on and C.knobOn or C.knobOff)
end

-- Which row is under the cursor? Pure hit-test, no drawing.
local function rowAtCursor()
    local _, _, w, _, bx, by = geometry(activeTab)
    local listTop = by + LAYOUT.headerH + LAYOUT.tabBarH + LAYOUT.padY
    local mx, my = px(cursorX), py(cursorY)
    if mx < bx + 4 or mx > bx + w - 4 then return 0 end
    for i = 1, #TABS[activeTab].items do
        local ry = listTop + (i - 1) * LAYOUT.rowH
        if my >= ry and my <= ry + LAYOUT.rowH then return i end
    end
    return 0
end

local function draw(mouseActive)
    local tab, rows, w, h, bx, by = geometry(activeTab)

    -- panel
    rect(bx - 1, by - 1, w + 2, h + 2, C.border)
    rect(bx, by, w, h, C.bg)

    -- header
    textAt('H E T I A', bx + w * 0.5, by + 16, LAYOUT.logoScale, C.accent, true)

    -- tabs
    local tabY = by + LAYOUT.headerH - 6
    local tabW = w / #TABS
    for i, t in ipairs(TABS) do
        local cx = bx + tabW * (i - 0.5)
        local hovered = math.abs(px(cursorX) - cx) < tabW * 0.5
            and py(cursorY) > tabY - 24
            and py(cursorY) < tabY + 14
        local col = (i == activeTab) and C.accent or (hovered and C.text or C.textDim)
        textAt(t.name, cx, tabY, LAYOUT.tabScale, col, true)
        if i == activeTab then
            rect(bx + tabW * (i - 1) + 12, tabY + 22, tabW - 24, 2, C.accent)
        end
    end
    rect(bx, by + LAYOUT.headerH, w, 1, C.divider)

    -- rows
    local listTop = by + LAYOUT.headerH + LAYOUT.tabBarH + LAYOUT.padY
    local hoveredRow = 0
    for i, item in ipairs(tab.items) do
        local ry = listTop + (i - 1) * LAYOUT.rowH
        local mx, my = px(cursorX), py(cursorY)
        local inside = mx >= bx + 4 and mx <= bx + w - 4
            and my >= ry and my <= ry + LAYOUT.rowH
        if inside then hoveredRow = i end

        if inside then
            rect(bx + 4, ry, w - 8, LAYOUT.rowH, C.hover)
        end

        local isSel = (i == selectedRow) and not mouseActive

        if isSel then
            rect(bx + 4, ry, 2, LAYOUT.rowH, C.accent)          -- accent bar
            rect(bx + 4, ry, w - 8, LAYOUT.rowH, C.hover)        -- row highlight
        end

        local col = (inside or isSel) and C.textHover or C.text
        textAt(item.label, bx + LAYOUT.labelInset, ry + 9, LAYOUT.rowScale, col, false)

        if item.kind == 'toggle' then
            local on = toggles[item.key] and true or false
            drawToggle(bx + w - LAYOUT.labelInset - LAYOUT.toggleW,
                ry + (LAYOUT.rowH - LAYOUT.toggleH) * 0.5, on)
        elseif isSel then
            textAt('>', bx + w - LAYOUT.labelInset, ry + 9, LAYOUT.rowScale,
                C.accent, 'right')
        end
    end

    -- footer
    rect(bx, by + h - LAYOUT.footerH, w, 1, C.divider)
    textAt('Hetia  |  l-0-0 [lifetime]',
        bx + LAYOUT.labelInset, by + h - LAYOUT.footerH + 8, LAYOUT.footScale, C.footer, false)
    textAt('F5 to toggle',
        bx + w - LAYOUT.labelInset, by + h - LAYOUT.footerH + 8, LAYOUT.footScale,
        C.footer, true)

    return hoveredRow
end

-- ------------------------- INPUT DISPATCH -------------------------

local function setToggle(key, value)
    toggles[key] = value
    if key == 'godmode' then
        if value then godmodeLoop() else
            SetEntityInvincible(ped(), false)
            SetPlayerInvincible(PlayerId(), false)
        end
    elseif key == 'infammo' then
        if value then infammoLoop() else
            local p = ped()
            SetPedInfiniteAmmoClip(p, false)
            local _, wpn = GetCurrentPedWeapon(p, true)
            if wpn and wpn ~= 0 then SetPedInfiniteAmmo(p, false, wpn) end
        end
    elseif key == 'noclip' then
        if value then noclipLoop() end
    elseif key == 'superjump' then
        if value then superjumpLoop() end
    end
end

local lastRow = 0
local selectedRow = 1
local prevMouseX, prevMouseY = 0.0, 0.0

local function clampSelection()
    local n = #TABS[activeTab].items
    if selectedRow < 1 then selectedRow = n end
    if selectedRow > n then selectedRow = 1 end
end

local function activateRow(index)
    local item = TABS[activeTab].items[index]
    if not item then return end

    if item.kind == 'toggle' then
        setToggle(item.key, not toggles[item.key])
    elseif item.kind == 'weapon' then
        giveWeapon(item.value)
    elseif item.kind == 'vehicle' then
        spawnVehicle(item.value)
    elseif item.kind == 'action' then
        if item.fn == 'close' then
            toggleMenu(false)
        elseif ACTIONS[item.fn] then
            ACTIONS[item.fn]()
        end
    end
end

local function handleClick()
    activateRow(selectedRow)
end

local function switchTab(delta)
    activeTab = activeTab + delta
    if activeTab < 1 then activeTab = #TABS end
    if activeTab > #TABS then activeTab = 1 end
    selectedRow = 1
    lastRow = 0
end

-- ----------------------------- LOOP -------------------------------

function toggleMenu(state)
    if state == nil then state = not menuOpen end
    menuOpen = state

    if USE_NUI_FOCUS and type(G.SetNuiFocus) == 'function' then
        local ok = pcall(SetNuiFocus, menuOpen, menuOpen)
        if not ok then
            print('^3[HETIA] SetNuiFocus rejected; using cursor-only mode^7')
            USE_NUI_FOCUS = false
        end
    end

    if menuOpen then
        cursorX, cursorY = 0.5, 0.5
        selectedRow = 1
        notify('Menu opened')
    else
        lastRow = 0
        notify('Menu closed')
    end
end

Citizen.CreateThread(function()
    refreshResolution()
    print('^2[HETIA] loop started. resolution ' .. screenW .. 'x' .. screenH
        .. ' (scale ' .. string.format('%.2f', scale) .. ')^7')
    while true do
        Citizen.Wait(0)

        if menuOpen then
            DisableAllControlActions(0)

            -- ---------- mouse ----------
            local mx = GetDisabledControlNormal(0, 239) or 0.0
            local my = GetDisabledControlNormal(0, 240) or 0.0
            local mouseMoved = math.abs(mx) > 0.0001 or math.abs(my) > 0.0001

            if mouseMoved then
                cursorX = math.min(math.max(cursorX + mx * LAYOUT.cursorSens, 0.0), 1.0)
                cursorY = math.min(math.max(cursorY + my * LAYOUT.cursorSens, 0.0), 1.0)
                local hover = rowAtCursor()
                if hover > 0 then selectedRow = hover end
            end

            SetCursorLocation(cursorX, cursorY)
            SetMouseCursorActiveThisFrame()

            -- ---------- keyboard ----------
            if ctrlJustPressed(KEY.up)    then selectedRow = selectedRow - 1; clampSelection() end
            if ctrlJustPressed(KEY.down)  then selectedRow = selectedRow + 1; clampSelection() end
            if ctrlJustPressed(KEY.left)  then switchTab(-1) end
            if ctrlJustPressed(KEY.right) then switchTab(1) end
            if ctrlJustPressed(KEY.enter) then activateRow(selectedRow) end
            if ctrlJustPressed(KEY.esc) or ctrlJustPressed(KEY.cancel2) then
                toggleMenu(false)
            end

            -- scroll wheel cycles tabs (241 = up, 242 = down)
            local su = GetDisabledControlNormal(0, KEY.scrollUp) or 0.0
            local sd = GetDisabledControlNormal(0, KEY.scrollDown) or 0.0
            if su > 0.1 then switchTab(1) end
            if sd > 0.1 then switchTab(-1) end

            -- ---------- render ----------
            lastRow = draw(mouseMoved and true or false)

            -- ---------- click ----------
            if ctrlJustPressed(KEY.click) or ctrlJustPressed(KEY.click2) then
                local _, _, w, _, bx, by = geometry(activeTab)
                local mxp, myp = px(cursorX), py(cursorY)
                local tabY = by + LAYOUT.headerH - 6
                if myp > tabY - 24 and myp < tabY + 14 then
                    local tabW = w / #TABS
                    local idx = math.floor((mxp - bx) / tabW) + 1
                    if idx >= 1 and idx <= #TABS then
                        activeTab = idx
                        selectedRow = 1
                        lastRow = 0
                    end
                else
                    handleClick()
                end
            end
        end
    end
end)

-- --------------------------- KEYBIND ------------------------------

RegisterCommand('hetia', function()
    toggleMenu()
end, false)

RegisterKeyMapping('hetia', 'Open Hetia Menu', 'keyboard', 'F5')

-- Raw-key fallback, for executors where key mappings never register.
-- Tries every plausible raw-input function name before giving up.
local rawKeyFns = {
    'IsRawKeyPressed', 'IsKeyDown', 'IsRawKeyDown', 'GetKeyState',
    'IsKeyPressed', 'IsRawKeyJustPressed',
}

local rawFn, rawName = nil, nil
for _, name in ipairs(rawKeyFns) do
    if type(G[name]) == 'function' then
        rawFn, rawName = G[name], name
        break
    end
end

if rawFn then
    print('^2[HETIA] raw-key fallback active via ' .. rawName .. '^7')
    Citizen.CreateThread(function()
        local held = false
        while true do
            Citizen.Wait(0)
            local ok, down = pcall(rawFn, TOGGLE_VK)
            if ok and down and not held then toggleMenu() end
            held = ok and down or false
        end
    end)
else
    print('^3[HETIA] no raw-key function found -- use /hetia in chat, or re-run the script^7')
end

if OPEN_ON_LOAD then
    Citizen.CreateThread(function()
        Citizen.Wait(250)
        toggleMenu(true)
    end)
end

print('^2[HETIA] native menu loaded. Press F5 (or type /hetia) to toggle.^7')