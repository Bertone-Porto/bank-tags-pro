-- style.lua
-- The outline style (thickness and pulse) chosen with the Style button. The
-- choice is saved in PersistentDB under "style_index".

local Config = require("src/config")

local Style = {}

local index = Config.DEFAULT_STYLE_INDEX

local function load()
    local saved = math.floor(tonumber(PersistentDB:GetString("style_index") or "") or Config.DEFAULT_STYLE_INDEX)
    if Config.STYLE_PRESETS[saved] ~= nil then
        index = saved
    end
end
load()

-- The active preset: { thickness, pulse, label }.
function Style.current()
    return Config.STYLE_PRESETS[index]
end

-- Index of the active preset (part of outline cache keys).
function Style.index()
    return index
end

-- Switches to the next preset and saves it.
function Style.cycle()
    index = index % #Config.STYLE_PRESETS + 1
    PersistentDB:SetString("style_index", tostring(index))
end

return Style
