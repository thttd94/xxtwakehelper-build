#!/bin/sh
set -eu
make
mkdir -p Payload
cp -R .theos/obj/debug/DID603Diagnostic.app Payload/
cp Info.plist Payload/DID603Diagnostic.app/Info.plist
zip -qry DID603Diagnostic.ipa Payload
shasum -a 256 DID603Diagnostic.ipa > DID603Diagnostic.ipa.sha256
