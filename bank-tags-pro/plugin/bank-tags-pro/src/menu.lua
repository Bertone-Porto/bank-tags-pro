-- menu.lua
-- The right-click menu: finds the hovered item, shows its outline and adds the
-- plugin's own entries. Entries only run local Lua code; nothing is ever sent to
-- the server, and no item is moved.
--
--   * Shift + right click    "Add to / Remove from <tag>" (or one "Tag as ..." line
--                            per tag) and "Remove all tags"
--   * plain right click      an info line listing the item's tags
--   * Select mode (side tab) left click toggles the active tag on the item
--
-- Menu.onMiniMenuReady(event) is called every logic tick while the menu is closed.

local Config = require("src/config")
local Util = require("src/util")
local State = require("src/state")
local Tags = require("src/tags")
local Outline = require("src/outline")
local Slots = require("src/slots")
local Diagnostics = require("src/diagnostics")

local Menu = {}

local say = Util.say

---------------------------------------------------------------------------
-- Entry callbacks (run only when the player picks one of our entries)
---------------------------------------------------------------------------

-- "Tag as <tag>": adds the tag if the item lacks it.
local function onTagSelected(category, itemId, itemName)
    local tags = Tags.get(itemId)
    if Tags.has(tags, category) then
        say(itemName .. " already has the tag " .. category)
        return
    end
    local updated = {}
    for _, existing in ipairs(tags) do
        updated[#updated + 1] = existing
    end
    updated[#updated + 1] = category
    if Tags.save(itemId, updated) then
        say("Tagged " .. itemName .. " (id " .. tostring(itemId) .. ") as " .. category)
        State.notify("tags")
    else
        say("ERROR: could not save the tag for " .. itemName)
    end
end

-- "Add to / Remove from <tag>": adds the tag if the item lacks it, removes it otherwise.
local function onToggleSelected(category, itemId, itemName)
    local saved, had = Tags.toggle(itemId, category)
    if saved then
        if had then
            say("Removed " .. itemName .. " from " .. category)
        else
            say("Added " .. itemName .. " to " .. category)
        end
        State.notify("tags")
    else
        say("ERROR: could not save the change for " .. itemName)
    end
end

local function onRemoveAllSelected(itemId, itemName)
    if Tags.clear(itemId) then
        say("Removed all tags from " .. itemName .. " (id " .. tostring(itemId) .. ")")
        State.notify("tags")
    else
        say("ERROR: could not remove the tags of " .. itemName)
    end
end

-- The info entry only reports to the console; it changes nothing in the game.
local function onInfoSelected(itemName, tagText)
    say(itemName .. " is tagged: " .. tagText)
end

---------------------------------------------------------------------------
-- Building the menu
---------------------------------------------------------------------------

-- Finds the entry under the cursor that belongs to an interface item.
-- Returns the ObjType config and the component, or nil if there is none.
local function findTaggableItem(entries)
    for _, entry in ipairs(entries) do
        if entry.actionEntryType == MiniMenuEntryType.INTERFACE then
            local data = entry.componentData
            if data ~= nil and data.objConfig ~= nil and data.component ~= nil then
                return data.objConfig, data.component
            end
        end
    end
    return nil, nil
end

-- Moves the original highest-priority entry back to the end of the list, so our
-- new entries sit just below it. Indices are 1-based (see MiniMenu:Swap docs).
local function keepDefaultActionOnTop(menu, originalCount, addedCount)
    if originalCount < 1 then
        return
    end
    for i = 0, addedCount - 1 do
        menu:Swap(originalCount + i, originalCount + i + 1)
    end
end

-- "Add to" or "Remove from", depending on whether the item has the active tag.
local function toggleVerb(tags)
    if Tags.has(tags, State.activeCategory) then
        return "Remove from "
    end
    return "Add to "
end

-- One entry that adds the active tag to the item or removes it. In select mode
-- it becomes the left-click action (`asDefault`); otherwise it sits below the
-- game's own default entry.
local function addToggleEntry(menu, item, tags, asDefault)
    local originalCount = menu.entryCount
    local active = State.activeCategory
    menu:Add("Bank Tags Pro: " .. toggleVerb(tags) .. active, onToggleSelected, active, item.id, item.name)
    if Config.KEEP_DEFAULT_ACTION and not asDefault then
        keepDefaultActionOnTop(menu, originalCount, 1)
    end
end

-- Shift + right click entries: with a tag selected, a single toggle for it;
-- otherwise one "Tag as ..." line per tag. "Remove all tags" is always there.
local function addTagEntries(menu, item, tags)
    local originalCount = menu.entryCount
    local added = 0
    local active = State.activeCategory

    if Config.COMPACT_MENU_WITH_ACTIVE_TAG and active ~= nil then
        menu:Add("Bank Tags Pro: " .. toggleVerb(tags) .. active, onToggleSelected, active, item.id, item.name)
        added = added + 1
    else
        for _, category in ipairs(Tags.list()) do
            menu:Add("Bank Tags Pro: Tag as " .. category, onTagSelected, category, item.id, item.name)
            added = added + 1
        end
    end
    menu:Add("Bank Tags Pro: Remove all tags", onRemoveAllSelected, item.id, item.name)
    added = added + 1

    if Config.KEEP_DEFAULT_ACTION then
        keepDefaultActionOnTop(menu, originalCount, added)
    end
end

local function addInfoEntry(menu, item, tags)
    local originalCount = menu.entryCount
    local tagText = table.concat(tags, ", ")
    menu:Add("Bank Tags Pro: " .. tagText, onInfoSelected, item.name, tagText)
    if Config.KEEP_DEFAULT_ACTION then
        keepDefaultActionOnTop(menu, originalCount, 1)
    end
end

-- Called every client logic tick while the menu is closed.
function Menu.onMiniMenuReady(event)
    local menu = event.miniMenu
    local shiftDown = Keyboard.IsAvailable() and Keyboard.IsShiftDown()

    local item, component = findTaggableItem(menu.entries)
    if item == nil then
        Outline.hideHover()
        if shiftDown then
            Diagnostics.logMissingItem(menu.entries)
        end
        return
    end

    -- Any hovered item can teach the plugin how to read slots.
    if Config.PERSISTENT_OUTLINES then
        Slots.detectReader(component, item.id)
    end
    if shiftDown then
        Diagnostics.logFoundItem(item, component)
    end
    if not Slots.isTaggable(component) then
        Outline.hideHover()
        return
    end

    local tags = Tags.get(item.id)

    local category = Outline.categoryFor(tags)
    if Config.SHOW_HIGHLIGHT and category ~= nil then
        Outline.showHover(component, category)
    else
        Outline.hideHover()
    end

    if State.selectMode and State.activeCategory ~= nil then
        addToggleEntry(menu, item, tags, true) -- left click toggles the tag
    elseif shiftDown then
        addTagEntries(menu, item, tags)
    elseif Config.SHOW_INFO_ENTRY and #tags > 0 then
        addInfoEntry(menu, item, tags)
    end
end

return Menu
