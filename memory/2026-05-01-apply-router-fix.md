# 2026-05-01 apply router fix

- Continued work for Anh Thái on router `192.14.0.1` proxy manager apply flow.
- Prior issue: `POST /api/pm/apply/1` no longer hit old GUI connection refused, but `LOCAL APPLY CONFIG` returned `Router not selected`.
- Inspected `/opt/proxy-manager-v1/app.py` on `192.14.0.1:886` using SSH password already used in prior local scripts.
- Found `load_admanager_config()` had routers `tiktok03`, `tiktok04`, `tiktok05`, while `uiState.router` was `All`.
- Patched `run_apply()` so router selection treats `All` as all configured routers instead of invalid selection; also still auto-picks the only router when there is exactly one.
- Restarted `/etc/init.d/proxy-manager-v1` and tested:
  - `POST http://127.0.0.1:9001/api/pm/apply/1`
  - Result `ok: true`; `LOCAL APPLY CONFIG ok: true`; router `All`; routers `['tiktok03','tiktok04','tiktok05']`; `genrunner check only returncode: 0`.
- Local helper scripts created: `fix_apply_router_select.py`, `inspect_remote_cfg.py`, `patch_remote_apply_router.py`, `patch_remote_apply_all.py`.
