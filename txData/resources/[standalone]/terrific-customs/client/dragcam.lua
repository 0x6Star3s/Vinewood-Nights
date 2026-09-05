-- Kamera orbitalna wokol pojazdu.
-- Zrodlo: dragcam.lua (autor: Jorn) z Qbox-project/qbx_customs, GPL-3.0.
-- Zmiany: usunieta warstwa locale i wlasne instructional buttons (rysuje je ScaleformUI),
-- skladnia CFX (+=, ?.) zamieniona na czysty Lua, reset stanu przy stopie.

local angleY, angleZ = 0.0, 0.0
local cam, running
local gEntity, gRadius, gRadiusMax, gRadiusMin, scrollIncrements
local isFirstPersonView = false

local function cos(degrees) return math.cos(math.rad(degrees)) end
local function sin(degrees) return math.sin(math.rad(degrees)) end

-- ox_lib 3.6.0 nie ma lib.math.clamp (lib.math = math), oryginal by tu wybuchl.
local function clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end

local function setCamPosition()
    local entityCoords = GetEntityCoords(gEntity)
    local mouseX = GetDisabledControlNormal(0, 1) * 8.0 -- 8x = czulosc myszy
    local mouseY = GetDisabledControlNormal(0, 2) * 8.0

    angleZ = angleZ - mouseX -- lewo / prawo
    angleY = angleY + mouseY -- gora / dol
    angleY = clamp(angleY, 0.0, 89.0) -- >=90 przewraca kamere, <0 wchodzi pod ziemie

    local cosAngleZ, cosAngleY = cos(angleZ), cos(angleY)
    local sinAngleZ, sinAngleY = sin(angleZ), sin(angleY)

    local offset = vec3(
        ((cosAngleZ * cosAngleY) + (cosAngleY * cosAngleZ)) / 2 * gRadius,
        ((sinAngleZ * cosAngleY) + (cosAngleY * sinAngleZ)) / 2 * gRadius,
        sinAngleY * gRadius
    )

    SetCamCoord(cam, entityCoords.x + offset.x, entityCoords.y + offset.y, entityCoords.z + offset.z)
    PointCamAtCoord(cam, entityCoords.x, entityCoords.y, entityCoords.z + 0.5)
end

local function disablePlayerMovement()
    local controls = { 21, 24, 25, 30, 31, 36, 47, 58, 69, 75, 140, 141, 142, 143, 257, 263, 264 }
    for i = 1, #controls do
        DisableControlAction(0, controls[i], true)
    end
end

local function disableCamMovement()
    local controls = { 1, 2, 3, 4, 5, 6, 12, 13 }
    for i = 1, #controls do
        DisableControlAction(0, controls[i], true)
    end
end

local function mouseDownListener()
    CreateThread(function()
        while running do
            setCamPosition()
            if IsDisabledControlJustReleased(0, 24) or IsControlJustReleased(0, 24) then
                SetMouseCursorSprite(3)
                return
            end
            Wait(0)
        end
    end)
end

local function inputListener()
    setCamPosition() -- bez tego kamera wisi na graczu az do pierwszego kliku
    CreateThread(function()
        while running do
            DisableControlAction(0, 0, true) -- INPUT_NEXT_CAMERA | V
            disablePlayerMovement()

            if not isFirstPersonView then
                SetMouseCursorActiveThisFrame()
                disableCamMovement()
                if IsDisabledControlJustPressed(0, 24) or IsControlJustPressed(0, 24) then
                    SetMouseCursorSprite(4)
                    mouseDownListener()
                end
            end

            if IsDisabledControlJustReleased(0, 14) or IsControlJustReleased(0, 14) then
                if gRadius + scrollIncrements <= gRadiusMax then
                    gRadius = gRadius + scrollIncrements
                    setCamPosition()
                end
            elseif IsDisabledControlJustReleased(0, 15) or IsControlJustReleased(0, 15) then
                if gRadius - scrollIncrements >= gRadiusMin then
                    gRadius = gRadius - scrollIncrements
                    setCamPosition()
                end
            end

            if IsControlJustPressed(0, 22) then -- SPACJA = drzwi
                local doors = GetNumberOfVehicleDoors(gEntity)
                for i = 0, doors do
                    if GetVehicleDoorAngleRatio(gEntity, i) > 0 then
                        SetVehicleDoorShut(gEntity, i, false)
                    else
                        SetVehicleDoorOpen(gEntity, i, false, false)
                    end
                end
            end

            if IsDisabledControlJustPressed(0, 0) then -- V = widok z kabiny
                isFirstPersonView = not isFirstPersonView
                RenderScriptCams(not isFirstPersonView, true, 0, true, false)
                if isFirstPersonView then SetCamViewModeForContext(1, 4) end
            end

            Wait(0)
        end
    end)
end

DragCam = {}

---@param entity integer
---@param opts? { initial?: number, min?: number, max?: number, scrollIncrements?: number, angle?: number }
function DragCam.start(entity, opts)
    if running then return end
    opts = opts or {}

    running          = true
    gEntity          = entity
    gRadius          = opts.initial or 5.0
    gRadiusMin       = opts.min or 2.5
    gRadiusMax       = opts.max or 10.0
    scrollIncrements = opts.scrollIncrements or 0.5
    angleY, angleZ   = clamp(opts.angle or 0.0, 0.0, 89.0), 0.0 -- >0 = start z gory
    isFirstPersonView = false

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    RenderScriptCams(true, true, 0, true, false)
    inputListener()
end

--- Podmiana śledzonego pojazdu bez resetu kąta i zoomu (lista aut w garażu).
--- Zwraca false, gdy kamera nie działa - wtedy trzeba ją wystartować.
function DragCam.setEntity(entity)
    if not running then return false end
    gEntity = entity
    setCamPosition()
    return true
end

function DragCam.stop()
    if not running then return end
    running = false

    RenderScriptCams(false, true, 0, true, false)
    if cam then DestroyCam(cam, true) end
    cam = nil
    SetCamViewModeForContext(1, 1)
    isFirstPersonView = false
end
