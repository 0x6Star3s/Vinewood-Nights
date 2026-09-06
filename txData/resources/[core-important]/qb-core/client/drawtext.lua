-- Jedna podpowiedz "[E] ..." na calym serwerze: qb-core przekierowuje swoj DrawText
-- na lib.showTextUI z ox_lib - to samo, czego uzywa warsztat. NUI qb-core (html/)
-- zostaje na dysku, ale nic juz do niego nie pisze.
local POSITIONS = { left = 'left-center', right = 'right-center', top = 'top-center' }

-- Zasoby przysylaja HTML (<br>, <span>) - ox_lib pokazuje zwykly tekst
local function clean(text)
    text = tostring(text or '')
    text = text:gsub('<br%s*/?>', '\n'):gsub('<[^>]->', '')
    return text
end

local function hideText()
    lib.hideTextUI()
end

local function drawText(text, position)
    if type(position) ~= 'string' then position = 'left' end
    lib.showTextUI(clean(text), { position = POSITIONS[position] or 'left-center' })
end

local function changeText(text, position)
    drawText(text, position)
end

local function keyPressed()
    CreateThread(function()
        Wait(500)
        hideText()
    end)
end

RegisterNetEvent('qb-core:client:DrawText', function(text, position)
    drawText(text, position)
end)

RegisterNetEvent('qb-core:client:ChangeText', function(text, position)
    changeText(text, position)
end)

RegisterNetEvent('qb-core:client:HideText', function()
    hideText()
end)

RegisterNetEvent('qb-core:client:KeyPressed', function()
    keyPressed()
end)

exports('DrawText', drawText)
exports('ChangeText', changeText)
exports('HideText', hideText)
exports('KeyPressed', keyPressed)
