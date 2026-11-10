# API notes

What the plugin relies on, and how sure we are about it. "Documented" means it is described in the
[official API docs](https://developer.runescape.com/rs/); "observed" means it was found by testing in
the beta client (client version 951-1 at the time).

## Documented and used

| API | Used for |
|---|---|
| `Event.MiniMenuReady`, `MiniMenu:Add`, `MiniMenu:Swap`, `MiniMenu.entries`, `MiniMenu.entryCount` | adding menu entries |
| `MiniMenuEntry.actionEntryType`, `.componentData.objConfig`, `.componentData.component`, `MiniMenuEntryType.INTERFACE` | finding the hovered item |
| `Keyboard.IsAvailable`, `Keyboard.IsShiftDown` | Shift + right-click |
| `PersistentDB:GetString / SetString / Delete / IterateEntries` | saving tags |
| `ui.Interfaces:GetComponent(interfaceID, staticID)` | the bank root and item grid |
| `ComponentCollection:IterateDynamicComponents` | walking the slots of the grid |
| `Component.xyGlobal / width / height / parent / visible / visibleGlobal / staticID / interfaceID / dynamicID` | positions and visibility |
| `ComponentCollection.scrollable / scrollX / scrollY` | scroll offsets |
| `ui.Rectangle`, `ui.Text`, `ui.Button`, `ui.GroupBox`, `ui.InputField` | the outlines, the tab and the panel |
| `Component:Subscribe(ui.Hook.ONBUTTONPRESSED / ONCONTENTCHANGED / ONHOLD / ONRELEASE)` | buttons, text field, dragging |
| `Component:Destroy`, `component.hidden`, `component.clickthrough` | managing created components |
| `id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP` | the layer outlines and the tab are drawn on |
| `Event.ContentLayerReady`, `"hasRibbonIcon": true` in the manifest | the plugin window |
| `config.Obj.FromID` | item names in the plugin window |
| `require("src/...")` | modules (paths relative to the plugin folder) |

## Observed (not in the docs)

- **Interface IDs.** The bank window is interface `517`, static `2` (root); its scrolling item grid is
  static `201` (about 1920 dynamic slot components); the backpack panel inside the bank is `517 / 15`;
  the normal backpack is `1473 / 5`. They are kept in `Config.SLOT_SOURCES`, `Config.BANK_ROOT` and
  `Config.BANK_GRID`.
- **Reading the item of a slot.** `component.associatedObjectID` returns the item ID of a slot component.
  The docs only name `Sprite:SetAssociatedObject`. `slots.lua` tries it first and keeps other candidate
  names as fallbacks; the first one whose value matches the hovered item is used.
- **Content-space positions.** Slot `xyGlobal` ignores scrolling, so the on-screen position is
  `xyGlobal - scroll offset`. The scroll offset is the sum over the grid and its ancestors.
- **A closed bank stays loaded.** After the bank closes its components still exist and report
  `visibleGlobal = true`. The reliable signal is the root's `width` / `height` dropping to `0`;
  `bank.lua` combines that with visibility and "at least one slot visible".
- **The `visible` flag** passed to the `IterateDynamicComponents` callback is not a reliable
  "on screen" indicator (it was `false` for slots that were on screen); `visibleGlobal` of the
  component is used instead.
- **Manifest.** `requiredDependencies` / `optionalDependencies` must be objects (`{}`), not lists;
  the permission fields are lists.
- **Input fields.** The docs example uses an undefined style sheet name; `sidetab.lua` looks for
  `id.StyleSheet.INPUT_DEFAULT`, then any name containing `INPUT`.

## Assumed (not confirmed)

- `Event.Logic` exists (it appears in third-party plugin docs). If it does not, the menu event drives
  the same tick function.
- The `ONHOLD` hook delivers cursor coordinates either local or global; `drag.lua` detects which at
  the start of each drag.
- Copy/paste inside the client's input field behaves like the chat box.

## Things plugins cannot do (as far as we know)

- Extend the bank's native search box, or hide / show native bank slots (the guidelines forbid
  unhiding built-in components).
- Add a tab to the native bank window; the side tab is a separate plugin-layer window.
- Click, withdraw or move items for the player, or send any action to the server.

## Guidelines checked

The [plugin guidelines](https://developer.runescape.com/rs/submission/guidelines.html) list menu
customisation as subject to review and forbid menu entries that cause actions to be sent to the server.
This plugin's entries only run local code. Select mode replaces the left-click action by a local one
while it is on, and it is opt-in and visible in the tab.
