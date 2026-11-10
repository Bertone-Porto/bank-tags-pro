-- panel.lua
-- The plugin's own window (opened from its ribbon icon in the client's plugin
-- window): shows one tag at a time with its colour and lists the items that carry
-- it, paged. The "<" and ">" buttons move to the previous / next tag and make
-- that tag glow in the bank, like picking it in the side tab. The list is
-- read-only: it never changes tags or touches the bank.

local Config = require("src/config")
local State = require("src/state")
local Tags = require("src/tags")
local Colours = require("src/colours")

local Panel = {}

local ROWS_PER_PAGE = Config.ROWS_PER_PAGE
local ROW_HEIGHT = Config.PANEL_ROW_HEIGHT
local BUTTON_HEIGHT = Config.PANEL_BUTTON_HEIGHT
local FOOTER_HEIGHT = Config.PANEL_FOOTER_HEIGHT
local CONTROLS_Y = BUTTON_HEIGHT + 4
local STATUS_Y = CONTROLS_Y + BUTTON_HEIGHT + 4
local HEADER_Y = STATUS_Y + 22
local ROWS_Y = HEADER_Y + 26

-- State of the panel currently on screen.
local panel = {
    root = nil, header = nil, status = nil, swatch = nil, tagName = nil,
    rows = {}, category = nil, page = 1,
}

-- Item name from the game config; falls back to the ID if the lookup fails.
local function displayName(itemId)
    local ok, objConfig = pcall(function() return config.Obj.FromID(itemId) end)
    if ok and objConfig ~= nil and objConfig.name ~= nil then
        return objConfig.name
    end
    return "Item " .. tostring(itemId)
end

