#!/bin/sh
set -e
APP_PATH="${1:-.theos/obj/debug/XXTWakeHelper.app}"
if [ ! -d "$APP_PATH" ]; then
  echo "App not found: $APP_PATH" >&2
  exit 1
fi
rm -rf Payload XXTWakeHelper.ipa
mkdir -p Payload
cp -R "$APP_PATH" Payload/XXTWakeHelper.app

# Theos app bundles may not include our root Info.plist automatically in this scaffold.
# TrollStore/Filza require Payload/XXTWakeHelper.app/Info.plist.
cp -f Info.plist Payload/XXTWakeHelper.app/Info.plist

# Ensure executable name matches CFBundleExecutable.
if [ ! -f Payload/XXTWakeHelper.app/XXTWakeHelper ]; then
  FOUND="$(find Payload/XXTWakeHelper.app -maxdepth 1 -type f -perm +111 2>/dev/null | head -n 1 || true)"
  if [ -n "$FOUND" ]; then
    cp -f "$FOUND" Payload/XXTWakeHelper.app/XXTWakeHelper
  fi
fi

if [ ! -f Payload/XXTWakeHelper.app/Info.plist ]; then
  echo "Missing app Info.plist" >&2
  exit 1
fi
if [ ! -f Payload/XXTWakeHelper.app/XXTWakeHelper ]; then
  echo "Missing app executable" >&2
  find Payload/XXTWakeHelper.app -maxdepth 2 -type f -print >&2
  exit 1
fi

zip -qry XXTWakeHelper.ipa Payload
rm -rf Payload
echo "Wrote XXTWakeHelper.ipa"
