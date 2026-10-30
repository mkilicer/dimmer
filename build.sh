#!/bin/bash
# Builds Dimmer.app (no Xcode needed, Command Line Tools are enough) and installs it to /Applications.
set -euo pipefail
cd "$(dirname "$0")"
APP=build/Dimmer.app
rm -rf build && mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/"
swiftc -O -target arm64-apple-macos13 Sources/*.swift -o "$APP/Contents/MacOS/Dimmer"
codesign --force --sign - "$APP"
if [[ "${1:-}" == "--install" ]]; then
  pkill -x Dimmer || true
  rm -rf /Applications/Dimmer.app && cp -R "$APP" /Applications/
  open /Applications/Dimmer.app
fi
