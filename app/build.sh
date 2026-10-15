#!/bin/zsh
# Build, bundle and sign Easy Talk.app. Usage: ./build.sh [--run]
# Signing identity: $SIGN_IDENTITY, default "Apple Development".
set -e
cd "$(dirname "$0")"
xcodebuild -scheme EasyTalk -destination 'platform=macOS' -derivedDataPath .build-xc \
  -skipMacroValidation -skipPackagePluginValidation -configuration Release build | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
P=.build-xc/Build/Products/Release
APP="build/Easy Talk.app"
rm -rf "$APP" && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$P/EasyTalk" "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
for b in "$P"/*.bundle; do cp -R "$b" "$APP/Contents/Resources/"; done
codesign --force --options runtime --entitlements EasyTalk.entitlements \
  --sign "${SIGN_IDENTITY:-Apple Development}" "$APP"
codesign --verify --strict "$APP" && echo "Built and signed: $APP"
if [[ "$1" == "--run" ]]; then
  pkill -x EasyTalk && sleep 1 || true
  open "$APP"
fi
