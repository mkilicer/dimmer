#!/bin/bash
# Builds build/Dimmer.app and build/Dimmer.zip (Command Line Tools are enough, no Xcode).
# --install also copies it to /Applications and starts it.
set -euo pipefail
cd "$(dirname "$0")"
APP=build/Dimmer.app
rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/"
cp -R Resources/ "$APP/Contents/Resources/"
swiftc -O -target arm64-apple-macos13 Sources/*.swift -o "$APP/Contents/MacOS/Dimmer"
codesign --force --sign - "$APP"
(cd build && ditto -c -k --keepParent Dimmer.app Dimmer.zip)
if [[ "${1:-}" == "--install" ]]; then
  pkill -x Dimmer || true
  rm -rf /Applications/Dimmer.app && cp -R "$APP" /Applications/
  open /Applications/Dimmer.app
fi
