#!/bin/sh
# Makes sure this Mac has Curtain's local signing identity, and unlocks it for codesign (#11).
#
# Why: macOS ties the Accessibility permission (brightness keys) to the app's designated
# requirement. Signed ad hoc, that requirement is the build's hash, so every rebuild silently
# lost the permission while System Settings still showed it on. Signed with this certificate the
# requirement is "identifier com.saaquiblabs.curtain and this certificate", the same every build.
#
# The certificate is self-signed and lives in its own keychain file (not the login keychain), so
# `make` never shows a password dialog. It only signs builds made on this Mac. To remove it:
#   security delete-keychain ~/Library/Keychains/curtain-signing.keychain-db
set -e
KEYCHAIN="${CURTAIN_KEYCHAIN:-$HOME/Library/Keychains/curtain-signing.keychain-db}"   # override only for tests
PASSWORD=curtain   # not a secret: it only keeps the file out of the way of other keychains
NAME="Curtain Local Signing"

if [ ! -f "$KEYCHAIN" ]; then
  work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
  cat > "$work/cfg" <<CFG
[req]
distinguished_name = dn
prompt = no
x509_extensions = ext
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CFG
  # macOS's own openssl: its .p12 files are ones `security import` can read.
  /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 7300 -config "$work/cfg" \
    -keyout "$work/key.pem" -out "$work/cert.pem" 2>/dev/null
  /usr/bin/openssl pkcs12 -export -inkey "$work/key.pem" -in "$work/cert.pem" -out "$work/id.p12" -passout pass:p
  security create-keychain -p "$PASSWORD" "$KEYCHAIN"
  security set-keychain-settings "$KEYCHAIN"   # no auto-lock
  security unlock-keychain -p "$PASSWORD" "$KEYCHAIN"
  security import "$work/id.p12" -k "$KEYCHAIN" -P p -T /usr/bin/codesign >/dev/null
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$PASSWORD" "$KEYCHAIN" >/dev/null
  echo "signing-identity: made \"$NAME\" in $KEYCHAIN" >&2
fi
# codesign --keychain only finds the identity when the keychain is also on the user's search
# list, at least on macOS 26 (#37: "no identity found", install failed). Add it, keeping the
# existing keychains in their order. It then shows in Keychain Access as curtain-signing.
if ! security list-keychains -d user | grep -qF "$KEYCHAIN"; then
  eval "set -- $(security list-keychains -d user | tr '\n' ' ')"
  security list-keychains -d user -s "$@" "$KEYCHAIN" \
    || echo "signing-identity: couldn't add $KEYCHAIN to the keychain search list" >&2
fi
security unlock-keychain -p "$PASSWORD" "$KEYCHAIN"
echo "$KEYCHAIN"
