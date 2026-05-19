#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="release"
PRODUCT_NAME="LightPetDesktop"
APP_NAME="LightPet"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE_PATH="$MACOS_DIR/$PRODUCT_NAME"
ICON_PATH="$ROOT_DIR/Assets/AppIcon.icns"

if [[ -e "$APP_DIR" ]]; then
  echo "error: $APP_DIR already exists. Move or remove it before packaging." >&2
  exit 2
fi

if [[ ! -f "$ICON_PATH" ]]; then
  echo "error: missing app icon at $ICON_PATH" >&2
  exit 2
fi

cd "$ROOT_DIR"

swift build -c "$CONFIGURATION" --product "$PRODUCT_NAME"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp ".build/$CONFIGURATION/$PRODUCT_NAME" "$EXECUTABLE_PATH"
chmod 755 "$EXECUTABLE_PATH"
cp "$ICON_PATH" "$RESOURCES_DIR/AppIcon.icns"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$PRODUCT_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>local.lightpet.desktop</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "Packaged $APP_DIR"
echo "Pets are read from \${CODEX_HOME:-\$HOME/.codex}/pets"
