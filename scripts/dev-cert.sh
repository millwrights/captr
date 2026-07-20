#!/usr/bin/env bash
# Captr — create a stable self-signed code-signing identity for LOCAL DEV.
# SPDX-License-Identifier: MIT OR Apache-2.0
#
# Why: macOS ties Screen Recording (and Accessibility) permissions to an app's
# code signature. An unsigned app gets a new identity every rebuild, so the
# permission you granted stops applying. Signing every build with ONE stable
# identity makes the grant persist. This creates such an identity locally.
#
# The identity name is reusable across all your projects — sign every app with
# the same one and each keeps its permissions across rebuilds.
#
# For distribution you'd use a real "Developer ID Application" cert instead;
# this self-signed cert is for your machine only.
#
# Usage:
#   ./scripts/dev-cert.sh                 # creates "Millwrights" (default)
#   ./scripts/dev-cert.sh "My Identity"   # creates a named identity
#   # both write .signing-identity for this repo; in other repos reuse it with:
#   #   echo "Millwrights" > .signing-identity && make run

set -euo pipefail

NAME="${1:-Millwrights}"          # identity name (first arg; default "Millwrights")
P12PASS="devcert"                 # throwaway transport password for the .p12 import
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

# Refuse to create a second cert with the same name — codesign treats a
# duplicate name as "ambiguous" and silently falls back to an ad-hoc signature
# (whose identity changes every build, so TCC permissions never persist).
EXISTING="$(security find-identity -p codesigning 2>/dev/null | grep -c "\"$NAME\"" || true)"
if [ "${EXISTING:-0}" -ge 1 ]; then
  echo "✓ Code-signing identity '$NAME' already exists ($EXISTING found)."
  if [ "${EXISTING:-0}" -ge 2 ]; then
    echo "⚠ There are $EXISTING certs named '$NAME' — that is ambiguous and breaks signing."
    echo "  Remove extras in Keychain Access (login keychain → My Certificates), keep one, then:"
  fi
  echo "  echo \"$NAME\" > .signing-identity && make run"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/openssl.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = $NAME
[v3]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

echo "==> Generating self-signed code-signing certificate '$NAME'…"
openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/openssl.cnf" >/dev/null 2>&1

# OpenSSL 3 defaults to a PKCS#12 MAC that Apple's `security import` can't read
# ("MAC verification failed"). Force the legacy SHA1 encoding it understands.
LEGACY=""
if openssl version 2>/dev/null | grep -q '^OpenSSL 3'; then
  LEGACY="-legacy"
fi
openssl pkcs12 -export $LEGACY -macalg sha1 \
  -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -out "$TMP/id.p12" -passout "pass:$P12PASS" -name "$NAME" >/dev/null 2>&1

echo "==> Importing into your login keychain (you may be asked for your login password)…"
security import "$TMP/id.p12" -k "$KEYCHAIN" -P "$P12PASS" \
  -T /usr/bin/codesign -T /usr/bin/security

# Let codesign use the private key without an interactive prompt each time.
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" "$KEYCHAIN" >/dev/null 2>&1 || \
  echo "  (note: first codesign run may pop a keychain dialog — click 'Always Allow')"

echo
# A self-signed cert is untrusted by design, so `find-identity -v` (valid only)
# won't list it — check the full list instead. codesign can still use it.
if security find-identity -p codesigning | grep -q "$NAME"; then
  echo "✓ Created code-signing identity: $NAME"
  echo "$NAME" > .signing-identity
  echo "  wrote .signing-identity so every build in this repo signs with it"
  echo
  echo "Finish with:"
  echo "  tccutil reset ScreenCapture com.millwrights.captr   # clear stale grants (Captr)"
  echo "  make run                                            # builds + signs"
  echo "  # grant Captr under Privacy & Security → Screen Recording, then quit & 'make run' once more"
  echo
  echo "Reuse '$NAME' in another project:  echo \"$NAME\" > .signing-identity"
else
  echo "✗ Could not find the identity. Create it via Keychain Access instead:" >&2
  echo "  Keychain Access → Certificate Assistant → Create a Certificate…" >&2
  echo "  Name '$NAME', Identity Type 'Self Signed Root', Certificate Type 'Code Signing'." >&2
  exit 1
fi
