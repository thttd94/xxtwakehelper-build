# LidCopy IPA source

App mở lên sẽ copy:

- nguồn ưu tiên: `/var/mobile/Media/1ferver/ipa/lid.png`
- nếu không có thì dùng `lid.png` bundle kèm app

vào Safari data container:

`/var/mobile/Containers/Data/Application/<SafariUUID>/Library/Cookies/lid.png`

Nếu file đích tồn tại, backup thành `lid_backup.png`.

## Build trên macOS / Theos-capable environment

```sh
cd LidCopyIPA
chmod +x build.sh
./build.sh
```

Output: `LidCopy.ipa`

## Ghi chú

- IPA thường có thể bị sandbox chặn khi đọc/ghi container của Safari.
- Cần môi trường có quyền phù hợp như TrollStore/jailbreak + entitlement phù hợp.
- Windows hiện tại không có Xcode/clang/ldid nên không build trực tiếp được ở máy này.
