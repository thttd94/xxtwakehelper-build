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
zip -qry XXTWakeHelper.ipa Payload
rm -rf Payload
echo "Wrote XXTWakeHelper.ipa"
