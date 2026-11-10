-- Bank Tags Pro
-- Tag the items in your bank, then pick a tag in the side tab next to the bank and
-- the items with that tag glow. Entry point: it loads the modules in src/ and
-- connects them to the client's events. See README.md for what each module does.
--
-- The plugin never sends actions to the server and never moves items: menu entries
-- only run local Lua code, and outlines are click-through rectangles.

local Config = require("src/config")
local Util = require("src/util")
local State = require("src/state")
local Drag = require("src/drag")
local Outline = require("src/outline")
local Slots = require("src/slots")
local SideTab = require("src/sidetab")
local Panel = require("src/panel")
local Menu = require("src/menu")

---------------------------------------------------------------------------
-- Logic tick
---------------------------------------------------------------------------

-- Runs every client logic tick (Event.Logic).
local function onLogicTick()
    State.tick = State.tick + 1

    -- A drag whose release we never saw (cursor let go elsewhere) ends here.
    Drag.finishIfStale()

    if State.tick % Config.PERSISTENT_REFRESH_TICKS == 0 then
        SideTab.refresh()
        Slots.refreshOutlines()
        State.outlinesDirty = false
    elseif State.outlinesDirty then
        State.outlinesDirty = false -- tags changed: redraw now instead of waiting
        Slots.refreshOutlines()
    end

    if State.tick % 2 == 0 then
        Outline.updatePulse(State.tick)
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

-- If Event.Logic is not available, the menu event (which runs every tick while the
-- menu is closed) drives the logic tick instead.
local menuDrivesTick = false

local function onMiniMenuReady(event)
    if menuDrivesTick then
        onLogicTick()
    end
    Menu.onMiniMenuReady(event)
end

Event.MiniMenuReady.Subscribe("BankTagsPro", Util.guarded("MiniMenuReady", onMiniMenuReady))

local logicEvent = Util.readProp(Event, "Logic")
if logicEvent ~= nil then
    logicEvent.Subscribe("BankTagsPro", Util.guarded("Logic", onLogicTick))
else
    menuDrivesTick = true
    Util.say("Event.Logic not found; the menu event drives the outlines instead.")
end

Event.ContentLayerReady.Subscribe("BankTagsPro", Util.guarded("ContentLayerReady", Panel.onContentLayerReady))

Util.say("loaded. Hold Shift and right-click an item to tag it; open the bank and pick a tag in the side tab.")
