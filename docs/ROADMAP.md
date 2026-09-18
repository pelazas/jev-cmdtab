# CmdTab roadmap

Replace the system Cmd+Tab HUD with one that looks the same and ranks better.

Apple's switcher cannot be reordered. There is no API for that strip. CmdTab eats Cmd+Tab, suppresses the system HUD, and draws its own. Same hold-Cmd, tap-Tab, row of icons.

## Step 1 — Same HUD, same keys (this release)

Clone the macOS 26 Command-Tab strip:

- Liquid glass panel, icon row, selected name underneath
- Cmd+Tab / Cmd+Shift+Tab / arrows / Escape / release Cmd to switch
- MRU order, current app first, first Tab lands on the previous app
- Menu bar extra so the process can be quit
- One-command install

No Jev. No window mode. If this does not feel like Apple's strip, later steps do not matter.

## Step 2 — Local ranking

Deterministic rules, no model:

- Apps with zero visible windows go to the back (close-without-quit)
- Hidden (Cmd+H) and minimized go to the back
- Finder Desktop / empty Preview / utility windows drop or park last
- Recency is the default sort; dwell time is a small bump
- Freeze the order when Cmd goes down

## Step 3 — Window mode

Default to windows, not apps. App-only mode stays for people who want stock Cmd+Tab behavior. Cmd+` stays Apple's.

## Step 4 — Jev, opt-in

Jev never computes recency. It only scores leftover clutter vs destination given clipboard, titles, and frontmost app. Runs in the background; the keypress reads a cache. Default ranking stays on-device. US API is a setting.

## Step 5 — Ship

Homebrew cask, notarization, icon, screenshot in the README, tuning against a side-by-side photo of Apple's HUD.
