-- layout.lua
-- Where the side tab sits relative to its default spot beside the bank, and how
-- big it is. Saved in PersistentDB ("layout_dx", "layout_dy", "layout_scale") so
-- the choice survives restarts. This module's table is the state itself:
--   Layout.dx, Layout.dy  offset from the default spot, in interface units
--   Layout.scale          size multiplier (Config.SCALE_MIN .. Config.SCALE_MAX)

local Config = require("src/config")

local Layout = { dx = 0, dy = 0, scale = 1.0 }

local function clampScale(scale)
    return math.min(Config.SCALE_MAX, math.max(Config.SCALE_MIN, scale))
end

local function load()
    Layout.dx = math.floor(tonumber(PersistentDB:GetString("layout_dx") or "") or 0)
    Layout.dy = math.floor(tonumber(PersistentDB:GetString("layout_dy") or "") or 0)
    Layout.scale = clampScale(tonumber(PersistentDB:GetString("layout_scale") or "") or 1.0)
end
load()

function Layout.save()
    PersistentDB:SetString("layout_dx", tostring(Layout.dx))
    PersistentDB:SetString("layout_dy", tostring(Layout.dy))
    PersistentDB:SetString("layout_scale", string.format("%.2f", Layout.scale))
end

-- Sets the offset and saves it.
function Layout.setOffset(dx, dy)
    Layout.dx = math.floor(dx + 0.5)
    Layout.dy = math.floor(dy + 0.5)
    Layout.save()
end

-- Sets the size multiplier (rounded to 2 decimals, clamped) and saves it.
function Layout.setScale(scale)
    Layout.scale = clampScale(math.floor(scale * 100 + 0.5) / 100)
    Layout.save()
end

-- Back to the default spot and size.
function Layout.reset()
    Layout.dx, Layout.dy, Layout.scale = 0, 0, 1.0
    Layout.save()
end

-- Scales a base size by the current multiplier, rounded to whole units.
function Layout.scaled(value)
    return math.floor(value * Layout.scale + 0.5)
end

return Layout
