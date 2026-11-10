-- diagnostics.lua
-- Debug-only console output about the hovered item and its surrounding
-- components. Everything here does nothing unless Config.DEBUG is true; it is
-- what to look at (and send in a bug report) when a position or an interface ID
-- seems wrong.

local Config = require("src/config")
local Util = require("src/util")

local Diagnostics = {}

local debugLog = Util.debugLog
local readProp = Util.readProp

-- Reports Shift + hover on interface entries that carry no item.
local lastMissLog = nil
function Diagnostics.logMissingItem(entries)
    if not Config.DEBUG then
        return
    end
    local lastInterfaceEntry = nil
    for _, entry in ipairs(entries) do
        if entry.actionEntryType == MiniMenuEntryType.INTERFACE and entry.componentData ~= nil then
            lastInterfaceEntry = entry
        end
    end
    if lastInterfaceEntry == nil then
        return
    end
    local component = lastInterfaceEntry.componentData.component
    local text = tostring(lastInterfaceEntry.fullText)
    local key = tostring(component.interfaceID) .. ":" .. tostring(component.staticID) .. ":" .. text
    if key ~= lastMissLog then
        lastMissLog = key
        debugLog("interface entry without objConfig: interface " .. tostring(component.interfaceID)
            .. ", static " .. tostring(component.staticID) .. ", text '" .. text .. "'")
    end
end

-- Prints the chain of parent components above `component` (up to 6 levels) with
-- their scroll state, to find which ancestor scrolls.
local function logAncestors(component)
    local current = component.parent
    local depth = 1
    while current ~= nil and depth <= 6 do
        debugLog("  ancestor " .. depth .. ": type " .. tostring(current.type)
            .. ", interface " .. tostring(current.interfaceID)
            .. ", static " .. tostring(current.staticID)
            .. ", pos " .. tostring(current.xyGlobal)
            .. ", size " .. tostring(current.width) .. "x" .. tostring(current.height)
            .. ", scrollable " .. tostring(readProp(current, "scrollable"))
            .. ", scroll " .. tostring(readProp(current, "scrollX")) .. "," .. tostring(readProp(current, "scrollY"))
            .. ", scrollSize " .. tostring(readProp(current, "scrollWidth")) .. "x" .. tostring(readProp(current, "scrollHeight")))
        current = current.parent
        depth = depth + 1
    end
end

-- Asks the parent for its dynamic components (the sibling slots) via
-- ComponentCollection:IterateDynamicComponents. Prints the first three plus the
-- neighbours of the hovered slot, and a total.
local function logSiblings(component)
    local parent = component.parent
    if parent == nil then
        return
    end
    local hoveredId = component.dynamicID
    local total = 0
    local visibleCount = 0
    parent:IterateDynamicComponents(function(child, visible)
        total = total + 1
        if visible then
            visibleCount = visibleCount + 1
        end
        local near = hoveredId ~= nil and child.dynamicID ~= nil and math.abs(child.dynamicID - hoveredId) <= 1
        if total <= 3 or near then
            debugLog("  sibling #" .. total .. ": dynamic " .. tostring(child.dynamicID)
                .. ", category " .. tostring(child.categoryID)
                .. ", type " .. tostring(child.type)
                .. ", visible " .. tostring(visible)
                .. ", visibleGlobal " .. tostring(child.visibleGlobal)
                .. ", pos " .. tostring(child.xyGlobal)
                .. (near and " <- near hovered" or ""))
        end
        return false -- keep iterating
    end)
    debugLog("  hovered slot: dynamic " .. tostring(hoveredId) .. ", category " .. tostring(component.categoryID)
        .. ", visibleGlobal " .. tostring(component.visibleGlobal))
    debugLog("  parent has " .. total .. " dynamic components, " .. visibleCount .. " visible")
end

-- Shift held: reports the hovered item and the geometry of its component, which
-- is what the outlines are placed from. Logged on change only.
local lastItemLog = nil
function Diagnostics.logFoundItem(item, component)
    if not Config.DEBUG then
        return
    end
    local key = tostring(item.id) .. ":" .. tostring(component.interfaceID)
    if key == lastItemLog then
        return
    end
    lastItemLog = key
    debugLog("item '" .. tostring(item.name) .. "' id " .. tostring(item.id)
        .. " in interface " .. tostring(component.interfaceID)
        .. ", static " .. tostring(component.staticID))
    local ok, err = pcall(function()
        local parent = component.parent
        debugLog("  component type " .. tostring(component.type)
            .. ", parent type " .. tostring(parent ~= nil and parent.type or "none")
            .. ", pos " .. tostring(component.xyGlobal)
            .. ", size " .. tostring(component.width) .. "x" .. tostring(component.height))
    end)
    if not ok then
        debugLog("  could not read component geometry: " .. tostring(err))
    end

    local okChain, errChain = pcall(logAncestors, component)
    if not okChain then
        debugLog("  could not read ancestors: " .. tostring(errChain))
    end
    local okSiblings, errSiblings = pcall(logSiblings, component)
    if not okSiblings then
        debugLog("  could not iterate sibling components: " .. tostring(errSiblings))
    end
end

return Diagnostics
