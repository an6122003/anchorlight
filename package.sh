#!/bin/bash
# Produces a distributable Anchorlight: dist/Anchorlight-<version>.dmg and .zip
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Anchorlight"
APP="build/$APP_NAME.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
DIST="dist"
DMG="$DIST/$APP_NAME-$VERSION.dmg"
ZIP="$DIST/$APP_NAME-$VERSION.zip"

./build.sh --universal

rm -rf "$DIST"
mkdir -p "$DIST"

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

cat > "$STAGING/Read Me First.txt" <<'NOTE'
Anchorlight
==========

1. Drag Anchorlight.app onto the Applications folder in this window.
2. Open it. A cup/moon icon appears in the menu bar — there is no Dock icon
   and no window; everything lives in that menu.

   Moon         = the Mac sleeps normally when you close the lid
   Cup + AWAKE  = the Mac stays awake with the lid closed

Press Control-Option-Command-S anywhere to switch between the two. A panel
appears confirming the new state, so this works even if your menu bar is full
and the icon is hidden behind the notch.

First launch
------------
This app is not notarized by Apple, so macOS will refuse the first launch and
say it cannot check it for malicious software. To allow it:

   System Settings > Privacy & Security > scroll down > "Open Anyway"

Or, in Terminal:

   xattr -dr com.apple.quarantine /Applications/Anchorlight.app

Toggling the setting needs an administrator password, because it runs
`pmset -a disablesleep 0|1` as root. macOS will prompt you each time.
The project's scripts/install-sudoers.sh makes it passwordless if you prefer.
NOTE

hdiutil create \
	-volname "$APP_NAME" \
	-srcfolder "$STAGING" \
	-fs HFS+ \
	-format UDZO \
	-ov \
	"$DMG" >/dev/null

ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo
echo "Version $VERSION  ($(lipo -archs "$APP/Contents/MacOS/$APP_NAME"))"
ls -lh "$DMG" "$ZIP" | awk '{print "  " $9 "  " $5}'
echo
shasum -a 256 "$DMG" "$ZIP"
