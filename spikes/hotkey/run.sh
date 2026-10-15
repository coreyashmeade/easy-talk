#!/bin/zsh
# Build, bundle, sign and launch the hotkey spike. Log: ~/Library/Logs/EasyTalkHotkeySpike.log
set -e
cd "$(dirname "$0")"
swift build -c release
APP=HotkeySpike.app
rm -rf $APP && mkdir -p $APP/Contents/MacOS
cp .build/release/HotkeySpike $APP/Contents/MacOS/
cat > $APP/Contents/Info.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.coreyashmeade.easytalk.hotkeyspike</string>
<key>CFBundleExecutable</key><string>HotkeySpike</string><key>CFBundleName</key><string>Easy Talk Hotkey Test</string>
<key>CFBundlePackageType</key><string>APPL</string><key>LSUIElement</key><true/><key>LSMinimumSystemVersion</key><string>26.0</string>
</dict></plist>
PLIST
codesign --force --options runtime --sign "${SIGN_IDENTITY:-Apple Development}" $APP
pkill -x HotkeySpike && sleep 1 || true
open $APP
echo "Launched. Log: ~/Library/Logs/EasyTalkHotkeySpike.log"
