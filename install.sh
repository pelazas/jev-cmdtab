#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
make app
if [ -w /Applications ]; then
  DEST=/Applications
else
  DEST="$HOME/Applications"
  mkdir -p "$DEST"
fi
killall CmdTab JevCmdTab 2>/dev/null || true
rm -rf "$DEST/CmdTab.app" "$DEST/JevCmdTab.app"
cp -R .build/JevCmdTab.app "$DEST/JevCmdTab.app"
open "$DEST/JevCmdTab.app"
echo "Installed $DEST/JevCmdTab.app"
echo "Enable Jev CmdTab in System Settings → Privacy & Security → Accessibility, then press Cmd+Tab."
