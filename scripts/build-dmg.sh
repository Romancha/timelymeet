#!/usr/bin/env bash
#
# Builds a Developer ID-signed, notarized TimelyMeet.dmg for distribution outside the Mac App Store.
# Signing uses the Developer ID certificate from the login keychain; it never leaves this Mac.
#
# One-time setup: store notarization credentials in the keychain (Apple ID + app-specific password, or an API key):
#   xcrun notarytool store-credentials timelymeet --apple-id <apple-id> --team-id KY6MPSHF75
#
# Environment:
#   NOTARY_KEYCHAIN_PROFILE  notarytool keychain profile (default "timelymeet")
#   SIGNING_IDENTITY         codesign identity for the app (default "Developer ID Application")
#   EXPECTED_VERSION         fail if CFBundleShortVersionString differs (release.sh passes the project version)
#   BUILD_DIR                output directory (default ./build)
#   SKIP_NOTARIZATION        set to 1 for a dry run: signs everything but skips notarization
#
# Output: $BUILD_DIR/TimelyMeet.dmg (stable name, linked as releases/latest/download/TimelyMeet.dmg)

set -euo pipefail

APP_NAME="TimelyMeet"
SCHEME="TimelyMeet"
TEAM_ID="KY6MPSHF75"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application}"
NOTARY_KEYCHAIN_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-timelymeet}"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP_PATH="$EXPORT_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"

log() { echo "==> $*"; }

notarize() {
    local file="$1"
    log "Notarizing $(basename "$file")"

    # Don't let set -e abort before the rejection log is fetched
    local result rc=0 status id
    result=$(xcrun notarytool submit "$file" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
        --wait --timeout 30m --output-format json) || rc=$?
    echo "$result"

    status=$(jq -r '.status // empty' <<<"$result" 2>/dev/null || true)
    if [[ $rc -ne 0 || "$status" != "Accepted" ]]; then
        id=$(jq -r '.id // empty' <<<"$result" 2>/dev/null || true)
        if [[ -n "$id" ]]; then
            xcrun notarytool log "$id" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" || true
        fi
        echo "Notarization failed for $file" >&2
        exit 1
    fi
}

rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR" "$DMG_PATH" "$BUILD_DIR/dmg"
mkdir -p "$BUILD_DIR"

# Hardened runtime is required for notarization; it is enabled here so the App Store configuration stays untouched
log "Archiving $SCHEME"
xcodebuild archive \
    -project "$ROOT_DIR/$APP_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    PROVISIONING_PROFILE_SPECIFIER="" \
    ENABLE_HARDENED_RUNTIME=YES \
    OTHER_CODE_SIGN_FLAGS="--timestamp"

log "Exporting with Developer ID"
EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"
cat > "$EXPORT_OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>$SIGNING_IDENTITY</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
</dict>
</plist>
EOF
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$EXPORT_DIR"

APP_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
log "Built $APP_NAME $APP_VERSION"
if [[ -n "${EXPECTED_VERSION:-}" && "$APP_VERSION" != "$EXPECTED_VERSION" ]]; then
    echo "Version mismatch: app is $APP_VERSION, expected $EXPECTED_VERSION (bump MARKETING_VERSION or fix the tag)" >&2
    exit 1
fi

log "Verifying app signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
SIGNATURE_INFO=$(codesign --display --verbose=2 "$APP_PATH" 2>&1)
echo "$SIGNATURE_INFO" | grep -E "^(Authority|TeamIdentifier|Timestamp)="
if [[ "$SIGNATURE_INFO" != *"(runtime)"* ]]; then
    echo "Hardened runtime is not enabled on $APP_PATH" >&2
    exit 1
fi

if [[ "${SKIP_NOTARIZATION:-0}" != "1" ]]; then
    # Staple the app itself too, so Gatekeeper accepts it offline after it is copied out of the DMG
    APP_ZIP="$BUILD_DIR/$APP_NAME.zip"
    ditto -c -k --keepParent "$APP_PATH" "$APP_ZIP"
    notarize "$APP_ZIP"
    rm -f "$APP_ZIP"
    xcrun stapler staple "$APP_PATH"
    spctl --assess --type execute --verbose=2 "$APP_PATH"
fi

log "Creating DMG"
STAGING_DIR="$BUILD_DIR/dmg"
mkdir -p "$STAGING_DIR"
ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "$DMG_PATH"
rm -rf "$STAGING_DIR"

# Sign the DMG with the exact certificate Xcode picked for the app: a plain name is ambiguous
# for codesign when the keychain holds several Developer ID certificates
CERT_DIR=$(mktemp -d)
codesign --display --extract-certificates="$CERT_DIR/cert" "$APP_PATH" 2>/dev/null
APP_CERT_SHA1=$(openssl x509 -inform DER -in "$CERT_DIR/cert0" -noout -fingerprint -sha1 | cut -d= -f2 | tr -d :)
rm -rf "$CERT_DIR"
codesign --force --sign "$APP_CERT_SHA1" --timestamp "$DMG_PATH"

if [[ "${SKIP_NOTARIZATION:-0}" != "1" ]]; then
    notarize "$DMG_PATH"
    xcrun stapler staple "$DMG_PATH"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"
else
    log "SKIP_NOTARIZATION=1: DMG is signed but NOT notarized, do not publish it"
fi

log "Done: $DMG_PATH"
shasum -a 256 "$DMG_PATH"