-- Items that carry `category`, sorted by name: { { id = ..., name = ... }, ... }.
local function collectItems(category)
    local items = {}
    for _, itemId in ipairs(Tags.itemsWithTag(category)) do
        items[#items + 1] = { id = itemId, name = displayName(itemId) }
    end
    table.sort(items, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
    return items
end

-- Creates a centred line of text under `parent`.
local function createText(parent, content, y, height)
    local text = ui.Text.new(parent)
    text:SetPos(0, y)
    text:SetSize(0, height, 1.0, 0.0)
    text.content = content
    text.font = id.Font.MUSEO_SANS_15PT_REGULAR
    text:AlignTo(ui.AlignMode.CENTRE)
    return text
end

-- Creates a standard button under the panel root.
local function createButton(label, onPress)
    local button = ui.Button.new(panel.root)
    button.label = label
    button.stylesheetID = id.StyleSheet.BUTTON_DEFAULT
    button:Subscribe(ui.Hook.ONBUTTONPRESSED, onPress)
    return button
end

-- Rebuilds the status line, colour swatch, header line and item rows.
local function refreshList()
    for _, row in ipairs(panel.rows) do
        row:Destroy()
    end
    panel.rows = {}

    if State.activeCategory ~= nil then
        panel.status.content = "Glowing in the bank: " .. State.activeCategory
    else
        panel.status.content = "Glow off"
    end

    -- Keep the listed tag valid: it may have been deleted in the side tab.
    local tagList = Tags.list()
    local stillExists = false
    for _, name in ipairs(tagList) do
        if name == panel.category then
            stillExists = true
        end
    end
    if not stillExists then
        panel.category = tagList[1]
        panel.page = 1
    end

    if panel.category == nil then
        panel.tagName.content = "No tags"
        panel.header.content = "Create one in the side tab next to the bank"
        panel.swatch.colour = Vector4.new(0.0, 0.0, 0.0, 0.0)
        return
    end
    panel.tagName.content = panel.category

    local rgb = Colours.get(panel.category)
    panel.swatch.colour = Vector4.new(rgb[1], rgb[2], rgb[3], 1.0)

    local items = collectItems(panel.category)
    local pageCount = math.max(1, math.ceil(#items / ROWS_PER_PAGE))
    if panel.page > pageCount then
        panel.page = pageCount
    end
    if panel.page < 1 then
        panel.page = 1
    end

    panel.header.content = string.format("%s: %d item(s) - page %d/%d",
        panel.category, #items, panel.page, pageCount)

    local firstIndex = (panel.page - 1) * ROWS_PER_PAGE
    for i = 1, ROWS_PER_PAGE do
        local item = items[firstIndex + i]
        if item == nil then
            break
        end
        local label = item.name .. " (" .. tostring(item.id) .. ")"
        panel.rows[#panel.rows + 1] = createText(panel.root, label, ROWS_Y + (i - 1) * ROW_HEIGHT, ROW_HEIGHT)
    end
end

-- Moves the panel to the previous (-1) or next (+1) tag and selects it.
local function selectPanelTag(offset)
    local tagList = Tags.list()
    if #tagList == 0 then
        return
    end
    local index = 1
    for position, name in ipairs(tagList) do
        if name == panel.category then
            index = position
        end
    end
    index = (index - 1 + offset) % #tagList + 1
    panel.category = tagList[index]
    panel.page = 1
    State.setActiveCategory(panel.category) -- also refreshes this panel
end

-- Called each time the plugin's content layer is shown (the layer starts empty).
function Panel.onContentLayerReady(event)
    panel.root = event.component
    panel.rows = {} -- the layer was cleared, so old rows no longer exist

    -- Top row: previous tag / current tag name / next tag.
    local previousTag = createButton("<", function() selectPanelTag(-1) end)
    previousTag:SetPos(0, 0, 0.0, 0.0)
    previousTag:SetSize(0, BUTTON_HEIGHT, 0.15, 0.0)

    panel.tagName = ui.Text.new(panel.root)
    panel.tagName:SetPos(0, 4, 0.15, 0.0)
    panel.tagName:SetSize(0, 24, 0.7, 0.0)
    panel.tagName.content = ""
    panel.tagName.font = id.Font.MUSEO_SANS_15PT_REGULAR
    panel.tagName:AlignTo(ui.AlignMode.CENTRE)

    local nextTag = createButton(">", function() selectPanelTag(1) end)
    nextTag:SetPos(0, 0, 0.85, 0.0)
    nextTag:SetSize(0, BUTTON_HEIGHT, 0.15, 0.0)

    -- Second row: change the listed tag's colour / turn the glow off.
    local colourButton = createButton("Change colour", function()
        if panel.category ~= nil then
            Colours.cycle(panel.category)
        end
        State.notify("colour") -- refreshes this panel and the side tab
    end)
    colourButton:SetPos(0, CONTROLS_Y, 0.0, 0.0)
    colourButton:SetSize(0, BUTTON_HEIGHT, 0.5, 0.0)

    local glowOffButton = createButton("Glow off", function()
        State.setActiveCategory(nil)
    end)
    glowOffButton:SetPos(0, CONTROLS_Y, 0.5, 0.0)
    glowOffButton:SetSize(0, BUTTON_HEIGHT, 0.5, 0.0)

    panel.status = createText(panel.root, "", STATUS_Y, 20)
    panel.header = createText(panel.root, "", HEADER_Y, 24)

    -- Small swatch at the right edge of the header showing the tag colour.
    panel.swatch = ui.Rectangle.new(panel.root)
    panel.swatch.fill = true
    panel.swatch:SetPos(-30, HEADER_Y + 4, 1.0, 0.0)
    panel.swatch:SetSize(24, 16)

    -- Previous / next page buttons along the bottom edge.
    local previous = createButton("Previous", function()
        panel.page = panel.page - 1
        refreshList()
    end)
    previous:SetPos(0, -FOOTER_HEIGHT, 0.0, 1.0)
    previous:SetSize(0, FOOTER_HEIGHT, 0.5, 0.0)

    local nextPage = createButton("Next", function()
        panel.page = panel.page + 1
        refreshList()
    end)
    nextPage:SetPos(0, -FOOTER_HEIGHT, 0.5, 1.0)
    nextPage:SetSize(0, FOOTER_HEIGHT, 0.5, 0.0)

    refreshList()
end

-- Keeps the panel up to date when the selection, a colour or the tags change.
-- Errors are ignored: the panel may have been closed, destroying its components.
State.onChange(function()
    if panel.root ~= nil and panel.status ~= nil then
        pcall(refreshList)
    end
end)

return Panel
