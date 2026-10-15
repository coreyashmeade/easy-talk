#!/bin/zsh
# Build an ad-hoc signed release of Easy Talk and zip it for GitHub Releases.
# Ad-hoc signing carries no personal developer identity; users approve the app once in System Settings.
# Usage: scripts/package-release.sh [version]
set -e -o pipefail
cd "$(dirname "$0")/.."
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' app/Info.plist)}"
STAGE="$PWD/dist/staging"
SIGN_IDENTITY=- APP_DIR="$STAGE" app/build.sh
ZIP="dist/Easy-Talk-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$STAGE/Easy Talk.app" "$ZIP"
rm -rf "$STAGE"
shasum -a 256 "$ZIP" | tee "$ZIP.sha256"
