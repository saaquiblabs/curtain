#!/bin/sh
# Does Curtain's Accessibility permission survive a rebuild? macOS ties the permission to the
# app's designated requirement. Builds the app, changes one sealed file the way any rebuild does,
# signs again exactly as `make app` does, and fails if the requirement changed.
set -e
APP=build/Curtain.app
make -s app >/dev/null
before=$(codesign -d -r- "$APP" 2>&1 | sed -n "s/.*designated => //p")
trap 'rm -f "$APP/Contents/Resources/rebuild-stamp"' EXIT
date > "$APP/Contents/Resources/rebuild-stamp"
make -s sign >/dev/null
after=$(codesign -d -r- "$APP" 2>&1 | sed -n "s/.*designated => //p")
rm -f "$APP/Contents/Resources/rebuild-stamp"; make -s sign >/dev/null   # leave a normal build behind
echo "before: $before"
echo "after:  $after"
[ "$before" = "$after" ] && echo "check-signing: OK, the permission survives rebuilds" \
  || { echo "check-signing: FAIL, a rebuild gets a new requirement, so macOS drops the permission"; exit 1; }
