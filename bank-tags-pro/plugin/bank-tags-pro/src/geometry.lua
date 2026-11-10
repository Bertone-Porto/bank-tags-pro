-- geometry.lua
-- Helpers for reading where UI components really are on screen.

local Util = require("src/util")

local Geometry = {}

-- Sum of the scroll offsets of `node` and every ancestor above it.
-- Scrolled lists (like the bank) report slot positions in content space, so the
-- on-screen position is the reported position minus the scroll offset.
function Geometry.scrollOffsetFrom(node)
    local dx, dy = 0, 0
    local current = node
    local depth = 0
    while current ~= nil and depth < 10 do
        if Util.readProp(current, "scrollable") == true then
            dx = dx + (Util.readProp(current, "scrollX") or 0)
            dy = dy + (Util.readProp(current, "scrollY") or 0)
        end
        current = current.parent
        depth = depth + 1
    end
    return dx, dy
end

-- Scroll offset that applies to the slot `component` (its parents and above).
function Geometry.scrollOffset(component)
    return Geometry.scrollOffsetFrom(component.parent)
end

-- False if the component is hidden. Uses the docs' visibility properties:
-- visibleGlobal (visible in the whole UI tree) and visible (includes built-in
-- UI state). A missing component counts as not visible.
function Geometry.isVisible(component)
    if component == nil then
        return false
    end
    if Util.readProp(component, "visibleGlobal") == false then
        return false
    end
    if Util.readProp(component, "visible") == false then
        return false
    end
    return true
end

return Geometry
