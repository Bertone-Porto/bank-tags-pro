-- outline.lua
-- Draws the coloured outlines. An outline is a few unfilled rectangles nested one
-- unit apart (the style's thickness decides how many) on the plugin layer. They
-- are click-through, so they never block the mouse.
--
-- Two kinds of outline use it:
--   * the hover outline: one set of rectangles that follows the hovered item
--   * a pool of sets used by slots.lua for the always-on outlines

local Util = require("src/util")
local State = require("src/state")
local Tags = require("src/tags")
local Colours = require("src/colours")
local Style = require("src/style")
local Geometry = require("src/geometry")

local Outline = {}

local debugLog = Util.debugLog

local highlight = { layer = nil, rects = {}, rgb = nil, visible = false, key = nil, failed = false }
local pool = {} -- { rects, key, shown, rgb }
local pulseAlpha = 1.0

-- Creates one unfilled, click-through, hidden rectangle on the plugin layer.
local function newRectangle()
    local rectangle = ui.Rectangle.new(highlight.layer)
    rectangle.fill = false
    rectangle.clickthrough = true
    rectangle.hidden = true
    return rectangle
end

-- Makes sure `rects` holds at least `thickness` rectangles.
local function ensureRects(rects, thickness)
    for index = #rects + 1, thickness do
        rects[index] = newRectangle()
    end
end

-- Hides every rectangle of a set.
function Outline.hideRects(rects)
    for _, rectangle in ipairs(rects) do
        rectangle.hidden = true
    end
end

-- Finds the plugin layer (and prepares the hover rectangles) the first time it
-- is needed. Returns true if ready.
function Outline.ensure()
    if highlight.layer ~= nil then
        return true
    end
    if highlight.failed then
        return false
    end
    local ok, err = pcall(function()
        highlight.layer = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
        ensureRects(highlight.rects, Style.current().thickness)
    end)
    if not ok then
        highlight.failed = true
        highlight.layer = nil
        Util.say("ERROR: could not create the outline: " .. tostring(err))
        return false
    end
    return true
end

-- The plugin layer (nil until Outline.ensure() succeeded).
function Outline.layer()
    return highlight.layer
end

-- Which tag's outline an item with these tags gets, or nil for none: only items
-- with the active tag glow.
function Outline.categoryFor(tags)
    local active = State.activeCategory
    if active ~= nil and Tags.has(tags, active) then
        return active
    end
    return nil
end

-- Cache key for an outline: position, size, tag, its colour and the style.
function Outline.key(x, y, width, height, category)
    return table.concat({ x, y, width, height, category, Colours.signature(category), Style.index() }, ":")
end

-- Alpha of the outlines: always 1.0, or moving for pulse styles.
local function alpha()
    if Style.current().pulse then
        return pulseAlpha
    end
    return 1.0
end

-- Colours `rects` and places them over x, y, width x height. The first rectangle
-- is the outermost; each further one (up to the style's thickness) sits one unit
-- further inside. Rectangles beyond the thickness are hidden.
function Outline.set(rects, x, y, width, height, rgb)
    local thickness = Style.current().thickness
    ensureRects(rects, thickness)
    local colour = Vector4.new(rgb[1], rgb[2], rgb[3], alpha())
    for index, rectangle in ipairs(rects) do
        if index <= thickness then
            local inset = index - 1
            rectangle.colour = colour
            rectangle:SetPos(x + inset, y + inset)
            rectangle:SetSize(math.max(width - 2 * inset, 0), math.max(height - 2 * inset, 0))
            rectangle.hidden = false
        else
            rectangle.hidden = true
        end
    end
end

---------------------------------------------------------------------------
-- Hover outline
---------------------------------------------------------------------------

function Outline.hideHover()
    if highlight.visible then
        Outline.hideRects(highlight.rects)
        highlight.visible = false
        highlight.key = nil
    end
end

-- Places the hover outline over `component`, coloured for `category`.
function Outline.showHover(component, category)
    if not Outline.ensure() then
        return
    end

    local position = component.xyGlobal
    local origin = highlight.layer.xyGlobal
    local scrollX, scrollY = Geometry.scrollOffset(component)
    local x = math.floor(position.x - origin.x - scrollX)
    local y = math.floor(position.y - origin.y - scrollY)
    local width = component.width
    local height = component.height

    local key = Outline.key(x, y, width, height, category)
    if highlight.visible and key == highlight.key then
        return -- nothing changed since the last tick
    end
    highlight.key = key
    debugLog("outline " .. category .. " at " .. x .. "," .. y .. " size " .. width .. "x" .. height
        .. " (reported " .. tostring(position.x) .. "," .. tostring(position.y)
        .. ", scroll " .. tostring(scrollX) .. "," .. tostring(scrollY) .. ")")

    highlight.rgb = Colours.get(category)
    Outline.set(highlight.rects, x, y, width, height, highlight.rgb)
    highlight.visible = true
end

---------------------------------------------------------------------------
-- Pool for the always-on outlines
---------------------------------------------------------------------------

-- The pooled outline number `index`, created empty on first use:
-- { rects = {...}, key = string or nil, shown = bool, rgb = colour or nil }.
function Outline.poolEntry(index)
    local entry = pool[index]
    if entry == nil then
        entry = { rects = {}, key = nil, shown = false, rgb = nil }
        pool[index] = entry
    end
    return entry
end

-- Hides every pooled outline from `fromIndex` onwards.
function Outline.hidePoolFrom(fromIndex)
    for index = fromIndex, #pool do
        local entry = pool[index]
        if entry.shown then
            Outline.hideRects(entry.rects)
            entry.shown = false
            entry.key = nil
        end
    end
end

---------------------------------------------------------------------------
-- Pulse
---------------------------------------------------------------------------

-- Pulse styles: recolours the visible outlines with a new alpha. Call every
-- couple of ticks with the current tick count.
function Outline.updatePulse(tick)
    if not Style.current().pulse then
        pulseAlpha = 1.0
        return
    end
    pulseAlpha = 0.65 + 0.35 * math.sin(tick * 0.15)

    local function repaint(rects, rgb)
        if rgb == nil then
            return
        end
        local colour = Vector4.new(rgb[1], rgb[2], rgb[3], pulseAlpha)
        for _, rectangle in ipairs(rects) do
            if rectangle.hidden == false then
                rectangle.colour = colour
            end
        end
    end

    if highlight.visible then
        repaint(highlight.rects, highlight.rgb)
    end
    for _, entry in ipairs(pool) do
        if entry.shown then
            repaint(entry.rects, entry.rgb)
        end
    end
end

return Outline
