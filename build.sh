#!/bin/bash
# Builds Anchorlight.app into ./build (no Xcode project needed).
#
#   ./build.sh              host architecture only (fast, for development)
#   ./build.sh --universal  arm64 + x86_64 universal binary (for distribution)
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Anchorlight"
APP="build/$APP_NAME.app"
SOURCES=(Sources/PowerSleep.swift Sources/GlobalHotKey.swift Sources/HUD.swift Sources/AppDelegate.swift Sources/main.swift)
DEPLOYMENT_TARGET="13.0"

if [[ "${1:-}" == "--universal" ]]; then
	ARCHS=(arm64 x86_64)
else
	ARCHS=("$(uname -m)")
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

SLICES=()
for arch in "${ARCHS[@]}"; do
	echo "Compiling $arch…"
	slice="build/$APP_NAME-$arch"
	swiftc -O \
		-target "${arch}-apple-macos${DEPLOYMENT_TARGET}" \
		-o "$slice" \
		"${SOURCES[@]}"
	SLICES+=("$slice")
done

if [[ ${#SLICES[@]} -gt 1 ]]; then
	lipo -create -output "$APP/Contents/MacOS/$APP_NAME" "${SLICES[@]}"
else
	mv "${SLICES[0]}" "$APP/Contents/MacOS/$APP_NAME"
fi
rm -f "${SLICES[@]}"

# Use a Developer ID certificate when one exists, otherwise sign ad-hoc.
IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"' || true)"
if [[ -n "$IDENTITY" ]]; then
	echo "Signing with: $IDENTITY"
	codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$APP"
else
	echo "No Developer ID found — signing ad-hoc."
	codesign --force --sign - "$APP"
fi

codesign --verify --strict "$APP"
echo "Built $APP ($(lipo -archs "$APP/Contents/MacOS/$APP_NAME"))"
