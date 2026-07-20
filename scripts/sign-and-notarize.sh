#!/usr/bin/env bash
# Captr — sign, notarize, and staple Captr.app for distribution.
# SPDX-License-Identifier: MIT OR Apache-2.0
#
# Requires a paid Apple Developer account and a "Developer ID Application"
# certificate installed in your login keychain.
#
# Configuration (via environment variables):
#   SIGN_IDENTITY   "Developer ID Application: Your Name (TEAMID)"   (required)
#   NOTARY_PROFILE  name of a stored notarytool keychain profile     (recommended)
#     — or —
#   APPLE_ID        your Apple ID email
#   TEAM_ID         your 10-char team id
#   APP_PASSWORD    an app-specific password (appleid.apple.com)
#
# One-time notarytool profile setup (so you don't pass credentials each run):
#   xcrun notarytool store-credentials Captr-notary \
#       --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-pw"
#   export NOTARY_PROFILE=Captr-notary
#
# Usage:
#   SIGN_IDENTITY="Developer ID Application: ... (TEAMID)" \
#   NOTARY_PROFILE=Captr-notary \
#   scripts/sign-and-notarize.sh

set -euo pipefail

APP="build/Captr.app"
ZIP="build/Captr.zip"

if [[ -z "${SIGN_IDENTITY:-}" || "${SIGN_IDENTITY}" == "-" ]]; then
  echo "error: set SIGN_IDENTITY to your 'Developer ID Application' identity." >&2
  echo "       list yours with:  security find-identity -v -p codesigning" >&2
  exit 1
fi

echo "==> Building"
make app

echo "==> Signing with hardened runtime"
codesign --force --deep --timestamp --options runtime \
  --sign "${SIGN_IDENTITY}" "${APP}"
codesign --verify --strict --verbose=2 "${APP}"

echo "==> Zipping for notarization"
rm -f "${ZIP}"
/usr/bin/ditto -c -k --keepParent "${APP}" "${ZIP}"

echo "==> Submitting to Apple notary service"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "${ZIP}" --keychain-profile "${NOTARY_PROFILE}" --wait
else
  : "${APPLE_ID:?set APPLE_ID or NOTARY_PROFILE}"
  : "${TEAM_ID:?set TEAM_ID or NOTARY_PROFILE}"
  : "${APP_PASSWORD:?set APP_PASSWORD or NOTARY_PROFILE}"
  xcrun notarytool submit "${ZIP}" \
    --apple-id "${APPLE_ID}" --team-id "${TEAM_ID}" --password "${APP_PASSWORD}" --wait
fi

echo "==> Stapling ticket"
xcrun stapler staple "${APP}"
xcrun stapler validate "${APP}"

echo "==> Verifying Gatekeeper acceptance"
spctl --assess --type execute --verbose=4 "${APP}" || true

echo "✓ Done. Distributable, notarized app at ${APP}"
