-- tags.lua
-- Everything about tags and the items they are attached to, stored in PersistentDB:
--   "tag_<itemId>"  comma separated tag names of one item, e.g. "PvM,Slayer"
--   "taglist"       comma separated list of all tags ("#" = the user deleted all)
-- Items are identified by their game item ID, so every copy of an item shares its
-- tags. This module has no UI; other modules call it.

local Config = require("src/config")
local State = require("src/state")
local Colours = require("src/colours")

local Tags = {}

local KEY_PREFIX = Config.KEY_PREFIX
local TAG_LIST_KEY = "taglist"
local TAG_LIST_EMPTY = "#"

local function itemKey(itemId)
    return KEY_PREFIX .. tostring(itemId)
end

-- Turns a stored value such as "PvM,Slayer" into { "PvM", "Slayer" }.
function Tags.split(raw)
    local tags = {}
    for category in string.gmatch(raw, "[^,]+") do
        tags[#tags + 1] = category
    end
    return tags
end

-- True if `category` is in the list `tags`.
function Tags.has(tags, category)
    for _, existing in ipairs(tags) do
        if existing == category then
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Tags of one item
---------------------------------------------------------------------------

-- The menu event fires about 50 times per second, so tag lists are cached in
-- memory and the cache entry is dropped whenever that item's tags change.
local itemCache = {}

-- Tags of an item as a list (empty if none). Do not modify the returned table.
function Tags.get(itemId)
    local cached = itemCache[itemId]
    if cached ~= nil then
        return cached
    end
    local raw = PersistentDB:GetString(itemKey(itemId))
    local tags = {}
    if raw then
        tags = Tags.split(raw)
    end
    itemCache[itemId] = tags
    return tags
end

-- Writes the tag list of an item; an empty list deletes the entry. Also asks for
-- an outline redraw. Returns true on success.
function Tags.save(itemId, tags)
    itemCache[itemId] = nil
    State.outlinesDirty = true
    if #tags == 0 then
        return PersistentDB:Delete(itemKey(itemId))
    end
    return PersistentDB:SetString(itemKey(itemId), table.concat(tags, ","))
end

-- Removes every tag from an item. Returns true on success.
function Tags.clear(itemId)
    return Tags.save(itemId, {})
end

-- Adds the tag to the item if it lacks it, removes it otherwise.
-- Returns true on success and whether the item had the tag before.
function Tags.toggle(itemId, category)
    local updated = {}
    local had = false
    for _, existing in ipairs(Tags.get(itemId)) do
        if existing == category then
            had = true
        else
            updated[#updated + 1] = existing
        end
    end
    if not had then
        updated[#updated + 1] = category
    end
    return Tags.save(itemId, updated), had
end

-- Every stored item as an array of { id = itemId, tags = { ... } }.
function Tags.entries()
    local found = {}
    pcall(function()
        PersistentDB:IterateEntries(function(key, value)
            if string.sub(key, 1, #KEY_PREFIX) == KEY_PREFIX and type(value) == "string" then
                local itemId = tonumber(string.sub(key, #KEY_PREFIX + 1))
                if itemId ~= nil then
                    found[#found + 1] = { id = itemId, tags = Tags.split(value) }
                end
            end
            return false -- keep iterating
        end)
    end)
    return found
end

-- IDs of every item that has the tag.
function Tags.itemsWithTag(category)
    local ids = {}
    for _, entry in ipairs(Tags.entries()) do
        if Tags.has(entry.tags, category) then
            ids[#ids + 1] = entry.id
        end
    end
    return ids
end

---------------------------------------------------------------------------
-- The list of tags
---------------------------------------------------------------------------

local listCache = nil

-- All tags in display order. Do not modify the returned table.
function Tags.list()
    if listCache ~= nil then
        return listCache
    end
    local raw = PersistentDB:GetString(TAG_LIST_KEY)
    local list = {}
    if raw == nil then
        for _, name in ipairs(Config.DEFAULT_TAGS) do
            list[#list + 1] = name
        end
    elseif raw ~= TAG_LIST_EMPTY then
        list = Tags.split(raw)
    end
    listCache = list
    return list
end

local function saveList(list)
    listCache = list
    if #list == 0 then
        return PersistentDB:SetString(TAG_LIST_KEY, TAG_LIST_EMPTY)
    end
    return PersistentDB:SetString(TAG_LIST_KEY, table.concat(list, ","))
end

-- Cleans up a typed tag name: no commas or '#', no leading/trailing spaces,
-- single spaces inside, limited length.
function Tags.sanitizeName(raw)
    local name = tostring(raw or "")
    name = (string.gsub(name, "[,#]", ""))
    name = (string.gsub(name, "^%s+", ""))
    name = (string.gsub(name, "%s+$", ""))
    name = (string.gsub(name, "%s+", " "))
    if #name > Config.MAX_TAG_NAME_LENGTH then
        name = (string.gsub(string.sub(name, 1, Config.MAX_TAG_NAME_LENGTH), "%s+$", ""))
    end
    return name
end

-- Creates a tag. Returns true and the final name, or false and the reason.
function Tags.add(raw)
    local name = Tags.sanitizeName(raw)
    if name == "" then
        return false, "Type a name first"
    end
    local list = Tags.list()
    if #list >= Config.MAX_TAGS then
        return false, "Limit: " .. tostring(Config.MAX_TAGS) .. " tags"
    end
    for _, existing in ipairs(list) do
        if string.lower(existing) == string.lower(name) then
            return false, "That tag already exists"
        end
    end

    -- The new tag takes the next colour of the palette.
    local colourIndex = #list % #Config.COLOUR_PALETTE + 1
    local updated = {}
    for _, existing in ipairs(list) do
        updated[#updated + 1] = existing
    end
    updated[#updated + 1] = name
    saveList(updated)
    Colours.assignIndex(name, colourIndex)
    return true, name
end

-- Deletes a tag everywhere: from the list, its saved colour and every item that
-- carries it. Returns how many items it was removed from.
function Tags.remove(name)
    local remaining = {}
    for _, existing in ipairs(Tags.list()) do
        if existing ~= name then
            remaining[#remaining + 1] = existing
        end
    end
    saveList(remaining)
    Colours.forget(name)

    -- Collect first, change afterwards: never edit entries while iterating them.
    local affected = {}
    for _, entry in ipairs(Tags.entries()) do
        if Tags.has(entry.tags, name) then
            affected[#affected + 1] = entry
        end
    end
    for _, entry in ipairs(affected) do
        local kept = {}
        for _, tag in ipairs(entry.tags) do
            if tag ~= name then
                kept[#kept + 1] = tag
            end
        end
        Tags.save(entry.id, kept)
    end
    return #affected
end

return Tags
