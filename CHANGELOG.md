# Changelog

Versions follow the plugin manifest. Earlier versions were single-file scripts; the code was split
into modules in 0.13.0.

## 0.13.0
- Code split into modules under `src/` (config, util, state, colours, style, layout, tags, geometry,
  outline, slots, bank, drag, diagnostics, menu, sidetab, panel). No intended change in behaviour.
- The plugin window refreshes by itself when tags change.
- Repository files: READMEs (English and Portuguese), docs, changelog, license, packaging and check scripts.

## 0.12.0
- Tag features apply only to the bank's own item grid (`517 / 201`); backpack items get no options or outline.
- Calibration mode and `BANK_INTERFACE_IDS` removed; `DEBUG` is off by default.

## 0.11.1
- Same as 0.11.0 without the experimental tag export / import.

## 0.11.0
- Select mode: left-click items in the bank to add / remove them from the selected tag.
- Compact Shift menu (`Add to / Remove from <tag>`) when a tag is selected.
- Outline styles (thickness 1-3, pulse) and 12 colours.

## 0.10.0
- Move the side tab by dragging its title bar, resize it by dragging the corner square.

## 0.9.0
- More robust "bank is open" detection (size and slot visibility); layout step buttons (now optional).

## 0.8.0
- Create and delete your own tags from the side tab.

## 0.7.0
- Side tab next to the bank with one button per tag; the glow only appears for the selected tag.

## 0.6.0
- Active tag with per-tag colours and a plugin window with previous / next tag buttons.

## 0.5.0
- Always-on outlines on every visible tagged slot (reads the item of each slot).

## 0.4.x
- Coloured outline on the hovered tagged item (with scroll correction in the bank); info line in the menu.

## 0.3.0
- Plugin window listing the items of each category.

## 0.2.0
- Shift + right-click menu entries to tag items, stored per item ID.

## 0.1.0
- First prototype: a window to type item names into category lists.
