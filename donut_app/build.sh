#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUBSPEC_PATH="$ROOT_DIR/pubspec.yaml"
APPINFO_PATH="$ROOT_DIR/macos/Runner/Configs/AppInfo.xcconfig"
BUILD_ROOT="$ROOT_DIR/build"
MACOS_RELEASE_DIR="$BUILD_ROOT/macos/Build/Products/Release"
DMG_STAGE_DIR="$BUILD_ROOT/dmg"
DIST_DIR="$ROOT_DIR/dist"

usage() {
  cat <<'EOF'
Usage:
  ./build.sh
  ./build.sh --version=0.0.3+3

Options:
  --version=x.y.z+n   Override build version for this packaging run.
  -h, --help          Show this help message.
EOF
}

VERSION_OVERRIDE=""

for arg in "$@"; do
  case "$arg" in
    --version=*)
      VERSION_OVERRIDE="${arg#*=}"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd" >&2
    exit 1
  fi
}

require_command flutter
require_command create-dmg
require_command python3
require_command open

APP_NAME="$(sed -n 's/^PRODUCT_NAME = //p' "$APPINFO_PATH" | head -n 1 | tr -d '\r')"
if [[ -z "$APP_NAME" ]]; then
  echo "Failed to resolve PRODUCT_NAME from $APPINFO_PATH" >&2
  exit 1
fi

PUBSPEC_VERSION="$(sed -n 's/^version: //p' "$PUBSPEC_PATH" | head -n 1 | tr -d '\r')"
if [[ -z "$PUBSPEC_VERSION" ]]; then
  echo "Failed to resolve version from $PUBSPEC_PATH" >&2
  exit 1
fi

VERSION_STRING="${VERSION_OVERRIDE:-$PUBSPEC_VERSION}"

if [[ ! "$VERSION_STRING" =~ ^[0-9]+(\.[0-9]+){2}\+[0-9]+$ ]]; then
  echo "Invalid version format: $VERSION_STRING" >&2
  echo "Expected format: x.y.z+n" >&2
  exit 1
fi

BUILD_NAME="${VERSION_STRING%%+*}"
BUILD_NUMBER="${VERSION_STRING##*+}"
APP_BUNDLE_PATH="$MACOS_RELEASE_DIR/$APP_NAME.app"
DMG_NAME="$APP_NAME-$VERSION_STRING.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"

echo "App name: $APP_NAME"
echo "Version: $VERSION_STRING"
echo "Cleaning old build artifacts..."
rm -rf "$BUILD_ROOT" "$DIST_DIR"

mkdir -p "$DIST_DIR"

echo "Cleaning Flutter artifacts..."
(
  cd "$ROOT_DIR"
  flutter clean
)

echo "Fetching dependencies..."
(
  cd "$ROOT_DIR"
  flutter pub get
)

echo "Building macOS app..."
(
  cd "$ROOT_DIR"
  flutter build macos --release --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER"
)

if [[ ! -d "$APP_BUNDLE_PATH" ]]; then
  echo "Build succeeded but app bundle was not found: $APP_BUNDLE_PATH" >&2
  exit 1
fi

echo "Preparing DMG contents..."
rm -rf "$DMG_STAGE_DIR"
mkdir -p "$DMG_STAGE_DIR"
cp -R "$APP_BUNDLE_PATH" "$DMG_STAGE_DIR/"

echo "Creating DMG..."
create-dmg \
  --volname "$APP_NAME" \
  --window-pos 200 120 \
  --window-size 800 420 \
  --icon-size 120 \
  --icon "$APP_NAME.app" 220 190 \
  --icon "Applications" 580 190 \
  --hide-extension "$APP_NAME.app" \
  --app-drop-link 580 190 \
  "$DMG_PATH" \
  "$DMG_STAGE_DIR"

echo "DMG created at: $DMG_PATH"
echo "Opening output folder..."
open "$DIST_DIR"
