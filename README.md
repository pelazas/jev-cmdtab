# jev-cmdtab

macOS app switcher with Apple's Cmd+Tab HUD. Same strip. Smarter order later.

Requires macOS 26. There is no API to reorder Apple's own switcher, so Jev CmdTab intercepts Cmd+Tab and draws the same kind of panel.

## Install

```bash
git clone https://github.com/pelazas/jev-cmdtab.git
cd jev-cmdtab
./install.sh
```

Then: System Settings → Privacy & Security → Accessibility → enable **Jev CmdTab**.

Press Cmd+Tab. You should see Jev CmdTab's glass strip, not Apple's.

Quit from the menu bar extra (left/right arrows icon).

Rebuild and reinstall with the same `./install.sh`. The app lives in `/Applications/JevCmdTab.app` if that folder is writable, otherwise `~/Applications/JevCmdTab.app`.

## Keys

Same as Apple:

- Cmd+Tab — next app
- Cmd+Shift+Tab — previous app
- Left / Right — while the strip is open
- Escape — cancel
- Release Cmd — switch

`JevCmdTab --list` prints the MRU app list. `JevCmdTab --demo` shows the strip for three seconds.

## Status

Step 1 of [the roadmap](docs/ROADMAP.md): HUD + keys + MRU. No Jev ranking yet. Close-without-quit apps still sit in the middle; that is step 2.
