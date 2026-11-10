-- sidetab.lua
-- The tab next to the bank window: a group box on the plugin layer, placed to the
-- right of the bank (plus the user's offset) and shown only while the bank is open.
--
--   * title bar        drag it to move the tab
--   * one button per tag (the selected one is marked ">>") with a colour square
--   * Colour / Delete  next palette colour for the selected tag / delete it
--                      (press Delete twice: "Sure?")
--   * Select / Style   toggle select mode / next outline style
--   * text field + Add tag   create a tag (Enter also works)
--   * Reset layout     default position and size
--   * corner square    drag it sideways to resize the tab
--
-- The tab is rebuilt on the next tick whenever the tag list or the size changes.
-- SideTab.refresh() is called every few ticks by main.lua.

local Config = require("src/config")
local Util = require("src/util")
local State = require("src/state")
local Tags = require("src/tags")
local Colours = require("src/colours")
local Style = require("src/style")
local Layout = require("src/layout")
local Outline = require("src/outline")
local Bank = require("src/bank")
local Drag = require("src/drag")

local SideTab = {}

local say = Util.say
local debugLog = Util.debugLog

local TAB_PADDING = Config.TAB_PADDING

-- UI state of the tab currently on screen.
local tab = {
    box = nil, names = {}, buttons = {}, swatches = {},
    deleteButton = nil, selectButton = nil, styleButton = nil,
    input = nil, message = nil, pendingMessage = "",
    shown = false, key = nil, failed = false, dirty = false,
    boxX = 0, boxY = 0, baseX = 0, baseY = 0, height = 0,
}

-- Tag waiting for a second press of Delete.
local pendingDelete = nil

---------------------------------------------------------------------------
-- Keeping the labels in sync
---------------------------------------------------------------------------

-- Updates the tag buttons (">>" mark, colour squares) and the Delete / Select /
-- Style labels from the current state.
local function update()
    if tab.box == nil then
        return
    end
    for index, button in ipairs(tab.buttons) do
        local category = tab.names[index]
        if State.activeCategory == category then
            button.label = ">> " .. category
        else
            button.label = category
        end
        local rgb = Colours.get(category)
        tab.swatches[index].colour = Vector4.new(rgb[1], rgb[2], rgb[3], 1.0)
    end
    if tab.deleteButton ~= nil then
        if pendingDelete ~= nil and pendingDelete == State.activeCategory then
            tab.deleteButton.label = "Sure?"
        else
            tab.deleteButton.label = "Delete"
        end
    end
    if tab.selectButton ~= nil then
        if State.selectMode then
            tab.selectButton.label = "Select: ON"
        else
            tab.selectButton.label = "Select: OFF"
        end
    end
    if tab.styleButton ~= nil then
        tab.styleButton.label = "Style: " .. Style.current().label
    end
end

local function setMessage(text)
    if tab.message ~= nil then
        tab.message.content = text
    end
end

-- Any change of the shared state (tag picked, colour, select mode...) refreshes
-- the labels. Picking another tag cancels a pending Delete.
State.onChange(function(reason)
    if reason == "category" then
        pendingDelete = nil
    end
    update()
end)

---------------------------------------------------------------------------
-- Button callbacks
---------------------------------------------------------------------------

-- Selecting the active tag again turns the glow off.
local function toggleCategory(category)
    if State.activeCategory == category then
        State.setActiveCategory(nil)
    else
        State.setActiveCategory(category)
    end
end

local function changeActiveColour()
    if State.activeCategory == nil then
        setMessage("Pick a tag first")
        return
    end
    Colours.cycle(State.activeCategory)
    State.notify("colour")
end

-- Deletes a tag everywhere (list, colour and items); the tab is rebuilt next tick.
local function removeTag(name)
    local affected = Tags.remove(name)
    if State.activeCategory == name then
        State.setActiveCategory(nil)
    end
    tab.dirty = true
    tab.pendingMessage = "Deleted " .. name
    say("Deleted tag " .. name .. " (removed from " .. tostring(affected) .. " item(s))")
end

local function onDeletePressed()
    if State.activeCategory == nil then
        setMessage("Pick a tag first")
        return
    end
    if pendingDelete == State.activeCategory then
        local name = State.activeCategory
        pendingDelete = nil
        removeTag(name)
    else
        pendingDelete = State.activeCategory
        update()
        setMessage("Press Delete again")
    end
end

-- Creates a tag from typed text; the tab is rebuilt on the next tick.
local function submitNewTag(raw)
    local ok, result = Tags.add(raw)
    if ok then
        State.setActiveCategory(result)
        tab.dirty = true
        tab.pendingMessage = "Created " .. result
        say("Created tag " .. result)
    else
        setMessage(result)
    end
end

local function onAddPressed()
    local content = ""
    if tab.input ~= nil then
        content = tab.input.content
    end
    submitNewTag(content)
end

local function onTagFieldChanged(field, cause, _)
    if cause == ui.InputFieldActionResult.SUBMIT then
        submitNewTag(field.content)
    end
end

-- Select mode: while on, left-clicking an item in the bank toggles it in the
-- active tag (the click does not withdraw the item). Off again when the tag is
-- cleared or the bank closes.
local function onSelectPressed()
    if State.activeCategory == nil then
        setMessage("Pick a tag first")
        return
    end
    State.setSelectMode(not State.selectMode)
    if State.selectMode then
        setMessage("Click items to add/remove")
    else
        setMessage("")
    end
end

-- Next outline style (thickness / pulse).
local function onStylePressed()
    Style.cycle()
    State.notify("style")
end

-- Layout buttons (shown only with Config.SHOW_LAYOUT_BUTTONS).
local function nudgeTab(dx, dy)
    Layout.setOffset(Layout.dx + dx, Layout.dy + dy)
    tab.key = nil -- the position is re-applied on the next refresh
end

local function scaleTab(delta)
    Layout.setScale(Layout.scale + delta)
    tab.dirty = true
end

local function resetLayout()
    Layout.reset()
    tab.key = nil
    tab.dirty = true
end

---------------------------------------------------------------------------
-- Dragging the title bar (move) and the corner square (resize)
---------------------------------------------------------------------------

local moveHandlers = {
    onMove = function(rx, ry)
        if tab.box == nil then
            return
        end
        tab.boxX = tab.boxX + rx
        tab.boxY = tab.boxY + ry
        tab.box:SetPos(tab.boxX, tab.boxY)
    end,
    onEnd = function()
        Layout.setOffset(tab.boxX - tab.baseX, tab.boxY - tab.baseY)
        tab.key = nil
        debugLog("tab moved: offset " .. tostring(Layout.dx) .. "," .. tostring(Layout.dy))
    end,
}

-- While resizing, the width changes live; the heights follow when the tab is
-- rebuilt at the end of the drag.
local resizeWidth = 0
local resizeHandlers = {
    onStart = function()
        if tab.box ~= nil then
            resizeWidth = tab.box.width
        end
    end,
    onMove = function(rx)
        if tab.box == nil then
            return
        end
        local minWidth = Config.TAB_BASE_WIDTH * Config.SCALE_MIN
        local maxWidth = Config.TAB_BASE_WIDTH * Config.SCALE_MAX
        resizeWidth = math.min(maxWidth, math.max(minWidth, resizeWidth + rx))
        tab.box:SetSize(math.floor(resizeWidth), tab.height)
    end,
    onEnd = function()
        Layout.setScale(resizeWidth / Config.TAB_BASE_WIDTH)
        tab.dirty = true -- rebuilt on the next tick with the new size
        debugLog("tab resized: scale " .. string.format("%.2f", Layout.scale))
    end,
}

---------------------------------------------------------------------------
-- Building and destroying the tab
---------------------------------------------------------------------------

-- Style sheet for the text field. The docs example uses an undefined name, so
-- look for INPUT_DEFAULT first and otherwise take the first INPUT* entry.
local function findInputStyleSheet()
    local sheets = id.StyleSheet
    local preferred = Util.readProp(sheets, "INPUT_DEFAULT")
    if preferred ~= nil then
        return preferred, "INPUT_DEFAULT"
    end
    local found, foundName = nil, nil
    pcall(function()
        for name, value in pairs(sheets) do
            if type(name) == "string" and string.find(name, "INPUT", 1, true) ~= nil then
                debugLog("  input style sheet candidate: " .. name)
                if found == nil then
                    found, foundName = value, name
                end
            end
        end
    end)
    return found, foundName
end

local function destroy()
    Drag.cancel()
    if tab.box ~= nil then
        pcall(function() tab.box:Destroy() end)
    end
    tab.box = nil
    tab.names = {}
    tab.buttons = {}
    tab.swatches = {}
    tab.deleteButton = nil
    tab.selectButton = nil
    tab.styleButton = nil
    tab.input = nil
    tab.message = nil
    tab.shown = false
    tab.key = nil
end

-- Creates the tab (for the current tag list and size) the first time the bank is
-- seen open, and again after the tag list or the size changes.
-- Returns true if it is ready.
local function ensure()
    if tab.box ~= nil then
        return true
    end
    if tab.failed or not Outline.ensure() then
        return false
    end

    local box = nil
    local ok, err = pcall(function()
        local width = Layout.scaled(Config.TAB_BASE_WIDTH)
        local buttonHeight = Layout.scaled(Config.TAB_BASE_BUTTON_HEIGHT)
        local inputHeight = Layout.scaled(Config.TAB_BASE_INPUT_HEIGHT)
        local messageHeight = Layout.scaled(Config.TAB_BASE_MESSAGE_HEIGHT)
        local step = buttonHeight + 4
        local tags = Tags.list()

        -- Rows from top to bottom.
        local titleY = TAB_PADDING
        local layoutButtonsY = titleY + step
        local firstTagY = titleY + step
        if Config.SHOW_LAYOUT_BUTTONS then
            firstTagY = firstTagY + step
        end
        local colourY = firstTagY + #tags * step
        local selectY = colourY + step
        local inputY = selectY + step
        local addY = inputY + inputHeight + 4
        local resetY = addY + step
        local messageY = resetY + step
        local height = messageY + messageHeight + TAB_PADDING + 8 -- room for the resize square

        box = ui.GroupBox.new(Outline.layer())
        box.stylesheetID = id.StyleSheet.DEFAULT
        box:SetHeaderLayout(0, 0, 0, 0, 0)
        box:SetSize(width, height)
        box.hidden = true

        local function makeButton(label, onPress)
            local button = ui.Button.new(box)
            button.stylesheetID = id.StyleSheet.BUTTON_DEFAULT
            button.label = label
            button:Subscribe(ui.Hook.ONBUTTONPRESSED, onPress)
            return button
        end

        -- Title bar: drag it to move the tab.
        local titleBar = ui.Rectangle.new(box)
        titleBar.fill = true
        titleBar.colour = Vector4.new(0.12, 0.2, 0.32, 1.0)
        titleBar:SetPos(TAB_PADDING, titleY)
        titleBar:SetSize(-(TAB_PADDING * 2), buttonHeight, 1.0, 0.0)
        local titleText = ui.Text.new(box)
        titleText:SetPos(TAB_PADDING, titleY + 4)
        titleText:SetSize(-(TAB_PADDING * 2), buttonHeight - 4, 1.0, 0.0)
        titleText.content = "Bank Tags Pro"
        titleText.font = id.Font.MUSEO_SANS_15PT_REGULAR
        titleText:AlignTo(ui.AlignMode.CENTRE)
        pcall(function() titleText.clickthrough = true end) -- let the bar get the mouse
        Drag.attach(titleBar, "move", moveHandlers)

        -- Optional fallback row: move left/right/up/down, smaller, larger.
        if Config.SHOW_LAYOUT_BUTTONS then
            local layoutButtons = {
                { "<", function() nudgeTab(-Config.LAYOUT_STEP, 0) end },
                { ">", function() nudgeTab(Config.LAYOUT_STEP, 0) end },
                { "^", function() nudgeTab(0, -Config.LAYOUT_STEP) end },
                { "v", function() nudgeTab(0, Config.LAYOUT_STEP) end },
                { "-", function() scaleTab(-Config.SCALE_STEP) end },
                { "+", function() scaleTab(Config.SCALE_STEP) end },
            }
            for index, entry in ipairs(layoutButtons) do
                local button = makeButton(entry[1], entry[2])
                button:SetPos(2, layoutButtonsY, (index - 1) / #layoutButtons, 0.0)
                button:SetSize(-4, buttonHeight, 1.0 / #layoutButtons, 0.0)
            end
        end

        -- One button and colour square per tag.
        local names, buttons, swatches = {}, {}, {}
        for index, category in ipairs(tags) do
            local y = firstTagY + (index - 1) * step

            local button = makeButton(category, function() toggleCategory(category) end)
            button:SetPos(TAB_PADDING, y)
            button:SetSize(-(TAB_PADDING * 2) - 12, buttonHeight, 1.0, 0.0)

            local swatch = ui.Rectangle.new(box)
            swatch.fill = true
            swatch:SetPos(-(TAB_PADDING + 8), y + 4, 1.0, 0.0)
            swatch:SetSize(8, buttonHeight - 8)

            names[index], buttons[index], swatches[index] = category, button, swatch
        end

        -- Colour and Delete, side by side.
        local colourButton = makeButton("Colour", changeActiveColour)
        colourButton:SetPos(TAB_PADDING, colourY)
        colourButton:SetSize(-TAB_PADDING - 2, buttonHeight, 0.5, 0.0)

        local deleteButton = makeButton("Delete", onDeletePressed)
        deleteButton:SetPos(2, colourY, 0.5, 0.0)
        deleteButton:SetSize(-TAB_PADDING - 2, buttonHeight, 0.5, 0.0)

        -- Select mode and outline style, side by side.
        local selectButton = makeButton("Select: OFF", onSelectPressed)
        selectButton:SetPos(TAB_PADDING, selectY)
        selectButton:SetSize(-TAB_PADDING - 2, buttonHeight, 0.5, 0.0)

        local styleButton = makeButton("Style", onStylePressed)
        styleButton:SetPos(2, selectY, 0.5, 0.0)
        styleButton:SetSize(-TAB_PADDING - 2, buttonHeight, 0.5, 0.0)

        -- Text field for a new tag name.
        local inputSheet = findInputStyleSheet()
        if inputSheet == nil then
            say("no input field style sheet found; the text field may look unstyled.")
        end
        local input = ui.InputField.new(box)
        if inputSheet ~= nil then
            input.stylesheetID = inputSheet
        else
            pcall(function() input.text.font = id.Font.MUSEO_SANS_15PT_REGULAR end)
        end
        input:Setup(ui.TextContentVisibilityMode.VISIBLE, ui.InputFieldFilterMode.NONE, Config.MAX_TAG_NAME_LENGTH)
        input.emptyText = "New tag name"
        input:SetPos(TAB_PADDING, inputY)
        input:SetSize(-(TAB_PADDING * 2), inputHeight, 1.0, 0.0)
        input:Subscribe(ui.Hook.ONCONTENTCHANGED, onTagFieldChanged)

        local addButton = makeButton("Add tag", onAddPressed)
        addButton:SetPos(TAB_PADDING, addY)
        addButton:SetSize(-(TAB_PADDING * 2), buttonHeight, 1.0, 0.0)

        local resetButton = makeButton("Reset layout", resetLayout)
        resetButton:SetPos(TAB_PADDING, resetY)
        resetButton:SetSize(-(TAB_PADDING * 2), buttonHeight, 1.0, 0.0)

        local message = ui.Text.new(box)
        message:SetPos(TAB_PADDING, messageY)
        message:SetSize(-(TAB_PADDING * 2), messageHeight, 1.0, 0.0)
        message.content = tab.pendingMessage
        message.font = id.Font.MUSEO_SANS_15PT_REGULAR
        message:AlignTo(ui.AlignMode.CENTRE)

        -- Resize square in the bottom-right corner: drag it sideways to resize.
        local grip = ui.Rectangle.new(box)
        grip.fill = true
        grip.colour = Vector4.new(0.7, 0.7, 0.75, 1.0)
        grip:SetPos(-16, -16, 1.0, 1.0)
        grip:SetSize(12, 12)
        Drag.attach(grip, "resize", resizeHandlers)
        pcall(function() grip:MoveToFront() end)

        tab.names, tab.buttons, tab.swatches = names, buttons, swatches
        tab.deleteButton, tab.input, tab.message = deleteButton, input, message
        tab.selectButton, tab.styleButton = selectButton, styleButton
        tab.height = height
        tab.box = box
        debugLog("side tab built: " .. tostring(#tags) .. " tag(s), scale " .. string.format("%.2f", Layout.scale))
    end)
    tab.pendingMessage = ""

    if not ok then
        tab.failed = true
        tab.box = nil
        if box ~= nil then
            pcall(function() box:Destroy() end)
        end
        say("ERROR: could not create the side tab: " .. tostring(err))
        return false
    end
    update()
    return true
end

local function hide()
    if tab.box ~= nil and tab.shown then
        tab.box.hidden = true
        tab.shown = false
        tab.key = nil
    end
end

---------------------------------------------------------------------------
-- Refresh (called every few ticks)
---------------------------------------------------------------------------

-- Shows the tab beside the bank while it is open and hides it otherwise.
function SideTab.refresh()
    if not Config.SHOW_SIDE_TAB then
        return
    end

    if tab.dirty then
        tab.dirty = false
        destroy() -- rebuilt below, now that no button callback is running
    end

    local root = Bank.root()
    if not Bank.isOpen(root) then
        hide()
        if Config.RESET_ON_BANK_CLOSE and State.activeCategory ~= nil then
            State.setActiveCategory(nil)
        elseif State.selectMode then
            State.setSelectMode(false) -- never leave clicks hijacked while the bank is closed
        end
        return
    end
    if not ensure() then
        return
    end

    -- Default spot: just right of the bank window, plus the user's offset.
    local position = root.xyGlobal
    local origin = Outline.layer().xyGlobal
    local x = math.floor(position.x - origin.x + root.width + Config.TAB_GAP + Layout.dx)
    local y = math.floor(position.y - origin.y + Layout.dy)
    local key = tostring(x) .. ":" .. tostring(y)
    tab.baseX = x - Layout.dx
    tab.baseY = y - Layout.dy
    if not Drag.isActive() and key ~= tab.key then
        tab.box:SetPos(x, y)
        tab.boxX, tab.boxY = x, y
        tab.key = key
    end
    if not tab.shown then
        tab.box.hidden = false
        tab.shown = true
        debugLog("side tab shown at " .. tostring(x) .. "," .. tostring(y))
    end
end

return SideTab
