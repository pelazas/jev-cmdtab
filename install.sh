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
killall CmdTab 2>/dev/null || true
rm -rf "$DEST/CmdTab.app"
cp -R .build/CmdTab.app "$DEST/CmdTab.app"
open "$DEST/CmdTab.app"
echo "Installed $DEST/CmdTab.app"
echo "Enable CmdTab in System Settings → Privacy & Security → Accessibility, then press Cmd+Tab."
