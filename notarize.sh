#!/bin/zsh
set -euo pipefail

# Notarizes and staples dist/Plink.app, then produces a distributable
# dist/Plink.zip containing the stapled app.
#
# Credentials (either approach):
#   • A stored keychain profile:   NOTARY_PROFILE=plink-notary ./notarize.sh
#     (create once with: xcrun notarytool store-credentials plink-notary \
#         --apple-id you@example.com --team-id TEAMID --password app-specific-pw)
#   • Or environment variables:    APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD
#
# Run ./build.sh with SIGN_IDENTITY set first, so the app is Developer ID signed.

APP_NAME="Plink"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT_DIR/dist/$APP_NAME.app"
ZIP="$ROOT_DIR/dist/$APP_NAME.zip"

if [[ ! -d "$APP" ]]; then
  echo "error: $APP not found — run ./build.sh first." >&2
  exit 1
fi

echo "Zipping app for submission…"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo "Submitting to Apple notary service (this can take a few minutes)…"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
else
  : "${APPLE_ID:?set APPLE_ID or NOTARY_PROFILE}"
  : "${APPLE_TEAM_ID:?set APPLE_TEAM_ID}"
  : "${APPLE_APP_PASSWORD:?set APPLE_APP_PASSWORD}"
  xcrun notarytool submit "$ZIP" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --wait
fi

echo "Stapling ticket onto the app…"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "Re-zipping the stapled app for distribution…"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo "Notarized + stapled: $ZIP"
