-- bank.lua
-- Knows whether the bank window is really open. The bank's components can stay
-- loaded after it closes, so "the component exists" is not enough: this module
-- also checks visibility, size and that at least one slot of the item grid is
-- visible. Every time one of those signals changes it logs the values (with
-- Config.DEBUG on), which makes problems easy to diagnose.

local Config = require("src/config")
local Util = require("src/util")
local Geometry = require("src/geometry")

local Bank = {}

local debugLog = Util.debugLog
local readProp = Util.readProp

local lastState = nil
local lastOpen = nil

-- The bank window's root component, or nil if its interface is not loaded.
function Bank.root()
    return ui.Interfaces:GetComponent(Config.BANK_ROOT.interfaceID, Config.BANK_ROOT.staticID)
end

-- True if at least one slot of the item grid is visible.
local function anySlotVisible(grid)
    local found = false
    grid:IterateDynamicComponents(function(slot, _)
        if readProp(slot, "visibleGlobal") == true then
            found = true
            return true -- stop at the first visible slot
        end
        return false
    end)
    return found
end

-- Gathers the signals, logs them whenever they change and returns whether the
-- bank counts as open. `root` is the result of Bank.root().
function Bank.isOpen(root)
    if root == nil then
        if lastState ~= "root not loaded" then
            lastState = "root not loaded"
            debugLog("bank state: root not loaded")
        end
        lastOpen = false
        return false
    end

    local grid = ui.Interfaces:GetComponent(Config.BANK_GRID.interfaceID, Config.BANK_GRID.staticID)
    local rootVisible = Geometry.isVisible(root)
    local gridVisible = grid == nil or Geometry.isVisible(grid)
    local sized = (readProp(root, "width") or 0) > 0 and (readProp(root, "height") or 0) > 0
    local slotsVisible = true
    if rootVisible and gridVisible and sized and grid ~= nil then
        slotsVisible = anySlotVisible(grid)
    end

    local state = table.concat({
        tostring(readProp(root, "visibleGlobal")), tostring(readProp(root, "visible")),
        tostring(grid ~= nil and readProp(grid, "visibleGlobal")), tostring(grid ~= nil and readProp(grid, "visible")),
        tostring(readProp(root, "width")), tostring(readProp(root, "height")),
        tostring(slotsVisible),
    }, " ")
    if state ~= lastState then
        lastState = state
        debugLog("bank state: rootVisibleGlobal/rootVisible/gridVisibleGlobal/gridVisible/width/height/anySlotVisible = " .. state)
    end

    local open = rootVisible and gridVisible and sized and slotsVisible
    if open ~= lastOpen then
        lastOpen = open
        debugLog("bank open: " .. tostring(open))
    end
    return open
end

return Bank
