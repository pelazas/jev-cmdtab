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

`JevCmdTab --list` prints the ranked app list (`parked` marks close-without-quit / hidden, `dest` is the Jev pick). `JevCmdTab --demo` shows the strip for three seconds. `JevCmdTab --self-check` runs the ranking tests.

## Jev

Optional. Recency, parked apps, and the current display stay local. Jev only answers "where are you trying to go" from the clipboard.

Copy a TypeSafe API key from [typesafe.ai](https://typesafe.ai/), then menu extra → **Paste TypeSafe API key**. The menu reads `Jev: off` until then, `Jev: idle` when nothing in the clipboard points at an app, or `Jev: Mail` when it has a pick. That app sits next to the current one on the next Cmd+Tab.

The clipboard is sent to TypeSafe in the US. Concealed copy (password managers) is skipped. No key means no network. `TYPESAFE_API_KEY` also works if you launch from a shell.

## Status

HUD, local ranking, same-display switching, and optional Jev destination. Window mode is still later. See [the roadmap](docs/ROADMAP.md).
