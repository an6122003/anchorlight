#!/bin/bash
# Regenerates docs/images from scripts/make-readme-art.swift.
# PNGs are converted to WebP when cwebp is available: the gradients that make
# the artwork look good compress badly as PNG (≈19 MB → ≈0.6 MB).
set -euo pipefail
cd "$(dirname "$0")/.."

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

swiftc -O -o "$WORK/art" scripts/make-readme-art.swift
"$WORK/art" "$WORK" Resources/AppIcon.icns >/dev/null

mkdir -p docs/images
cp "$WORK/icon.png" docs/images/icon.png
for png in "$WORK"/*.png; do
	name="$(basename "$png" .png)"
	[[ "$name" == "icon" ]] && continue
	if command -v cwebp >/dev/null; then
		cwebp -quiet -q 90 -m 6 -sharp_yuv "$png" -o "docs/images/$name.webp"
	else
		cp "$png" "docs/images/$name.png"
	fi
done
du -sh docs/images
