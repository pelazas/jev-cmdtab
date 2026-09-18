# jev-cmdtab

macOS app switcher with Apple's Cmd+Tab HUD. Same strip. Smarter order later.

Requires macOS 26. There is no API to reorder Apple's own switcher, so Jev CmdTab intercepts Cmd+Tab and draws the same kind of panel.

## Install

```bash
git clone https://github.com/pelazas/jev-cmdtab.git
cd jev-cmdtab
./install.sh
```

Then: System Settings → Privacy & Security → Accessibility → enable **Jev CmdTab**. After every rebuild, toggle it off and on. Ad-hoc signing looks like a new app to macOS.

Press Cmd+Tab. The menu extra should say **Cmd+Tab intercept is on**. Parked apps (Finder with only the desktop, hidden, close-without-quit) sit at the right and look faded. If every other app has a real window, only those move.

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
