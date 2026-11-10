-- state.lua
-- Runtime state shared by the modules, plus a tiny change notification so the
-- side tab, the panel and the outlines can react without knowing each other.
--
--   State.activeCategory  the tag picked in the side tab / panel (nil = none)
--   State.selectMode      true while clicks on bank items toggle the active tag
--   State.outlinesDirty   set when something changed that needs a redraw
--   State.tick            client logic ticks since the plugin started

local State = {
    activeCategory = nil,
    selectMode = false,
    outlinesDirty = false,
    tick = 0,
}

local listeners = {}

-- Registers a function called as listener(reason) after a state change.
-- Reasons: "category", "select", "colour", "style", "tags".
function State.onChange(listener)
    listeners[#listeners + 1] = listener
end

-- Tells every listener that something changed and asks for an outline redraw.
function State.notify(reason)
    State.outlinesDirty = true
    for _, listener in ipairs(listeners) do
        listener(reason)
    end
end

-- Picks the active tag (nil clears it). Select mode needs a tag, so it turns off.
function State.setActiveCategory(category)
    State.activeCategory = category
    if category == nil then
        State.selectMode = false
    end
    State.notify("category")
end

function State.setSelectMode(enabled)
    State.selectMode = enabled
    State.notify("select")
end

return State
