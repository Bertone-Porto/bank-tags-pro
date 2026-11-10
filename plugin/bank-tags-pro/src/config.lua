-- config.lua
-- Every setting of Bank Tags Pro lives here. Edit a value, then reload the plugin
-- in the developer console with: prl bank-tags-pro
--
-- The other modules only read these values; nothing here runs any logic.

local Config = {}

---------------------------------------------------------------------------
-- General
---------------------------------------------------------------------------

-- Prefix of every line the plugin prints to the developer console.
Config.LOG_PREFIX = "[BankTagsPro] "

-- Print diagnostic lines (hover details, bank state, outline positions...).
-- Leave off normally; turn on when something does not behave and you want logs.
Config.DEBUG = false

---------------------------------------------------------------------------
-- Tags
---------------------------------------------------------------------------

-- Tags a new install starts with. After the first change the tag list is stored
-- in PersistentDB and these are only the starting point.
Config.DEFAULT_TAGS = { "PvM", "Slayer", "Skilling", "Clues", "Quests" }

-- Limits for tags created in the side tab.
Config.MAX_TAGS = 12
Config.MAX_TAG_NAME_LENGTH = 20

-- PersistentDB key prefixes. One key per item ID ("tag_4151" = "PvM,Slayer") and
-- one per tag colour ("colour_Clues" = palette index).
Config.KEY_PREFIX = "tag_"
Config.COLOUR_KEY_PREFIX = "colour_"

---------------------------------------------------------------------------
-- Colours and outline styles
---------------------------------------------------------------------------

-- Default colour of the starting tags as { red, green, blue } in the 0..1 range.
-- A colour picked with the Colour button replaces it.
Config.CATEGORY_COLOURS = {
    PvM      = { 0.0, 1.0, 0.0 },   -- green
    Slayer   = { 1.0, 0.2, 0.2 },   -- red
    Skilling = { 0.2, 0.6, 1.0 },   -- blue
    Clues    = { 1.0, 0.85, 0.0 },  -- yellow
    Quests   = { 0.8, 0.4, 1.0 },   -- purple
}
Config.DEFAULT_COLOUR = { 1.0, 1.0, 1.0 }

-- Colours the Colour button cycles through (new tags take them in order).
Config.COLOUR_PALETTE = {
    { 0.2, 0.6, 1.0 },   -- blue
    { 0.0, 1.0, 0.0 },   -- green
    { 1.0, 0.2, 0.2 },   -- red
    { 1.0, 0.85, 0.0 },  -- yellow
    { 0.8, 0.4, 1.0 },   -- purple
    { 1.0, 0.55, 0.0 },  -- orange
    { 0.0, 0.9, 0.9 },   -- cyan
    { 1.0, 1.0, 1.0 },   -- white
    { 1.0, 0.45, 0.75 }, -- pink
    { 0.65, 1.0, 0.2 },  -- lime
    { 0.6, 0.4, 0.2 },   -- brown
    { 0.6, 0.6, 0.65 },  -- grey
}

-- Outline styles the Style button cycles through: how many nested rectangles
-- (thickness) and whether the outline pulses.
Config.STYLE_PRESETS = {
    { thickness = 1, pulse = false, label = "1" },
    { thickness = 2, pulse = false, label = "2" },
    { thickness = 3, pulse = false, label = "3" },
    { thickness = 2, pulse = true,  label = "2 pulse" },
    { thickness = 3, pulse = true,  label = "3 pulse" },
}
Config.DEFAULT_STYLE_INDEX = 2

---------------------------------------------------------------------------
-- Where the tag features apply
---------------------------------------------------------------------------

-- The item slots that get every tag feature (hover outline, menu entries, select
-- mode and always-on outlines): { interfaceID, staticID }. Taken from the debug
-- log: 517 / 201 is the bank's scrolling item grid. The backpack (1473 / 5) and
-- the backpack panel inside the bank (517 / 15) are deliberately left out, so
-- items there get no tag options and no outline. Add a line to include more.
Config.SLOT_SOURCES = {
    { interfaceID = 517, staticID = 201 },
}

-- The bank window's root component (debug log: interface 517, static 2). The
-- side tab is placed to the right of it.
Config.BANK_ROOT = { interfaceID = 517, staticID = 2 }

-- The bank's item grid. The bank counts as open only while the root and this
-- grid are both visible.
Config.BANK_GRID = { interfaceID = 517, staticID = 201 }

---------------------------------------------------------------------------
-- Menu behaviour
---------------------------------------------------------------------------

-- Draw a coloured outline around the hovered item when it has the active tag.
Config.SHOW_HIGHLIGHT = true

-- Add an info entry ("Bank Tags Pro: PvM, Slayer") on a plain right click.
Config.SHOW_INFO_ENTRY = true

-- With a tag selected in the tab, the Shift menu shows one "Add to / Remove from"
-- entry for that tag (plus "Remove all tags") instead of a "Tag as ..." line per tag.
Config.COMPACT_MENU_WITH_ACTIVE_TAG = true

-- MiniMenu:Add puts new entries at the end of the list, which the API defines
-- as the HIGHEST priority (the entry used by a plain left click). When true, the
-- plugin swaps the game's own top entry back to the end so left clicks still do
-- what the game normally does. (Select mode deliberately skips this.)
Config.KEEP_DEFAULT_ACTION = true

---------------------------------------------------------------------------
-- Always-on outlines
---------------------------------------------------------------------------

-- Keep the outline on every visible item of the active tag (not only the hovered
-- one). The plugin learns how to read an item from a slot the first time you
-- hover an item.
Config.PERSISTENT_OUTLINES = true

-- How often the outlines are refreshed, in client logic ticks.
Config.PERSISTENT_REFRESH_TICKS = 10

-- Most outlines drawn at once.
Config.MAX_OUTLINES = 100

---------------------------------------------------------------------------
-- Side tab (next to the bank)
---------------------------------------------------------------------------

-- Show the tab with the tag buttons while the bank is open.
Config.SHOW_SIDE_TAB = true

-- Turn the glow (and Select mode) off whenever the bank closes.
Config.RESET_ON_BANK_CLOSE = true

-- Base sizes in interface units; the tab's scale setting multiplies them.
Config.TAB_BASE_WIDTH = 150
Config.TAB_BASE_BUTTON_HEIGHT = 26
Config.TAB_BASE_INPUT_HEIGHT = 28
Config.TAB_BASE_MESSAGE_HEIGHT = 36
Config.TAB_GAP = 6
Config.TAB_PADDING = 6

-- Resize limits (multiplier of the base size).
Config.SCALE_MIN = 0.7
Config.SCALE_MAX = 2.0

-- Dragging the title bar moves the tab and the corner square resizes it. Set this
-- to true to also show six step buttons (< > ^ v - +), a fallback in case
-- dragging does not work on your setup.
Config.SHOW_LAYOUT_BUTTONS = false
Config.LAYOUT_STEP = 20
Config.SCALE_STEP = 0.1

---------------------------------------------------------------------------
-- Panel (plugin window opened from the ribbon icon)
---------------------------------------------------------------------------

-- Items listed per page; lower it if the panel window is short.
Config.ROWS_PER_PAGE = 8
Config.PANEL_ROW_HEIGHT = 20
Config.PANEL_BUTTON_HEIGHT = 30
Config.PANEL_FOOTER_HEIGHT = 30

return Config
