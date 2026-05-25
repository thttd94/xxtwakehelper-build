#!/bin/sh
set -e
APP=LidCopy.app
IPA=LidCopy.ipa
BUNDLE=com.local.lidcopy
SDK="${SDK:-iphoneos}"
MIN="${MIN:-12.0}"
rm -rf Payload "$APP" "$IPA"
mkdir -p "$APP"
clang -isysroot "$(xcrun --sdk $SDK --show-sdk-path)" \
  -miphoneos-version-min=$MIN \
  -fobjc-arc \
  -framework UIKit -framework Foundation \
  main.m -o "$APP/LidCopy"
cp Info.plist "$APP/Info.plist"
if [ -f lid.png ]; then cp lid.png "$APP/lid.png"; fi
if command -v ldid >/dev/null 2>&1; then
  ldid -SEntitlements.plist "$APP/LidCopy"
else
  codesign -fs - --entitlements Entitlements.plist "$APP/LidCopy" || true
fi
mkdir Payload
mv "$APP" Payload/
zip -qry "$IPA" Payload
rm -rf Payload
echo "Built $IPA"
