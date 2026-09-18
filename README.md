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

`JevCmdTab --list` prints the ranked app list (`parked` marks close-without-quit / hidden). `JevCmdTab --demo` shows the strip for three seconds. `JevCmdTab --self-check` runs the ranking test.

## Status

Step 2 of [the roadmap](docs/ROADMAP.md): HUD + local ranking. Close-without-quit, hidden, and empty Finder/Preview sit at the back. The list freezes while you hold Cmd. Jev is not wired yet.
