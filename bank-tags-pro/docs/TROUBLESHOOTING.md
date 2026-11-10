# Troubleshooting

Open the developer console with `ALT` + `` ` `` and, when you need details, set `DEBUG = true` in
`plugin/bank-tags-pro/src/config.lua`, then run `prl bank-tags-pro`.

| Symptom | What to check |
|---|---|
| The plugin is not in `plist` | Run `prf`. Check the path `dev_plugins\bank-tags-pro\main.lua` (no extra folder in between). |
| `Failed to decode metadata at plugin.json ... expected a json Object` | In `plugin.json`, `requiredDependencies` and `optionalDependencies` must be `{}`, not `[]`. Run `prf` afterwards. |
| An error about a syntax problem when enabling | The message includes a file and line. Fix it and run `prl bank-tags-pro`. |
| `[BankTagsPro] ERROR in <name> handler: ...` | A Lua error at run time, printed once per distinct message. Include the full line in a bug report. |
| No tag options on right-click | Tags only apply to items of the bank's own grid. Hold `Shift` before right-clicking. With `DEBUG = true`, check that the hovered item reports `interface 517, static 201`. |
| Items of the backpack get tag options | They should not. Check `Config.SLOT_SOURCES` only has `517 / 201`. |
| The side tab does not appear | Look for `could not create the side tab` or `bank open: ...` in the console (`DEBUG = true`). Check `SHOW_SIDE_TAB = true`. |
| The side tab stays after the bank closes | With `DEBUG = true`, open and close the bank and send the `bank state: ...` and `bank open: ...` lines. |
| The text field has no frame or no text | Look for `input style sheet candidate: ...` or `no input field style sheet found` in the console. |
| Items do not glow when I pick a tag | Hover any item of the bank once so the plugin learns to read slots, then look for `slot items can be read with ...`. If it never appears, send the `slot reader ...` lines (`DEBUG = true`). |
| The outline is shifted | With `DEBUG = true`, hold `Shift` over an item and send the `item ...`, `component type ...`, `ancestor ...` and `outline ... at ...` lines plus a screenshot. |
| Dragging the title bar does nothing | Look for `drag move started ...` (`DEBUG = true`). If it never appears, set `SHOW_LAYOUT_BUTTONS = true` for step buttons and report it. |
| With Select ON, clicking an item does not withdraw it | Expected: in Select mode a click tags the item. Click `Select: ON` to turn it off. |
| The pulsing outline feels heavy | Pick a style without `pulse` with the **Style** button. |
| The panel is cut off | Lower `ROWS_PER_PAGE` in `config.lua`. |
| Too many console lines | Set `DEBUG = false`. |
