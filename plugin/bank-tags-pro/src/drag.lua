-- drag.lua
-- Generic mouse dragging for UI components, used by the side tab's title bar
-- (move) and corner square (resize).
--
-- The hold hook may report the cursor in local coordinates (inside the component)
-- or global ones; which one is detected once when the drag starts and logged.
-- Each hold event hands the caller only how far the cursor is from where it
-- grabbed, so the result is the same whichever mode is used.
--
-- Usage:
--   Drag.attach(component, "move", {
--       onStart = function() end,          -- optional
--       onMove  = function(rx, ry) end,    -- cursor offset since the last event
--       onEnd   = function() end,          -- optional
--   })

local Util = require("src/util")
local State = require("src/state")

local Drag = {}

-- A drag whose release event we never saw ends after this many ticks.
local STALE_TICKS = 5

local active = nil -- { kind, handlers, mode, grabX, grabY, lastTick }
local errorSeen = nil

function Drag.isActive()
    return active ~= nil
end

-- Forgets the current drag without calling onEnd (used when its UI is destroyed).
function Drag.cancel()
    active = nil
end

-- Ends the current drag, if any, and calls its onEnd.
function Drag.finish()
    if active == nil then
        return
    end
    local finished = active
    active = nil
    if finished.handlers.onEnd ~= nil then
        finished.handlers.onEnd()
    end
end

-- Ends the drag if no hold event arrived for a few ticks (call once per tick).
function Drag.finishIfStale()
    if active ~= nil and State.tick - active.lastTick > STALE_TICKS then
        Drag.finish()
    end
end

local function begin(kind, handlers, component, x, y)
    local position = component.xyGlobal
    local isLocal = x >= 0 and y >= 0 and x <= component.width and y <= component.height
    active = { kind = kind, handlers = handlers, lastTick = State.tick }
    if isLocal then
        active.mode = "local"
        active.grabX, active.grabY = x, y
    else
        active.mode = "global"
        active.grabX, active.grabY = x - position.x, y - position.y
    end
    Util.debugLog("drag " .. kind .. " started, cursor coordinates look " .. active.mode
        .. " (" .. tostring(x) .. "," .. tostring(y) .. ")")
    if handlers.onStart ~= nil then
        handlers.onStart()
    end
end

-- How far the cursor has moved from its grab point, relative to the component.
local function residual(component, x, y)
    if active.mode == "local" then
        return x - active.grabX, y - active.grabY
    end
    local position = component.xyGlobal
    return (x - position.x) - active.grabX, (y - position.y) - active.grabY
end

local function onHold(kind, handlers, component, x, y)
    if active == nil or active.kind ~= kind or State.tick - active.lastTick > STALE_TICKS then
        Drag.finish()
        begin(kind, handlers, component, x, y)
    end
    active.lastTick = State.tick

    local rx, ry = residual(component, x, y)
    if rx ~= 0 or ry ~= 0 then
        handlers.onMove(rx, ry)
    end
end

-- Runs a callback without letting an error repeat on every tick.
local function run(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and err ~= errorSeen then
        errorSeen = err
        Util.say("ERROR while dragging the tab: " .. tostring(err))
    end
end

-- Makes `component` a drag handle of the given kind (a label used in logs).
function Drag.attach(component, kind, handlers)
    local ok, err = pcall(function()
        component.enabled = true
        component.clickthrough = false
        component:Subscribe(ui.Hook.ONHOLD, function(self, x, y)
            run(onHold, kind, handlers, self, x, y)
        end)
        component:Subscribe(ui.Hook.ONRELEASE, function()
            run(Drag.finish)
        end)
    end)
    if not ok then
        Util.say("could not make the " .. kind .. " handle draggable: " .. tostring(err))
    end
end

return Drag
