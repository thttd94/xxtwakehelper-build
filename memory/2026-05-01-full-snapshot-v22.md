# 2026-05-01 V2.2 full-router snapshot correction

- User clarified that version packaging must not be app-only or hotfix-based. It must snapshot the whole GEN router state including system files, services, genrouter core/config, network/firewall/dhcp configs, cron, rc.local, /etc/shm, and partition/mount metadata, excluding backup stores to avoid recursion.
- Added `full_system_backup.sh` (BusyBox-compatible; no GNU tar `--exclude`) and rewrote `rollback_version.sh` to restore `system/*.tgz` plus clean app package.
- Ran full snapshot on source router `192.14.0.1` for version `2.2`, then downloaded into Git tree `GEN_NEW_9001/gen_backup/versions/2.2`.
- The V2.2 version now contains:
  - `package/` copied from live `/opt/proxy-manager-v1` on source router
  - `system/etc_config.tgz`
  - `system/etc_crontabs.tgz`
  - `system/etc_genrouter.tgz`
  - `system/etc_init_d.tgz`
  - `system/etc_rc_local.tgz`
  - `system/etc_shm.tgz`
  - `system/opt_proxy_manager_v1.tgz`
  - `system/system_manifest.txt`
- Pushed GitHub `thttd94/GEN` main commit `1f89480 Replace V2.2 package with full router snapshot`.
- Important lesson: do not call a version "packaged" unless both `package/` and `system/` snapshots exist from a known-good source router.
