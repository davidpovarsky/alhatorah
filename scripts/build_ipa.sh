#!/usr/bin/env bash
set -euo pipefail

# Builds a signed IPA for a real iPhone/iPad device.
# This script must run on macOS with Xcode installed.
# A real IPA requires valid Apple signing. The easiest mode is automatic signing:
#
#   TEAM_ID=ABCDE12345 \
#   BUNDLE_ID=com.yourname.NativeSiteApp \
#   ALLOW_AUTOMATIC_SIGNING=true \
#   ./scripts/build_ipa.sh
#
# Optional:
#   EXPORT_METHOD=development | ad-hoc | app-store-connect | enterprise
#   CONFIGURATION=Release
#
# Logs are written to build_logs/archive.log and build_logs/export.log.

PROJECT="${PROJECT:-NativeSiteApp.xcodeproj}"
SCHEME="${SCHEME:-NativeSiteApp}"
CONFIGURATION="${CONFIGURATION:-Release}"
TEAM_ID="${TEAM_ID:-}"
BUNDLE_ID="${BUNDLE_ID:-com.example.NativeSiteApp}"
EXPORT_METHOD="${EXPORT_METHOD:-development}"
ALLOW_AUTOMATIC_SIGNING="${ALLOW_AUTOMATIC_SIGNING:-true}"
PROVISIONING_PROFILE_SPECIFIER="${PROVISIONING_PROFILE_SPECIFIER:-}"

BUILD_DIR="${BUILD_DIR:-build}"
LOG_DIR="${LOG_DIR:-build_logs}"
ARCHIVE_PATH="$BUILD_DIR/archive/$SCHEME.xcarchive"
EXPORT_PATH="$BUILD_DIR/ipa"
EXPORT_OPTIONS_PATH="$BUILD_DIR/ExportOptions.plist"
SUMMARY_PATH="$LOG_DIR/last_build_summary.txt"

mkdir -p "$BUILD_DIR/archive" "$EXPORT_PATH" "$LOG_DIR"
rm -f "$LOG_DIR/archive.log" "$LOG_DIR/export.log" "$SUMMARY_PATH"

if [[ -z "$TEAM_ID" ]]; then
  echo "ERROR: TEAM_ID is required for a signed device IPA." | tee -a "$SUMMARY_PATH"
  echo "Example: TEAM_ID=ABCDE12345 BUNDLE_ID=com.yourname.NativeSiteApp ./scripts/build_ipa.sh" | tee -a "$SUMMARY_PATH"
  exit 2
fi

ARCHIVE_SIGNING_ARGS=(
  DEVELOPMENT_TEAM="$TEAM_ID"
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID"
)

if [[ "$ALLOW_AUTOMATIC_SIGNING" == "true" ]]; then
  SIGNING_STYLE="automatic"
  ARCHIVE_SIGNING_ARGS+=(CODE_SIGN_STYLE=Automatic)
  PROVISIONING_FLAG=(-allowProvisioningUpdates)
  PROVISIONING_PROFILES_BLOCK=""
else
  SIGNING_STYLE="manual"
  PROVISIONING_FLAG=()
  if [[ -z "$PROVISIONING_PROFILE_SPECIFIER" ]]; then
    echo "ERROR: PROVISIONING_PROFILE_SPECIFIER is required when ALLOW_AUTOMATIC_SIGNING=false." | tee -a "$SUMMARY_PATH"
    exit 2
  fi
  ARCHIVE_SIGNING_ARGS+=(CODE_SIGN_STYLE=Manual)
  ARCHIVE_SIGNING_ARGS+=(PROVISIONING_PROFILE_SPECIFIER="$PROVISIONING_PROFILE_SPECIFIER")
  PROVISIONING_PROFILES_BLOCK="
    <key>provisioningProfiles</key>
    <dict>
        <key>$BUNDLE_ID</key>
        <string>$PROVISIONING_PROFILE_SPECIFIER</string>
    </dict>"
fi

cat > "$EXPORT_OPTIONS_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>$EXPORT_METHOD</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>signingStyle</key>
    <string>$SIGNING_STYLE</string>$PROVISIONING_PROFILES_BLOCK
    <key>stripSwiftSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
PLIST

echo "Project: $PROJECT" | tee -a "$SUMMARY_PATH"
echo "Scheme: $SCHEME" | tee -a "$SUMMARY_PATH"
echo "Configuration: $CONFIGURATION" | tee -a "$SUMMARY_PATH"
echo "Bundle ID: $BUNDLE_ID" | tee -a "$SUMMARY_PATH"
echo "Export method: $EXPORT_METHOD" | tee -a "$SUMMARY_PATH"
echo "Archive path: $ARCHIVE_PATH" | tee -a "$SUMMARY_PATH"
echo "Export path: $EXPORT_PATH" | tee -a "$SUMMARY_PATH"

echo "Starting archive..." | tee -a "$SUMMARY_PATH"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  "${PROVISIONING_FLAG[@]}" \
  "${ARCHIVE_SIGNING_ARGS[@]}" \
  2>&1 | tee "$LOG_DIR/archive.log"

echo "Starting IPA export..." | tee -a "$SUMMARY_PATH"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PATH" \
  "${PROVISIONING_FLAG[@]}" \
  2>&1 | tee "$LOG_DIR/export.log"

IPA_PATH="$(find "$EXPORT_PATH" -maxdepth 1 -name '*.ipa' -print -quit || true)"
if [[ -z "$IPA_PATH" ]]; then
  echo "ERROR: xcodebuild finished but no IPA was found in $EXPORT_PATH" | tee -a "$SUMMARY_PATH"
  exit 3
fi

echo "IPA created: $IPA_PATH" | tee -a "$SUMMARY_PATH"
echo "Archive log: $LOG_DIR/archive.log" | tee -a "$SUMMARY_PATH"
echo "Export log: $LOG_DIR/export.log" | tee -a "$SUMMARY_PATH"
