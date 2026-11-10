-- colours.lua
-- The colour of each tag. A colour picked by the user is saved in PersistentDB as
-- an index into Config.COLOUR_PALETTE; otherwise the default from
-- Config.CATEGORY_COLOURS (or white) is used.

local Config = require("src/config")

local Colours = {}

local cache = {}

-- Colour of a tag as { red, green, blue }.
function Colours.get(category)
    local cached = cache[category]
    if cached ~= nil then
        return cached
    end
    local rgb = Config.CATEGORY_COLOURS[category] or Config.DEFAULT_COLOUR
    local raw = PersistentDB:GetString(Config.COLOUR_KEY_PREFIX .. category)
    if raw then
        local index = tonumber(raw)
        if index ~= nil and Config.COLOUR_PALETTE[index] ~= nil then
            rgb = Config.COLOUR_PALETTE[index]
        end
    end
    cache[category] = rgb
    return rgb
end

-- Gives a tag the palette colour at `index` and remembers the choice.
function Colours.assignIndex(category, index)
    cache[category] = Config.COLOUR_PALETTE[index]
    PersistentDB:SetString(Config.COLOUR_KEY_PREFIX .. category, tostring(index))
end

-- Moves a tag to the next palette colour and returns it.
function Colours.cycle(category)
    local palette = Config.COLOUR_PALETTE
    local current = Colours.get(category)
    local nextIndex = 1
    for index, rgb in ipairs(palette) do
        if rgb[1] == current[1] and rgb[2] == current[2] and rgb[3] == current[3] then
            nextIndex = index % #palette + 1
            break
        end
    end
    Colours.assignIndex(category, nextIndex)
    return palette[nextIndex]
end

-- Forgets a tag's saved colour (used when the tag is deleted).
function Colours.forget(category)
    cache[category] = nil
    PersistentDB:Delete(Config.COLOUR_KEY_PREFIX .. category)
end

-- A string that changes whenever the colour changes (used in outline cache keys).
function Colours.signature(category)
    return table.concat(Colours.get(category), ",")
end

return Colours
