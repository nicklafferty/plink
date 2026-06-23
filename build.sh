#!/bin/zsh
set -euo pipefail

APP_NAME="Plink"
BINARY_NAME="Plink"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$ROOT_DIR/dist"
BUILD_DIR="$ROOT_DIR/.build"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$BUILD_DIR/module-cache"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

swiftc -Osize \
  -parse-as-library \
  -module-cache-path "$BUILD_DIR/module-cache" \
  -framework AppKit \
  -framework ImageIO \
  -framework UniformTypeIdentifiers \
  "$ROOT_DIR/Sources/HEICDrop/main.swift" \
  -o "$MACOS_DIR/$BINARY_NAME"

cp "$ROOT_DIR/App/Info.plist" "$CONTENTS_DIR/Info.plist"
printf "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Generate AppIcon.icns from the 1024×1024 master.
ICON_SRC="$ROOT_DIR/App/AppIcon.png"
if [[ -f "$ICON_SRC" ]]; then
  ICONSET="$(mktemp -d)/AppIcon.iconset"
  mkdir -p "$ICONSET"
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ICON_SRC" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$ICON_SRC" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$RESOURCES_DIR/AppIcon.icns"
  rm -rf "$(dirname "$ICONSET")"
fi

# Sign. With SIGN_IDENTITY set (a "Developer ID Application: …" identity) we sign
# with the hardened runtime + secure timestamp so the app can be notarized.
# Without it, fall back to ad-hoc signing for local development.
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" "$APP_DIR"
  codesign --verify --strict --verbose=1 "$APP_DIR"
  echo "Built $APP_DIR (signed: $SIGN_IDENTITY)"
else
  codesign --force --sign - "$APP_DIR" >/dev/null
  echo "Built $APP_DIR (ad-hoc; set SIGN_IDENTITY to sign with Developer ID)"
fi
