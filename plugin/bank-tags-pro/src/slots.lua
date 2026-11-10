-- slots.lua
-- Item slots of the bank grid: which components count as taggable, how to read
-- the item shown by a slot, and the always-on outlines (every visible item of the
-- active tag, not only the hovered one).

local Config = require("src/config")
local Util = require("src/util")
local State = require("src/state")
local Tags = require("src/tags")
local Colours = require("src/colours")
local Outline = require("src/outline")
local Geometry = require("src/geometry")

local Slots = {}

local debugLog = Util.debugLog
local readProp = Util.readProp

---------------------------------------------------------------------------
-- Which slots are taggable
---------------------------------------------------------------------------

-- True if `component` is an item slot of one of Config.SLOT_SOURCES (the bank
-- grid). A slot reports the interface and static component it sits in.
function Slots.isTaggable(component)
    for _, source in ipairs(Config.SLOT_SOURCES) do
        if component.interfaceID == source.interfaceID and component.staticID == source.staticID then
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Reading the item shown by a slot
---------------------------------------------------------------------------

-- Ways to read the item shown by a slot. The docs only name
-- Sprite:SetAssociatedObject, so these getter names are tried one by one: the
-- first that returns the same item ID as the hovered item (known from the menu)
-- is used. The one that works on the current client is component.associatedObjectID;
-- the others are kept as fallbacks in case a game update renames it.
local READERS = {
    { name = "component.associatedObjectID",    read = function(c) return c.associatedObjectID end },
    { name = "component:GetAssociatedObject()", read = function(c) return c:GetAssociatedObject() end },
    { name = "component.associatedObject",      read = function(c) return c.associatedObject end },
    { name = "component.associatedObj",         read = function(c) return c.associatedObj end },
    { name = "component.objConfig",             read = function(c) return c.objConfig end },
    { name = "component.obj",                   read = function(c) return c.obj end },
    { name = "component.objID",                 read = function(c) return c.objID end },
    { name = "component.objId",                 read = function(c) return c.objId end },
    { name = "component:GetAssociatedObj()",    read = function(c) return c:GetAssociatedObj() end },
    { name = "component.associatedObjID",       read = function(c) return c.associatedObjID end },
    { name = "component.associatedObjectId",    read = function(c) return c.associatedObjectId end },
    { name = "component.objectID",              read = function(c) return c.objectID end },
}

local reader = nil
local lastDetectKey = nil

-- Item ID from a number or from an ObjType-like value with an `id` property.
local function objectId(value)
    if type(value) == "number" then
        return value
    end
    if value ~= nil then
        local idValue = readProp(value, "id")
        if type(idValue) == "number" then
            return idValue
        end
    end
    return nil
end

-- True once a working reader has been found.
function Slots.hasReader()
    return reader ~= nil
end

-- Tries every reader on a hovered slot whose item ID is known from the menu and
-- keeps the first one that returns that same ID. Does nothing once one is found.
function Slots.detectReader(component, itemId)
    if reader ~= nil then
        return
    end
    local key = tostring(itemId)
    local verbose = Config.DEBUG and key ~= lastDetectKey
    lastDetectKey = key
    for _, candidate in ipairs(READERS) do
        local ok, value = pcall(candidate.read, component)
        local readId = nil
        if ok then
            readId = objectId(value)
        end
        if verbose then
            if ok then
                debugLog("  slot reader " .. candidate.name .. " -> " .. tostring(readId or value))
            else
                debugLog("  slot reader " .. candidate.name .. " -> error: " .. tostring(value))
            end
        end
        if readId == itemId then
            reader = candidate
            Util.say("slot items can be read with " .. candidate.name .. "; always-on outlines enabled.")
            return
        end
    end
end

-- Item ID shown by `slot`, or nil if empty or unreadable.
local function readSlotItemId(slot)
    local ok, value = pcall(reader.read, slot)
    if ok then
        return objectId(value)
    end
    return nil
end

---------------------------------------------------------------------------
-- Always-on outlines
-- Every few ticks, walks the slots of the bank grid, reads the item in each slot
-- and outlines those with the active tag. Slot positions are corrected for
-- scrolling and slots that are not fully inside the visible area are skipped, so
-- nothing is drawn outside the window.
---------------------------------------------------------------------------

local lastOutlineCount = nil

-- Outlines the tagged slots of one source. Returns the next free pool index.
local function refreshSource(source, nextIndex)
    local collection = ui.Interfaces:GetComponent(source.interfaceID, source.staticID)
    if collection == nil then
        return nextIndex -- that interface is not loaded (for example, bank closed)
    end

    -- Visible area: the parent of the scrolling grid (or the grid itself).
    local clip = collection.parent or collection
    local clipPosition = clip.xyGlobal
    local clipLeft = clipPosition.x
    local clipTop = clipPosition.y
    local clipRight = clipLeft + clip.width
    local clipBottom = clipTop + clip.height

    local origin = Outline.layer().xyGlobal
    local scrollX, scrollY = Geometry.scrollOffsetFrom(collection)

    collection:IterateDynamicComponents(function(slot, _)
        if nextIndex > Config.MAX_OUTLINES then
            return true -- stop: the pool is full
        end
        local position = slot.xyGlobal
        local left = position.x - scrollX
        local top = position.y - scrollY
        local width = slot.width
        local height = slot.height

        if left >= clipLeft and top >= clipTop and left + width <= clipRight and top + height <= clipBottom then
            local itemId = readSlotItemId(slot)
            if itemId ~= nil then
                local category = Outline.categoryFor(Tags.get(itemId))
                if category ~= nil and readProp(slot, "visibleGlobal") ~= false then
                    local x = math.floor(left - origin.x)
                    local y = math.floor(top - origin.y)
                    local key = Outline.key(x, y, width, height, category)
                    local entry = Outline.poolEntry(nextIndex)
                    if not entry.shown or entry.key ~= key then
                        entry.rgb = Colours.get(category)
                        Outline.set(entry.rects, x, y, width, height, entry.rgb)
                        entry.key = key
                        entry.shown = true
                    end
                    nextIndex = nextIndex + 1
                end
            end
        end
        return false -- keep iterating
    end)
    return nextIndex
end

-- Redraws the always-on outlines for the active tag.
function Slots.refreshOutlines()
    if not Config.PERSISTENT_OUTLINES or reader == nil then
        return
    end
    if State.activeCategory == nil then
        Outline.hidePoolFrom(1) -- nothing selected: no glow, and no work
        lastOutlineCount = nil
        return
    end
    if not Outline.ensure() then
        return
    end

    local nextIndex = 1
    for _, source in ipairs(Config.SLOT_SOURCES) do
        nextIndex = refreshSource(source, nextIndex)
    end
    Outline.hidePoolFrom(nextIndex)

    local count = nextIndex - 1
    if count ~= lastOutlineCount then
        lastOutlineCount = count
        debugLog("always-on outlines: " .. tostring(count) .. " tagged slot(s) outlined")
    end
end

return Slots
