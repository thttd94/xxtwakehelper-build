#!/bin/sh
set -e
APP_PATH="${1:-.theos/obj/debug/LidCopy.app}"
if [ ! -d "$APP_PATH" ]; then
  echo "App not found: $APP_PATH" >&2
  exit 1
fi
rm -rf Payload LidCopy.ipa
mkdir -p Payload
cp -R "$APP_PATH" Payload/LidCopy.app
cp -f Info.plist Payload/LidCopy.app/Info.plist
for icon in Icon*.png; do
  [ -f "$icon" ] && cp -f "$icon" Payload/LidCopy.app/
done
if [ -f lid.png ]; then cp -f lid.png Payload/LidCopy.app/lid.png; fi
if [ ! -f Payload/LidCopy.app/LidCopy ]; then
  FOUND="$(find Payload/LidCopy.app -maxdepth 1 -type f -perm +111 2>/dev/null | head -n 1 || true)"
  if [ -n "$FOUND" ]; then cp -f "$FOUND" Payload/LidCopy.app/LidCopy; fi
fi
if [ ! -f Payload/LidCopy.app/Info.plist ]; then echo "Missing app Info.plist" >&2; exit 1; fi
if [ ! -f Payload/LidCopy.app/LidCopy ]; then echo "Missing app executable" >&2; find Payload/LidCopy.app -maxdepth 2 -type f -print >&2; exit 1; fi
zip -qry LidCopy.ipa Payload
rm -rf Payload
echo "Wrote LidCopy.ipa"
