# XXTWakeHelper

TrollStore helper app to wake XXTouch after reboot.

Goal:
- Run as a TrollStore app with launch-app entitlements.
- On launch / foreground / background wake, repeatedly open XXTouch using `xxt://` and `ch.xxtou.XXTExplorer`.
- Keep a small background task loop for several minutes after boot/launch.
- Optional tiny HTTP status endpoint can be added later.

This folder is source/project scaffold. Build on macOS with Xcode or Theos, then install the IPA with TrollStore.

## Target bundle

- Helper bundle id: `com.oc.xxtwakehelper`
- Target to wake: `ch.xxtou.XXTExplorer`
- URL scheme: `xxt://`

## Build

Use the Xcode project/spec generated from these sources, or create a new iOS app project and copy:

- `Sources/AppDelegate.m`
- `Sources/main.m`
- `Info.plist`
- `entitlements.plist`

Build as iOS app, then package:

```sh
mkdir -p Payload
cp -R build/Release-iphoneos/XXTWakeHelper.app Payload/
zip -r XXTWakeHelper.ipa Payload
```

Install with TrollStore.

## Test

1. Install helper with TrollStore.
2. Open helper once manually.
3. Reboot.
4. Check if XXTouch port 46952 comes up without manual open.

