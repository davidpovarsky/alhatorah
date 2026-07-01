#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT:-NativeSiteApp.xcodeproj}"
SCHEME="${SCHEME:-NativeSiteApp}"
CONFIGURATION="${CONFIGURATION:-Release}"
BUNDLE_ID="${BUNDLE_ID:-com.davidpovarsky.alhatorah}"

BUILD_DIR="${BUILD_DIR:-build}"
LOG_DIR="${LOG_DIR:-build_logs}"
DERIVED_DATA="$BUILD_DIR/DerivedData"
IPA_DIR="$BUILD_DIR/ipa"
SUMMARY="$LOG_DIR/last_build_summary.txt"
BUILD_LOG="$LOG_DIR/build.log"

mkdir -p "$BUILD_DIR" "$LOG_DIR" "$IPA_DIR"
rm -f "$SUMMARY" "$BUILD_LOG" "$IPA_DIR"/*.ipa

log() {
  echo "$1" | tee -a "$SUMMARY"
}

log "Project: $PROJECT"
log "Scheme: $SCHEME"
log "Configuration: $CONFIGURATION"
log "Bundle ID: $BUNDLE_ID"
log "SDK: iphoneos"
log "Build log: $BUILD_LOG"

log "Starting unsigned iPhoneOS build..."

xcodebuild clean build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DERIVED_DATA" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  2>&1 | tee "$BUILD_LOG"

PRODUCTS_DIR="$DERIVED_DATA/Build/Products/$CONFIGURATION-iphoneos"
APP_PATH="$(find "$PRODUCTS_DIR" -maxdepth 1 -name '*.app' -type d | sort | head -n 1)"

if [[ -z "$APP_PATH" ]]; then
  log "ERROR: Build finished, but no .app was found in $PRODUCTS_DIR"
  exit 3
fi

STAGING="$BUILD_DIR/ipa_staging"
rm -rf "$STAGING"
mkdir -p "$STAGING/Payload"
cp -R "$APP_PATH" "$STAGING/Payload/"

IPA_PATH="$PWD/$IPA_DIR/${SCHEME}-unsigned-device.ipa"
(
  cd "$STAGING"
  zip -qry "$IPA_PATH" Payload
)

log "IPA created: $IPA_PATH"
log "Note: This IPA is unsigned. It confirms real-device compilation, but normal installation requires Apple signing."

