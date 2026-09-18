# Step 1 implementation plan

Goal: an installable background app that intercepts Cmd+Tab and shows a macOS 26-style app strip.

Require macOS 26 (NSGlassEffectView). Build with `swiftc` (no Xcode app).

## Tasks

1. Bundle layout: `JevCmdTab.app` + `Info.plist` (`LSUIElement`, bundle id `com.pelazas.jevcmdtab`).
   Verify: `make app` writes `.build/JevCmdTab.app`.

2. Accessory `NSApplication` + status item (Quit, Accessibility).
   Verify: `open .build/JevCmdTab.app` shows a menu bar extra, not a dock icon.

3. Catalog regular apps, track MRU via `NSWorkspace.didActivateApplicationNotification`, skip ourselves.
   Verify: `./.build/JevCmdTab.app/Contents/MacOS/JevCmdTab --list` prints names, frontmost first.

4. HUD: `NSGlassEffectView`, icon row, highlight, name label, centered on the screen with the pointer. Icons shrink if the row would exceed ~72% of the display.
   Verify: `JevCmdTab --demo` shows the strip for 3 seconds without the hotkey.

5. Event tap: swallow Cmd+Tab, cycle selection, commit on Command key-up, Escape cancels. Re-enable the tap on timeout.
   Verify: with Accessibility granted, Cmd+Tab shows Jev CmdTab's HUD, not Apple's.

6. `./install.sh` copies to `/Applications` (or `~/Applications`) and launches.
   Verify: `./install.sh` ends with a running `JevCmdTab` process.

## Out of scope

Jev, window lists, clutter ranking, Homebrew, notarization.
