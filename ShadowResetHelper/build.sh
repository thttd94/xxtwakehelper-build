#!/bin/sh
set -e
make clean && make
rm -rf Payload ShadowResetHelper.ipa
mkdir -p Payload
cp -R .theos/obj/debug/ShadowResetHelper.app Payload/
cp Info.plist Payload/ShadowResetHelper.app/Info.plist
zip -qry ShadowResetHelper.ipa Payload
rm -rf Payload
