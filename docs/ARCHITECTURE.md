# Architecture

The plugin is split into small Lua modules under `plugin/bank-tags-pro/src/`, loaded with the
client's `require` (path relative to the plugin folder, no extension: `require("src/tags")`).
`main.lua` only wires them to the client events. Each module returns a table of functions.

## Modules

| Module | Responsibility | Depends on |
|---|---|---|
| `config.lua` | Every user-editable setting (no logic) | - |
| `util.lua` | `debugLog`, `say`, `readProp`, `guarded` (error guard for event handlers) | config |
| `state.lua` | Shared runtime state (`activeCategory`, `selectMode`, `outlinesDirty`, `tick`) and the change notification (`onChange` / `notify`) | - |
| `colours.lua` | Colour of each tag (saved palette index) | config |
| `style.lua` | Outline style (thickness / pulse) and its persistence | config |
| `layout.lua` | Side tab offset and scale and their persistence | config |
| `tags.lua` | Tags of an item, the tag list, add / remove tags (all in `PersistentDB`) | config, state, colours |
| `geometry.lua` | Scroll offsets and visibility checks for UI components | util |
| `outline.lua` | Drawing the outlines: hover outline, pool for the always-on ones, pulse | util, state, tags, colours, style, geometry |
| `slots.lua` | Which slots are taggable, reading the item of a slot, always-on outlines | config, util, state, tags, colours, outline, geometry |
| `bank.lua` | "Is the bank really open?" from several visibility signals | config, util, geometry |
| `drag.lua` | Generic mouse dragging (used for move and resize) | util, state |
| `diagnostics.lua` | Debug-only console output about the hovered item | config, util |
| `menu.lua` | Right-click menu entries and the per-tick hover logic | config, util, state, tags, outline, slots, diagnostics |
| `sidetab.lua` | The tab next to the bank: building, updating, dragging, refreshing | config, util, state, tags, colours, style, layout, outline, bank, drag |
| `panel.lua` | The plugin window opened from the ribbon icon | config, state, tags, colours |

There are no circular requires (the client rejects them). Roughly, from the bottom up:

1. `config`, `state` depend on nothing.
2. `util`, `colours`, `style`, `layout` only need `config` (and `util` for helpers).
3. `tags`, `geometry`, `bank`, `drag`, `diagnostics` build on the layers above.
4. `outline` draws using tags, colours, style and geometry; `slots` adds slot reading on top of it.
5. `menu`, `sidetab` and `panel` are the user-facing modules; they only talk to each other through `state`.
6. `main.lua` requires the top modules and registers the client events.

## Events and the tick

`main.lua` subscribes to three client events:

- `Event.MiniMenuReady` -> `Menu.onMiniMenuReady`: runs about 50 times a second while the menu
  is closed. It finds the hovered item, draws the hover outline and adds the plugin's menu entries.
- `Event.Logic` -> `onLogicTick`: advances `State.tick`, ends stale drags, and every
  `Config.PERSISTENT_REFRESH_TICKS` ticks refreshes the side tab and the always-on outlines.
  When tags changed (`State.outlinesDirty`) the outlines are redrawn on the next tick instead.
  If `Event.Logic` does not exist, the menu event drives the same function.
- `Event.ContentLayerReady` -> `Panel.onContentLayerReady`: builds the plugin window.

All handlers are wrapped with `Util.guarded`, which prints a Lua error once instead of once per tick.

## Shared state and notification

Modules never call each other's UI. When something the user can see changes, the code calls
`State.notify(reason)` (reasons: `category`, `select`, `colour`, `style`, `tags`) or one of
`State.setActiveCategory` / `State.setSelectMode`. `notify` marks the outlines dirty and calls the
listeners registered with `State.onChange`: the side tab refreshes its labels and the panel redraws
its list. This keeps `sidetab.lua` and `panel.lua` independent of each other.

## Data stored in `PersistentDB`

| Key | Value |
|---|---|
| `tag_<itemId>` | comma separated tags of one item, e.g. `PvM,Slayer` |
| `taglist` | comma separated list of all tags (`#` means the user deleted them all; a missing key means "use the default tags") |
| `colour_<tag>` | index into `Config.COLOUR_PALETTE` |
| `style_index` | index into `Config.STYLE_PRESETS` |
| `layout_dx`, `layout_dy`, `layout_scale` | offset and size of the side tab |

Tag names cannot contain `,` or `#` because those are the separators.

## How the glow works

1. `Slots.detectReader` learns, the first time you hover an item, which property of a slot component
   returns the item ID (checked against the ID the menu reports for the hovered item).
2. Every refresh, `Slots.refreshOutlines` iterates the dynamic components of the bank grid, reads the
   item of every slot that is fully inside the visible area, and for items with the active tag
   places an outline.
3. Positions: slots report content-space coordinates, so the scroll offset of the grid and its
   ancestors is subtracted (`Geometry.scrollOffsetFrom`) and the plugin layer's own origin is removed.
4. Outlines are one to three nested, unfilled, click-through rectangles on the plugin layer
   (`Outline.set`); a pool of them is reused between refreshes.

## Select mode

While `State.selectMode` is on and a tag is active, `Menu.onMiniMenuReady` adds `Add to / Remove from <tag>`
as the *highest-priority* entry (the client treats the last entry as the left-click action), so a left
click toggles the tag instead of withdrawing the item. It turns off when the tag is cleared or the bank closes.

## Adding a feature

- A new setting: add it to `config.lua` and read it with `Config.NAME`.
- A new piece of persistent data: add its storage to the module that owns the concept (or a new one),
  and `State.notify` when it changes.
- A new button in the tab: create it in `ensure()` of `sidetab.lua`, handle it in a callback above,
  and update its label in `update()` if it reflects state.
- Run `python scripts/check_lua.py plugin/bank-tags-pro` before testing in the client.
