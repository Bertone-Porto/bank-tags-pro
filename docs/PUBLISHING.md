# Publishing checklist

Notes for sharing the plugin or submitting it for review. The authoritative sources are the
[plugin guidelines](https://developer.runescape.com/rs/submission/guidelines.html),
[good practice](https://developer.runescape.com/rs/submission/goodpractice.html),
[example description](https://developer.runescape.com/rs/submission/example.html) and
[submission process](https://developer.runescape.com/rs/submission/process.html) pages: read them
before submitting, since they may change.

- [ ] `contactEmailAddress` in `plugin/bank-tags-pro/plugin.json` is a real address (a legal requirement).
- [ ] `version` in `plugin.json` matches the release (and `CHANGELOG.md`).
- [ ] `DEBUG = false` in `src/config.lua`.
- [ ] `python scripts/check_lua.py plugin/bank-tags-pro` reports no errors.
- [ ] Tested in the beta client: tag items, side tab, select mode, new/delete tag, colour, style,
      move/resize, plugin window, closing and reopening the bank, `prl`, restart.
- [ ] The description says what the plugin does and that it only draws outlines and adds local menu
      entries (no actions are sent to the server, nothing is moved).
- [ ] Mention that menu customisation is used (the guidelines list it as subject to review), including
      that Select mode makes a left click toggle a tag while it is on.
- [ ] No permissions are requested (`requiredPermissions` / `optionalPermissions` are empty).
- [ ] The repository has a license you are happy with (`LICENSE` ships as MIT with a placeholder name).
