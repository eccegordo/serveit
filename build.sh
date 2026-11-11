#!/bin/bash
# Builds ServeIt and packages it as build/ServeIt.app
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="build/ServeIt.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp "$(swift build -c release --show-bin-path)/ServeIt" "$APP/Contents/MacOS/ServeIt"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null

echo "Built $APP"
